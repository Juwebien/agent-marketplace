

# Cycle zu — Budget-Tiered Workflows Architecture

---

## 1. Core Insight de ce cycle

**Le budget n'achète pas plus de compute, il achète une densité de vérification plus élevée — et cette densité doit être modélisée comme une chaîne de preuve composable, pas comme un pipeline linéaire.**

Les cycles précédents ont validé le principe (za) et l'architecture SSPW (zt). Ce que ce cycle zu doit résoudre, c'est le passage du modèle conceptuel à une **architecture implémentable** qui répond à la question que personne n'a encore tranchée : comment le `WorkflowEscrow` orchestre-t-il *concrètement* la séquence des missions, gère les failures intermédiaires, distribue les budgets, et maintient la cohérence entre l'état on-chain (commitments, escrow) et l'état off-chain (artefacts, rapports de review, scores) — le tout sans transformer le smart contract en un workflow engine Turing-complet ingérable ?

La réponse que je propose : **le contrat ne gère que les transitions d'état et les verrous financiers**. L'orchestration (quel agent, quel artefact passer au suivant, quel threshold appliquer) vit dans un **Workflow Orchestrator off-chain** (service TypeScript) qui est le seul autorisé à appeler `activateStage()` et `submitGateAttestation()`. Le contrat est un **finite state machine financier**, pas un workflow engine. C'est la seule architecture qui scale sans exploser le gas et sans reproduire Temporal en Solidity.

---

## 2. Workflow Engine Design

### 2.1 Le modèle : Sequential Spine with Parallel Wings (SSPW)

Validé en zt. Je le formalise ici en spec implémentable.

```
Workflow = Stage[]
Stage = {
  index: uint8,
  role: enum(CODER, REVIEWER, SECURITY_AUDITOR, TESTER, OPTIMIZER),
  parallelGroup: uint8,   // 0 = séquentiel, >0 = parallèle au sein du groupe
  budgetBps: uint16,       // basis points du budget total
  gateThreshold: uint8,    // score minimum (0-100) pour passer
  gatePolicy: enum(ALL_PASS, MAJORITY_PASS, ANY_PASS),
  timeout: uint32,         // secondes max pour ce stage
  retryCount: uint8,       // max retries avant fail workflow
  state: enum(PENDING, ACTIVE, PASSED, FAILED, SKIPPED, TIMED_OUT)
}
```

### 2.2 Les 3 patterns supportés

```
Pattern 1 — Sequential (Bronze/Silver)
┌─────────┐    ┌──────────┐    ┌──────────────┐
│  CODER  │───▶│ REVIEWER │───▶│  FINALIZE    │
└─────────┘    └──────────┘    └──────────────┘

Pattern 2 — Fan-out parallel (Gold)
                ┌────────────┐
┌─────────┐    │ REVIEWER_A │    ┌──────────────┐
│  CODER  │───▶│            │───▶│  FINALIZE    │
└─────────┘    │ REVIEWER_B │    └──────────────┘
                └────────────┘
              (parallelGroup=1)

Pattern 3 — Conditional branch (Gold+)
                ┌────────────┐
┌─────────┐    │ REVIEWER   │──pass──▶ ┌──────────┐    ┌──────────┐
│  CODER  │───▶│            │          │ TESTER   │───▶│ FINALIZE │
└─────────┘    └────────────┘          └──────────┘    └──────────┘
                      │
                     fail
                      │
                      ▼
               ┌──────────────┐
               │ RETRY CODER  │───▶ (re-enter REVIEWER)
               └──────────────┘
```

### 2.3 Orchestration : Off-chain engine, on-chain FSM

C'est le choix architectural clé. Je le justifie formellement :

| Responsabilité | On-chain (WorkflowEscrow) | Off-chain (Orchestrator) |
|---|---|---|
| Verrouillage du budget total | ✅ | |
| Transition d'état des stages | ✅ (vérifie préconditions) | |
| Distribution budget par stage | ✅ (appelle MissionEscrow) | |
| Vérification signature attestation | ✅ (ecrecover) | |
| Timeout enforcement | ✅ (block.timestamp) | |
| Matching agent au stage | | ✅ |
| Transmission artefacts entre stages | | ✅ (IPFS CID) |
| Évaluation qualité du livrable | | ✅ (agent reviewer) |
| Retry / branch logic | | ✅ (décide, puis call on-chain) |
| Notification client | | ✅ |

**Pourquoi pas tout on-chain ?**
- Un DAG engine en Solidity coûte ~500K gas par transition (stockage + boucles)
- Les artefacts (code, rapports) ne peuvent pas être on-chain
- Le jugement de qualité est intrinsèquement off-chain
- Un bug dans un workflow engine on-chain est non-patchable (même avec UUPS, c'est risqué)

**Pourquoi pas tout off-chain ?**
- Le client paye en USDC — les fonds DOIVENT être en escrow on-chain
- Les attestations de quality gate DOIVENT être vérifiables (hash + sig on-chain)
- Le timeout DOIT être enforced par block.timestamp, pas par un cron qui peut crash
- L'audit trail on-chain est le produit (c'est ce qu'on vend aux entreprises)

### 2.4 Orchestrator Service — Architecture

```typescript
// workflow-orchestrator/src/engine.ts

interface WorkflowEngine {
  // Lifecycle
  createWorkflow(issueId: string, tier: Tier, customStages?: StageConfig[]): Promise<WorkflowId>
  
  // Stage advancement
  onMissionCompleted(missionId: bytes32, artifacts: ArtifactCID[]): Promise<void>
  onGateAttestationSubmitted(workflowId: bytes32, gateIndex: number, score: number): Promise<void>
  onStageTimeout(workflowId: bytes32, stageIndex: number): Promise<void>
  
  // Retry / branch
  retryStage(workflowId: bytes32, stageIndex: number): Promise<void>
  skipStage(workflowId: bytes32, stageIndex: number, reason: string): Promise<void>
  
  // Queries
  getWorkflowStatus(workflowId: bytes32): Promise<WorkflowStatus>
  getStageArtifacts(workflowId: bytes32, stageIndex: number): Promise<ArtifactCID[]>
}
```

**Event-driven architecture :** L'Orchestrator **écoute les events du contrat** (`StageCompleted`, `GateAttestationSubmitted`, `StageTimedOut`) et réagit. Il ne poll pas. Il utilise un consumer Redis/BullMQ pour garantir at-least-once processing.

```
[Base L2 Events] → [Alchemy Webhooks] → [Orchestrator Queue] → [Engine Logic] → [Contract Calls]
```

**Idempotence :** Chaque action de l'Orchestrator est idempotente. Si le service crash et redémarre, il reconstruit l'état depuis les events on-chain + la DB PostgreSQL. Pas de state perdu.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Tier Definitions

| Aspect | Bronze | Silver | Gold | Platinum (V2) |
|--------|--------|--------|------|----------------|
| **Stages** | 1 | 2 | 4 | 5-6 custom |
| **Roles** | CODER | CODER → REVIEWER | CODER → REVIEWER_A ∥ REVIEWER_B → TESTER | CODER → REVIEWER_A ∥ REVIEWER_B → SECURITY → TESTER → OPTIMIZER |
| **Pattern** | Sequential | Sequential | SSPW (fan-out) | SSPW + conditional |
| **Budget range** | $10–$50 | $50–$200 | $200–$1,000 | $1,000+ (custom) |
| **SLA deadline** | Best effort, max 24h | 12h | 6h per stage, 24h total | Custom, contractual |
| **Quality gate** | None (auto-approve 48h) | 1 gate (score ≥ 60) | 2 gates (score ≥ 70, MAJORITY_PASS) | 3+ gates (score ≥ 80, ALL_PASS) |
| **Dispute SLA** | 72h manual | 48h reviewer panel | 24h reviewer panel + escalation | 12h SLA + dedicated arbiter |
| **Insurance** | Standard 5% | Standard 5% | Enhanced: 7% (pool contribution supérieure) | Custom: 10% + SLA penalty clause |
| **Retry policy** | 0 retry | 1 retry (même agent) | 2 retries (agent différent au 2ème) | 3 retries + fallback humain |
| **Audit trail** | Mission hash on-chain | + Gate attestation | + Parallel reviewer sigs + diff analysis | + Full compliance package (SOC2 artifact) |

### 3.2 Stage Roles — Spec

```typescript
enum StageRole {
  CODER = 'CODER',              // Produit le code/output principal
  REVIEWER = 'REVIEWER',        // Review qualité, style, correctness
  SECURITY_AUDITOR = 'SECURITY_AUDITOR',  // Vulns, dependencies, OWASP
  TESTER = 'TESTER',            // Test generation, coverage analysis
  OPTIMIZER = 'OPTIMIZER',      // Performance, gas optimization, refactor
}

// Chaque rôle a des capabilities requises dans l'AgentRegistry
const ROLE_REQUIRED_CAPABILITIES: Record<StageRole, string[]> = {
  CODER: ['code-generation', 'language:*'],      // wildcard sur le langage
  REVIEWER: ['code-review', 'static-analysis'],
  SECURITY_AUDITOR: ['security-audit', 'vulnerability-detection'],
  TESTER: ['test-generation', 'coverage-analysis'],
  OPTIMIZER: ['performance-optimization', 'refactoring'],
}
```

### 3.3 Budget Split par Tier (basis points, total = 10000)

| Component | Bronze | Silver | Gold | Platinum (V2) |
|-----------|--------|--------|------|----------------|
| CODER | 8500 | 6500 | 4500 | 3500 |
| REVIEWER_A | — | 2000 | 1500 | 1200 |
| REVIEWER_B | — | — | 1500 | 1200 |
| SECURITY | — | — | — | 1000 |
| TESTER | — | — | 1000 | 800 |
| OPTIMIZER | — | — | — | 800 |
| Platform fee (total) | 1500 | 1500 | 1500 | 1500 |
| ↳ Insurance pool | 500 | 500 | 700 | 1000 |
| ↳ AGNT burn | 300 | 300 | 300 | 200 |
| ↳ Treasury | 200 | 200 | 200 | 200 |
| ↳ Reviewer bonus pool | 500 | 500 | 300 | 100 |

**Nota :** Le "reviewer bonus pool" est une innovation de ce cycle. 5% du budget total est distribué aux reviewers qui ont fait un travail particulièrement bon (score de review > 90). Ça incite les reviewers à être thorough, pas juste à rubber-stamp.

**Invariant critique :** `sum(all budgetBps) == 10000`. Vérifié au `createWorkflow()`. Sinon revert.

---

## 4. Quality Gates

### 4.1 Architecture hybride (validée en zt, détaillée ici)

```
┌─────────────────────────────────────────────────────┐
│                 QUALITY GATE FLOW                    │
│                                                      │
│  1. Stage N complète → artifacts sur IPFS            │
│  2. Orchestrator assigne Stage N+1 (reviewer)        │
│  3. Reviewer agent pull artifacts, exécute review     │
│  4. Reviewer produit:                                │
│     - report.md (IPFS)                               │
│     - score: 0-100                                   │
│     - issues[]: {severity, location, description}    │
│     - recommendation: PASS | FAIL | PASS_WITH_NOTES  │
│  5. Reviewer signe: keccak256(workflowId, gateIdx,  │
│     score, reportHash)                               │
│  6. On-chain: submitGateAttestation(sig, score, hash)│
│  7. Contrat vérifie sig, compare score vs threshold  │
│  8. Si PASS → activateStage(next)                    │
│  9. Si FAIL → retry logic ou refund                  │
│ 10. Client: 24h challenge window                     │
└─────────────────────────────────────────────────────┘
```

### 4.2 Gate Policies

```solidity
enum GatePolicy {
    ALL_PASS,       // Tous les reviewers parallèles doivent passer (Gold)
    MAJORITY_PASS,  // >50% des reviewers passent (Gold default)
    ANY_PASS,       // Au moins un passe (low stakes only)
    WEIGHTED        // Score pondéré par reputation reviewer (V2)
}
```

**Pour Gold (2 reviewers parallèles) :**
- Default policy : `MAJORITY_PASS` (c'est-à-dire les deux doivent passer si n=2, ou 2/3 si on ajoute un tiebreaker)
- En pratique avec 2 reviewers, `MAJORITY_PASS` = les 2 passent OU on déclenche un 3ème reviewer tiebreaker
- **Décision concrète :** Si reviewer A passe (score ≥ 70) et reviewer B fail (score < 70), l'Orchestrator assigne un 3ème reviewer (coût prélevé sur le reviewer bonus pool). Le 3ème vote est définitif. C'est le **"tiebreaker pattern"**.

### 4.3 Scoring Model

```typescript
interface GateAttestation {
  workflowId: bytes32
  gateIndex: uint8
  reviewerAgentId: bytes32
  reviewerAddress: address     // pour ecrecover
  
  // Scores détaillés
  overallScore: uint8          // 0-100, weighted average
  subscores: {
    correctness: uint8         // Le code fait ce qui est demandé ?
    codeQuality: uint8         // Lisibilité, patterns, idiomatique ?
    testCoverage: uint8        // Tests présents et pertinents ?
    securityScore: uint8       // Pas de vulns évidentes ?
    specCompliance: uint8      // Respecte la TDL / issue spec ?
  }
  
  // Metadata
  reportCID: string            // IPFS hash du rapport complet
  issuesFound: uint16          // Nombre d'issues trouvées
  criticalIssues: uint16       // Nombre d'issues critiques (blockers)
  artifactHashes: bytes32[]    // Hashes des artefacts reviewés
  
  // Recommendation
  recommendation: 'PASS' | 'FAIL' | 'PASS_WITH_NOTES'
  
  // Signature
  signature: bytes             // EIP-712 typed data signature
}
```

**Threshold par tier :**

| Tier | Gate threshold | Critical issues tolerance | Auto-fail conditions |
|------|---------------|--------------------------|---------------------|
| Silver | 60 | ≤ 2 | criticalIssues > 0 |
| Gold | 70 | 0 | criticalIssues > 0 OR testCoverage < 50 |
| Platinum | 80 | 0 | criticalIssues > 0 OR testCoverage < 70 OR securityScore < 60 |

### 4.4 Challenge Window

Le client a **24 heures** après la dernière gate attestation pour challenger. Pendant ce temps, les fonds restent locked.

Challenge flow (V1 simplifié) :
1. Client appelle `challengeGate(workflowId, gateIndex, reason)`
2. Workflow passe en état `CHALLENGED`
3. Un reviewer tiers (pas les originaux) est assigné pour re-review
4. Son attestation remplace la contestée
5. Si le challenge est infondé (nouveau score confirme le premier), le client paye le coût du re-review (prélevé sur un dépôt de challenge de 5% du stage budget, requis pour challenger)

**Anti-grief :** Le dépôt de challenge empêche le client de challenger systématiquement pour retarder le paiement.

---

## 5. Smart Contract Changes

### 5.1 Nouveau contrat : `WorkflowEscrow.sol`

**Principe cardinal :** `MissionEscrow.sol` n'est PAS modifié. `WorkflowEscrow` compose avec lui.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MissionEscrow.sol";

contract WorkflowEscrow is 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // ========================
    // Types
    // ========================
    
    enum Tier { BRONZE, SILVER, GOLD }
    // PLATINUM ajouté en V2 sans breaking change
    
    enum StageRole { CODER, REVIEWER, SECURITY_AUDITOR, TESTER, OPTIMIZER }
    
    enum StageState { PENDING, ACTIVE, PASSED, FAILED, SKIPPED, TIMED_OUT }
    
    enum GatePolicy { ALL_PASS, MAJORITY_PASS, ANY_PASS }
    
    enum WorkflowState { 
        CREATED,        // Budget locked, pas encore démarré
        IN_PROGRESS,    // Au moins un stage actif
        GATE_REVIEW,    // En attente de quality gate
        CHALLENGED,     // Client a challengé une gate
        COMPLETED,      // Tous les stages passés
        FAILED,         // Un stage a fail et pas de retry
        CANCELLED,      // Client cancel avant IN_PROGRESS
        REFUNDED        // Fonds retournés
    }
    
    struct Stage {
        uint8 index;
        StageRole role;
        uint8 parallelGroup;     // 0 = sequential, >0 = parallel avec même group
        uint16 budgetBps;        // basis points du budget total
        uint8 gateThreshold;     // score min pour passer (0 = no gate)
        GatePolicy gatePolicy;
        uint32 timeout;          // secondes
        uint8 maxRetries;
        uint8 currentRetries;
        StageState state;
        bytes32 missionId;       // ID dans MissionEscrow (set à l'activation)
        bytes32 assignedAgentId; // Agent assigné (set à l'activation)
    }
    
    struct GateAttestation {
        bytes32 reviewerAgentId;
        address reviewerAddress;
        uint8 score;
        bytes32 reportHash;       // IPFS hash
        uint16 criticalIssues;
        uint256 timestamp;
        bytes signature;
        bool isValid;
    }
    
    struct Workflow {
        bytes32 workflowId;
        address client;
        Tier tier;
        uint256 totalBudget;      // USDC (6 decimals)
        uint256 lockedAmount;     // Ce qui reste en escrow dans ce contrat
        uint256 distributedAmount;// Ce qui a été envoyé aux MissionEscrow
        WorkflowState state;
        uint8 stageCount;
        uint8 currentStageIndex;  // Le plus avancé stage séquentiel
        uint256 createdAt;
        uint256 completedAt;
        string issueId;           // GitHub issue reference
        bytes32 specHash;         // Hash de la spec TDL
    }
    
    // ========================
    // Storage
    // ========================
    
    IERC20 public usdc;
    IMissionEscrow public missionEscrow;
    IAgentRegistry public agentRegistry;
    
    bytes32 public constant ORCHESTRATOR_ROLE = keccak256("ORCHESTRATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint8 public constant MAX_STAGES = 6;
    uint256 public constant CHALLENGE_DEPOSIT_BPS = 500; // 5% du stage budget
    uint256 public constant CHALLENGE_WINDOW = 24 hours;
    
    mapping(bytes32 => Workflow) public workflows;
    mapping(bytes32 => Stage[]) public workflowStages;
    mapping(bytes32 => mapping(uint8 => GateAttestation[])) public gateAttestations;
    // workflowId => gateIndex => attestations[]
    
    mapping(bytes32 => uint256) public challengeDeposits;
    // workflowId => deposit amount
    
    uint256 public emergencyWithdrawRequestTime;
    uint256 public constant EMERGENCY_TIMELOCK = 48 hours;
    
    // ========================
    // Events
    // ========================
    
    event WorkflowCreated(
        bytes32 indexed workflowId, 
        address indexed client, 
        Tier tier, 
        uint256 totalBudget,
        uint8 stageCount
    );
    event StageActivated(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        bytes32 missionId, 
        bytes32 agentId
    );
    event GateAttestationSubmitted(
        bytes32 indexed workflowId, 
        uint8 gateIndex, 
        uint8 score, 
        bytes32 reportHash
    );
    event StageCompleted(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        StageState finalState
    );
    event WorkflowCompleted(
        bytes32 indexed workflowId, 
        uint256 totalPaid
    );
    event WorkflowFailed(
        bytes32 indexed workflowId, 
        uint8 failedStageIndex, 
        string reason
    );
    event GateChallenged(
        bytes32 indexed workflowId, 
        uint8 gateIndex, 
        address challenger
    );
    
    // ========================
    // Core Functions
    // ========================
    
    function createWorkflow(
        Tier tier,
        uint256 totalBudget,
        Stage[] calldata stages,
        string calldata issueId,
        bytes32 specHash
    ) external nonReentrant returns (bytes32 workflowId) {
        // Validations
        require(stages.length > 0 && stages.length <= MAX_STAGES, "Invalid stage count");
        require(totalBudget > 0, "Budget must be positive");
        
        // Verify budgetBps sum = 10000
        uint256 totalBps;
        for (uint8 i = 0; i < stages.length; i++) {
            totalBps += stages[i].budgetBps;
        }
        require(totalBps == 10000, "Budget BPS must sum to 10000");
        
        // Validate tier matches stage count
        if (tier == Tier.BRONZE) require(stages.length == 1, "Bronze = 1 stage");
        if (tier == Tier.SILVER) require(stages.length >= 2 && stages.length <= 3, "Silver = 2-3 stages");
        if (tier == Tier.GOLD) require(stages.length >= 3 && stages.length <= 6, "Gold = 3-6 stages");
        
        // Transfer USDC from client to this contract
        require(usdc.transferFrom(msg.sender, address(this), totalBudget), "USDC transfer failed");
        
        // Create workflow
        workflowId = keccak256(abi.encode(msg.sender, block.timestamp, issueId, specHash));
        
        Workflow storage wf = workflows[workflowId];
        wf.workflowId = workflowId;
        wf.client = msg.sender;
        wf.tier = tier;
        wf.totalBudget = totalBudget;
        wf.lockedAmount = totalBudget;
        wf.state = WorkflowState.CREATED;
        wf.stageCount = uint8(stages.length);
        wf.createdAt = block.timestamp;
        wf.issueId = issueId;
        wf.specHash = specHash;
        
        // Store stages
        for (uint8 i = 0; i < stages.length; i++) {
            workflowStages[workflowId].push(stages[i]);
        }
        
        emit WorkflowCreated(workflowId, msg.sender, tier, totalBudget, uint8(stages.length));
    }
    
    function activateStage(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 agentId
    ) external onlyRole(ORCHESTRATOR_ROLE) nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(
            wf.state == WorkflowState.CREATED || wf.state == WorkflowState.IN_PROGRESS,
            "Workflow not active"
        );
        
        Stage storage stage = workflowStages[workflowId][stageIndex];
        require(stage.state == StageState.PENDING, "Stage not pending");
        
        // Verify sequential ordering (skip check for parallel stages)
        if (stage.parallelGroup == 0 && stageIndex > 0) {
            Stage storage prevStage = workflowStages[workflowId][stageIndex - 1];
            require(
                prevStage.state == StageState.PASSED || prevStage.state == StageState.SKIPPED,
                "Previous stage not completed"
            );
        }
        
        // Calculate stage budget
        uint256 stageBudget = (wf.totalBudget * stage.budgetBps) / 10000;
        
        // Approve MissionEscrow to spend USDC for this stage
        usdc.approve(address(missionEscrow), stageBudget);
        
        // Create mission in MissionEscrow
        bytes32 missionId = missionEscrow.createMission(
            agentId,
            stageBudget,
            block.timestamp + stage.timeout,
            wf.specHash  // TODO: stage-specific spec hash
        );
        
        stage.state = StageState.ACTIVE;
        stage.missionId = missionId;
        stage.assignedAgentId = agentId;
        
        wf.state = WorkflowState.IN_PROGRESS;
        wf.distributedAmount += stageBudget;
        wf.lockedAmount -= stageBudget;
        
        emit StageActivated(workflowId, stageIndex, missionId, agentId);
    }
    
    function submitGateAttestation(
        bytes32 workflowId,
        uint8 gateIndex,
        uint8 score,
        bytes32 reportHash,
        uint16 criticalIssues,
        bytes calldata signature
    ) external onlyRole(ORCHESTRATOR_ROLE) nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(wf.state == WorkflowState.IN_PROGRESS, "Workflow not in progress");
        
        // Verify signature (EIP-712)
        bytes32 digest = keccak256(abi.encode(
            workflowId, gateIndex, score, reportHash, criticalIssues
        ));
        address signer = _recoverSigner(digest, signature);
        
        // Verify signer is the assigned reviewer agent for this gate
        Stage storage gateStage = workflowStages[workflowId][gateIndex];
        require(gateStage.role == StageRole.REVIEWER || 
                gateStage.role == StageRole.SECURITY_AUDITOR, "Not a review stage");
        
        // Verify signer is the agent provider
        IAgentRegistry.AgentCard memory agent = agentRegistry.getAgent(gateStage.assignedAgentId);
        require(signer == agent.provider, "Invalid signer");
        
        // Store attestation
        gateAttestations[workflowId][gateIndex].push(GateAttestation({
            reviewerAgentId: gateStage.assignedAgentId,
            reviewerAddress: signer,
            score: score,
            reportHash: reportHash,
            criticalIssues: criticalIssues,
            timestamp: block.timestamp,
            signature: signature,
            isValid: true
        }));
        
        emit GateAttestationSubmitted(workflowId, gateIndex, score, reportHash);
        
        // Evaluate gate
        _evaluateGate(workflowId, gateIndex);
    }
    
    function challengeGate(
        bytes32 workflowId,
        uint8 gateIndex
    ) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(msg.sender == wf.client, "Only client can challenge");
        require(wf.state == WorkflowState.IN_PROGRESS, "Workflow not in progress");
        
        // Verify within challenge window
        GateAttestation[] storage attestations = gateAttestations[workflowId][gateIndex];
        require(attestations