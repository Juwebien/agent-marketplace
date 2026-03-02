

# Cycle zo — Budget-Tiered Workflows Architecture (Opus)

---

## 1. Core Insight de ce cycle

**Le budget n'achète pas du compute, il achète une réduction vérifiable de l'incertitude sur le livrable.** C'est le pivot intellectuel fondamental de ce cycle. Le marché actuel des agents IA est un commodities market : tu payes un agent, tu croises les doigts. Notre proposition est radicalement différente — le client n'achète pas "3 agents au lieu de 1", il achète un **pipeline de vérification** dont chaque stage réduit la probabilité résiduelle de défaut. Le delta économique est clair : si une entreprise perd 30% de l'output d'un agent en rework (estimé ~$15/h × 30% = $4.50/h gaspillé), un pipeline Silver à +60% du prix qui élimine 65% du rework est ROI-positif dès la première heure. Mais — et c'est la décision architecturale la plus importante — ce pipeline est un **mécanisme structurel**, pas une **garantie probabiliste**. On vend une structure (nombre de stages, types d'agents, quality gates), pas un SLA chiffré sur le taux de défaut. La raison est simple : on n'a pas les données actuarielles pour garantir un p(défaut), et encoder une telle garantie on-chain créerait un circuit de moral hazard exploitable. Le tier est donc un **menu de workflows**, pas un contrat d'assurance.

---

## 2. Workflow Engine Design

### 2.1 Pourquoi PAS un DAG arbitraire en V1

Un DAG arbitraire est un piège d'ingénierie en V1 pour trois raisons :

1. **Gas imprévisible** — la traversée d'un DAG on-chain a une complexité O(V+E) où le nombre d'edges est incontrôlable. Sur Base L2, le gas est cheap mais pas gratuit, et un DAG de 15 nœuds avec des conditions de branching peut coûter 10× le gas d'un pipeline linéaire.
2. **Surface d'attaque combinatoire** — chaque branche conditionnelle est un vecteur de dispute. "Mon agent a bien passé la quality gate du branch A, mais le client dit qu'il aurait dû prendre le branch B." Impossible à arbitrer on-chain.
3. **UX client catastrophique** — un client qui poste une issue veut choisir Bronze/Silver/Gold, pas dessiner un graphe d'exécution.

### 2.2 Les 3 patterns retenus

```
Pattern 1: SEQUENTIAL (V1 — tous les tiers)
┌──────┐    ┌──────────┐    ┌──────────┐    ┌──────┐
│ Code │───▶│  Review   │───▶│ Security │───▶│ Test │
└──────┘    └──────────┘    └──────────┘    └──────┘
  QG₁          QG₂             QG₃

Pattern 2: PARALLEL FAN-OUT (V2 — Enterprise)
                ┌──────────┐
           ┌───▶│ Security │───┐
┌──────┐   │    └──────────┘   │    ┌──────────┐
│ Code │───┤                   ├───▶│ Merge/QA │
└──────┘   │    ┌──────────┐   │    └──────────┘
           └───▶│   Test   │───┘
                └──────────┘

Pattern 3: CONDITIONAL BRANCH (V2 — Enterprise)
┌──────┐    ┌──────────┐   pass   ┌──────────┐
│ Code │───▶│  Review   │────────▶│ Security │
└──────┘    └──────────┘         └──────────┘
                 │
                 │ fail
                 ▼
            ┌──────────┐    ┌──────────┐
            │  Rework  │───▶│  Review  │ (retry, max 2)
            └──────────┘    └──────────┘
```

### 2.3 Workflow comme structure de données

```typescript
// Off-chain workflow definition (stored in IPFS, hash on-chain)
interface WorkflowDefinition {
  tier: 'BASIC' | 'STANDARD' | 'PREMIUM' | 'ENTERPRISE';
  pattern: 'SEQUENTIAL';  // V1 only
  stages: StageDefinition[];
  maxRetries: number;      // 0 pour BASIC, 1 pour STANDARD, 2 pour PREMIUM+
  timeoutTotal: number;    // seconds, sum of all stage deadlines
}

interface StageDefinition {
  index: number;           // 0-based, execution order
  role: AgentRole;         // enum: CODER | REVIEWER | SECURITY | TESTER | OPTIMIZER
  qualityGate: QualityGateConfig;
  budgetShare: number;     // basis points (e.g., 6000 = 60%)
  deadline: number;        // seconds for this stage
  isOptional: boolean;     // V2: for conditional branches
}

interface QualityGateConfig {
  threshold: number;       // 0-100, score minimum pour pass
  criteria: string[];      // human-readable, stored in IPFS
  autoPassTimeout: number; // seconds before auto-pass (48h default)
}
```

### 2.4 Cycle de vie du workflow

```
WORKFLOW STATES:
  CREATED → FUNDED → STAGE_N_ACTIVE → STAGE_N_DELIVERED → STAGE_N_QG_PENDING
    → [pass] STAGE_N+1_ACTIVE ... → ALL_STAGES_COMPLETE → COMPLETED
    → [fail + retries left] STAGE_N_RETRY → STAGE_N_ACTIVE
    → [fail + no retries]   FAILED → PARTIAL_REFUND
    → DISPUTED → RESOLVED
    → CANCELLED (before first stage ACTIVE)
```

**Invariant critique :** Le workflow est un automate fini déterministe. À chaque instant, un seul stage est `ACTIVE` (en V1 séquentiel). Le passage au stage suivant nécessite une `QualityGateAttestation` avec `score >= threshold`.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Définition des tiers

| Dimension | BASIC | STANDARD | PREMIUM | ENTERPRISE |
|-----------|-------|----------|---------|------------|
| **Stages** | 1 | 2 | 3 | 4-6 (custom) |
| **Agents** | Coder | Coder + Reviewer | Coder + Reviewer + Security Auditor | Custom pipeline |
| **Quality Gates** | Aucune (auto-approve 48h) | 1 QG (review score ≥ 60) | 2 QG (review ≥ 70, security ≥ 80) | N QG (configurable) |
| **Retries** | 0 | 1 | 2 | Configurable (max 3) |
| **SLA Deadline** | Best effort (7j) | 72h | 48h | Contractuel (custom) |
| **Budget Range** | $10-50 | $50-200 | $200-1,000 | $1,000+ |
| **Budget Multiplier** | 1× | 1.6× | 2.5× | Sur devis (≥3.5×) |
| **Insurance** | Pas de couverture | Couverture standard | Couverture étendue | SLA-backed |
| **Audit Trail** | Hash on-chain | Hash + événements | Hash + événements + rapport IPFS | Full compliance package |
| **Dry Run** | Disponible (10% prix, 5min) | Disponible | Inclus obligatoire | Inclus + staging env |
| **Dispute Resolution** | Auto-approve / simple | Reviewer arbitrage | Reviewer + expert arbitrage | Multi-sig + SLA breach auto |

### 3.2 Budget split par stage

La répartition du budget entre stages est **fixée par tier** en V1 (pas configurable par le client, pour éviter les incitations perverses — e.g., donner 1% au reviewer pour économiser).

| Tier | Stage 1 (Coder) | Stage 2 (Reviewer) | Stage 3 (Security) | Stage 4+ |
|------|-----------------|--------------------|--------------------|----------|
| BASIC | 100% | — | — | — |
| STANDARD | 70% | 30% | — | — |
| PREMIUM | 55% | 25% | 20% | — |
| ENTERPRISE | Custom (min 15% par stage) | Custom | Custom | Custom |

**Note :** Ces pourcentages s'appliquent à la part `provider` (90% du total). Les 10% de fees (5% insurance + 3% burn + 2% treasury) sont prélevés sur le budget total du workflow, pas par stage.

### 3.3 Contraintes et guard-rails

```solidity
// WorkflowEscrow constants
uint8 constant MAX_STAGES = 6;
uint8 constant MAX_RETRIES = 3;
uint16 constant MIN_STAGE_BUDGET_BPS = 1000;  // 10% minimum per stage
uint256 constant MIN_WORKFLOW_BUDGET = 10e6;   // $10 USDC (6 decimals)
uint256 constant MAX_WORKFLOW_BUDGET = 100_000e6; // $100K USDC
uint256 constant BASIC_MAX_BUDGET = 50e6;      // $50
uint256 constant STANDARD_MAX_BUDGET = 200e6;  // $200
uint256 constant PREMIUM_MAX_BUDGET = 1_000e6; // $1,000

// Tier-specific validations
function _validateTier(WorkflowTier tier, uint256 budget, uint8 stageCount) internal pure {
    if (tier == WorkflowTier.BASIC) {
        require(stageCount == 1, "BASIC_SINGLE_STAGE");
        require(budget <= BASIC_MAX_BUDGET, "BASIC_BUDGET_CAP");
    } else if (tier == WorkflowTier.STANDARD) {
        require(stageCount == 2, "STANDARD_TWO_STAGES");
        require(budget <= STANDARD_MAX_BUDGET, "STANDARD_BUDGET_CAP");
    } else if (tier == WorkflowTier.PREMIUM) {
        require(stageCount == 3, "PREMIUM_THREE_STAGES");
        require(budget <= PREMIUM_MAX_BUDGET, "PREMIUM_BUDGET_CAP");
    } else {
        require(stageCount >= 4 && stageCount <= MAX_STAGES, "ENTERPRISE_STAGE_RANGE");
        // No budget cap for enterprise
    }
}
```

**Décision architecturale : pourquoi des caps par tier ?**

Sans caps, un client pourrait poster un workflow BASIC à $10,000 — une seule passe sans review. C'est un red flag (possible blanchiment ou arbitrage d'insurance). Les caps forcent la cohérence : si tu veux dépenser $500, tu passes par PREMIUM avec 3 stages de vérification. C'est un nudge vers la qualité ET un guard-rail anti-abus.

---

## 4. Quality Gates

### 4.1 Le problème fondamental

Un smart contract ne peut pas évaluer la qualité d'un code review. Point. Toute tentative de mettre un "QA score" on-chain via un oracle centralisé recrée le problème de confiance qu'on essaie d'éliminer. Mais l'alternative — laisser le client décider seul — crée un pouvoir asymétrique (le client peut refuser indéfiniment pour récupérer ses fonds).

### 4.2 Solution : Attestation off-chain avec commitment on-chain

```
┌─────────────────────────────────────────────────────┐
│                    OFF-CHAIN                         │
│                                                     │
│  1. Agent Stage N produit un livrable               │
│  2. Agent Stage N+1 (reviewer) évalue               │
│  3. Reviewer produit :                              │
│     - Rapport détaillé (markdown, stocké IPFS)      │
│     - Score numérique (0-100)                       │
│     - Signature (ecrecover)                         │
│  4. Hash(rapport) + score + sig envoyés on-chain    │
│                                                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                    ON-CHAIN                          │
│                                                     │
│  QualityGateAttestation {                           │
│    workflowId: bytes32                              │
│    stageIndex: uint8                                │
│    reportHash: bytes32  // keccak256(IPFS content)  │
│    score: uint8         // 0-100                    │
│    reviewer: address    // ecrecover from sig       │
│    timestamp: uint256                               │
│    passed: bool         // score >= threshold       │
│  }                                                  │
│                                                     │
│  IF passed → advanceStage()                         │
│  IF !passed && retries > 0 → retryStage()           │
│  IF !passed && retries == 0 → failWorkflow()        │
│                                                     │
│  CHALLENGE WINDOW: 24h after attestation            │
│  Client OR provider can dispute → reveal IPFS       │
│                                                     │
└────────────────────────────────────────���────────────┘
```

### 4.3 Critères de scoring par rôle

Les critères ne sont PAS évalués on-chain — ils sont dans le prompt du reviewer agent et dans le rapport IPFS. Mais ils sont standardisés pour la reproductibilité.

| Rôle Reviewer | Critères | Threshold Défaut | Poids |
|---------------|----------|-------------------|-------|
| **Code Reviewer** | Correctness (40%), Readability (20%), Edge cases (20%), Best practices (20%) | 60/100 | — |
| **Security Auditor** | Vulnerability scan (30%), Input validation (25%), Auth/Authz (25%), Data handling (20%) | 80/100 | — |
| **Tester** | Coverage (30%), Edge cases (30%), Regression (20%), Performance (20%) | 70/100 | — |
| **Optimizer** | Gas/Perf improvement (40%), Backward compat (30%), Measurable gain (30%) | 65/100 | — |

### 4.4 Anti-gaming des Quality Gates

**Problème :** Le reviewer est un agent, pas un humain. Il pourrait :
- Toujours donner 100/100 (caoutchouc-stamper) pour finir vite et être payé
- Toujours donner 0/100 pour forcer des retries et multiplier ses fees (si payé par retry)
- Collusion avec le coder (même provider)

**Mitigations :**

| Risque | Mitigation | Implémentation |
|--------|------------|----------------|
| Rubber-stamping | Score distribution monitoring — alert si > 90% des scores sont ��� 90 | Off-chain analytics, rep penalty |
| Score bombing | Reviewer payé un montant fixe par stage, pas par retry | Budget split fixe (§3.2) |
| Self-review (collusion) | **Contrainte hard : le reviewer NE PEUT PAS être du même provider que le coder** | On-chain check : `require(stages[n].provider != stages[n+1].provider)` |
| Sybil (même provider, 2 comptes) | Staking minimum + reputation history | Le reviewer doit avoir ≥ 5 missions complétées ET un stake actif |

```solidity
function _validateStageAssignment(
    bytes32 workflowId,
    uint8 stageIndex,
    address provider
) internal view {
    // Anti-collusion: reviewer cannot be same provider as reviewed stage
    if (stageIndex > 0) {
        address previousProvider = workflows[workflowId]
            .stages[stageIndex - 1].provider;
        require(provider != previousProvider, "SAME_PROVIDER_CONSECUTIVE");
    }
    
    // Anti-sybil: reviewer must have reputation
    if (_isReviewerRole(workflows[workflowId].stages[stageIndex].role)) {
        IAgentRegistry.Reputation memory rep = registry.getReputation(
            workflows[workflowId].stages[stageIndex].agentId
        );
        require(rep.totalMissions >= 5, "INSUFFICIENT_REVIEWER_HISTORY");
        require(staking.getTier(provider) >= StakeTier.BRONZE, "REVIEWER_MUST_STAKE");
    }
}
```

### 4.5 Timeout et auto-pass

| Situation | Comportement |
|-----------|--------------|
| Reviewer ne soumet pas d'attestation en 24h | Stage auto-passed (score = threshold) |
| Client ne dispute pas en 24h post-attestation | Attestation finalisée |
| Workflow entier dépasse le deadline total | Workflow FAILED, partial refund proportionnel aux stages complétés |
| Stage dépasse son deadline individuel | Stage FAILED, retry si disponible, sinon workflow FAILED |

---

## 5. Smart Contract Changes

### 5.1 Nouveau contrat : WorkflowEscrow.sol

**Principe fondamental :** `WorkflowEscrow` **compose** avec `MissionEscrow`, il n'en hérite pas. Le MissionEscrow existant (323 lignes, 14/14 tests) reste INCHANGÉ. Le WorkflowEscrow est un meta-client qui appelle `MissionEscrow.createMission()` pour chaque stage.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IMissionEscrow {
    function createMission(bytes32 agentId, uint256 totalAmount, uint256 deadline, string calldata ipfsMissionHash) external returns (bytes32);
    function approveMission(bytes32 missionId) external;
    function cancelMission(bytes32 missionId) external;
    function getMissionState(bytes32 missionId) external view returns (uint8);
}

interface IAgentRegistry {
    function getAgent(bytes32 agentId) external view returns (address provider, bool isActive);
    function getReputation(bytes32 agentId) external view returns (uint256 totalMissions, uint256 successRate);
}

contract WorkflowEscrow is 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // ─── Constants ───
    uint8 public constant MAX_STAGES = 6;
    uint8 public constant MAX_RETRIES = 3;
    uint16 public constant MIN_STAGE_BUDGET_BPS = 1000; // 10%
    uint256 public constant CHALLENGE_WINDOW = 24 hours;
    uint256 public constant REVIEWER_AUTO_PASS_TIMEOUT = 24 hours;
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    // ─── Enums ───
    enum WorkflowTier { BASIC, STANDARD, PREMIUM, ENTERPRISE }
    
    enum WorkflowState { 
        CREATED,        // Workflow defined, not yet funded
        FUNDED,         // USDC deposited
        ACTIVE,         // At least one stage running
        COMPLETED,      // All stages passed
        FAILED,         // Non-recoverable failure
        DISPUTED,       // Under arbitration
        CANCELLED,      // Cancelled before ACTIVE
        PARTIAL_REFUND  // Some stages completed, remainder refunded
    }
    
    enum StageState {
        PENDING,        // Waiting for previous stage
        ASSIGNED,       // Agent matched, not started
        ACTIVE,         // Agent working
        DELIVERED,      // Agent submitted output
        QG_PENDING,     // Quality gate evaluation in progress
        PASSED,         // Quality gate passed
        FAILED,         // Quality gate failed
        RETRYING,       // Failed but retry available
        SKIPPED         // Optional stage skipped
    }
    
    enum AgentRole {
        CODER,
        REVIEWER,
        SECURITY_AUDITOR,
        TESTER,
        OPTIMIZER
    }

    // ─── Structs ───
    struct QualityGateConfig {
        uint8 threshold;           // 0-100
        uint256 autoPassTimeout;   // seconds
        string criteriaIpfsHash;   // IPFS hash of criteria doc
    }
    
    struct QualityGateAttestation {
        bytes32 reportHash;        // keccak256(IPFS report content)
        uint8 score;
        address reviewer;
        uint256 timestamp;
        bool passed;
        bool challenged;
        bool finalized;
    }
    
    struct Stage {
        AgentRole role;
        bytes32 agentId;
        address provider;
        uint256 budget;            // USDC amount for this stage
        uint256 deadline;          // seconds from stage start
        uint256 startedAt;
        uint8 retriesLeft;
        StageState state;
        bytes32 missionId;         // reference to MissionEscrow mission
        QualityGateConfig qgConfig;
        QualityGateAttestation qgAttestation;
        string outputIpfsHash;
    }
    
    struct Workflow {
        bytes32 workflowId;
        address client;
        WorkflowTier tier;
        WorkflowState state;
        uint256 totalBudget;       // Total USDC deposited
        uint256 createdAt;
        uint256 deadline;          // Total workflow deadline
        uint8 currentStage;        // Index of active stage
        uint8 stageCount;
        string specIpfsHash;       // Full workflow spec on IPFS
        mapping(uint8 => Stage) stages;
    }

    // ─── State ───
    IMissionEscrow public missionEscrow;
    IAgentRegistry public agentRegistry;
    IERC20 public usdc;
    
    mapping(bytes32 => Workflow) public workflows;
    mapping(bytes32 => bytes32) public missionToWorkflow; // missionId → workflowId
    
    uint256 public workflowCount;

    // ─── Events ───
    event WorkflowCreated(bytes32 indexed workflowId, address indexed client, WorkflowTier tier, uint256 budget);
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageAssigned(bytes32 indexed workflowId, uint8 stageIndex, bytes32 agentId);
    event StageStarted(bytes32 indexed workflowId, uint8 stageIndex);
    event StageDelivered(bytes32 indexed workflowId, uint8 stageIndex, string outputIpfsHash);
    event QualityGateSubmitted(bytes32 indexed workflowId, uint8 stageIndex, uint8 score, bool passed);
    event QualityGateChallenged(bytes32 indexed workflowId, uint8 stageIndex, address challenger);
    event StageAdvanced(bytes32 indexed workflowId, uint8 fromStage, uint8 toStage);
    event StageRetried(bytes32 indexed workflowId, uint8 stageIndex, uint8 retriesLeft);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowFailed(bytes32 indexed workflowId, uint8 failedStage, string reason);
    event WorkflowDisputed(bytes32 indexed workflowId, uint8 stageIndex);

    // ─── Core Functions ───
    
    function createWorkflow(
        WorkflowTier tier,
        uint256 totalBudget,
        uint256 deadline,
        StageInput[] calldata stageInputs,
        string calldata specIpfsHash
    ) external nonReentrant returns (bytes32 workflowId) {
        require(stageInputs.length >= 1 && stageInputs.length <= MAX_STAGES, "INVALID_STAGE_COUNT");
        _validateTier(tier, totalBudget, uint8(stageInputs.length));
        _validateBudgetSplit(stageInputs, totalBudget);
        
        workflowId = keccak256(abi.encodePacked(
            msg.sender, block.timestamp, workflowCount++
        ));
        
        Workflow storage wf = workflows[workflowId];
        wf.workflowId = workflowId;
        wf.client = msg.sender;
        wf.tier = tier;
        wf.state = WorkflowState.CREATED;
        wf.totalBudget = totalBudget;
        wf.createdAt = block.timestamp;
        wf.deadline = deadline;
        wf.stageCount = uint8(stageInputs.length);
        wf.specIpfsHash = specIpfsHash;
        
        for (uint8 i = 0; i < stageInputs.length; i++) {
            wf.stages[i] = Stage({
                role: stageInputs[i].role,
                agentId: bytes32(0),     // assigned later
                provider: address(0),
                budget: stageInputs[i].budget,
                deadline: stageInputs[i].deadline,
                startedAt: 0,
                retriesLeft: stageInputs[i].maxRetries,
                state: i == 0 ? StageState.PENDING : StageState.PENDING,
                missionId: bytes32(0),
                qgConfig: stageInputs[i].qgConfig,
                qgAttestation: QualityGateAttestation(bytes32(0), 0, address(0), 0, false, false, false),
                outputIpfsHash: ""
            });
        }
        
        emit WorkflowCreated(workflowId, msg.sender, tier, totalBudget);
    }
    
    function fundWorkflow(bytes32 workflowId) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(wf.state == WorkflowState.CREATED, "NOT_CREATED");
        require(msg.sender == wf.client, "NOT_CLIENT");
        
        usdc.transferFrom(msg.sender, address(this), wf.totalBudget);
        wf.state = WorkflowState.FUNDED;
        
        emit WorkflowFunded(workflowId, wf.totalBudget);
    }
    
    function assignStage(
        bytes32 workflowId, 
        uint8 stageIndex, 
        bytes32 agentId
    ) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(wf.state == WorkflowState.FUNDED || wf.state == WorkflowState.ACTIVE, "NOT_ACTIVE");
        
        Stage storage stage = wf.stages[stageIndex];
        require(stage.state == StageState.PENDING || stage.state == StageState.RETRYING, "STAGE_NOT_ASSIGNABLE");
        
        (address provider, bool isActive) = agentRegistry.getAgent(agentId);
        require(isActive, "AGENT_INACTIVE");
        
        _validateStageAssignment(workflowId, stageIndex, provider);
        
        stage.agentId = agentId;
        stage.provider = provider;
        stage.state = StageState.ASSIGNED;
        
        // Create mission in MissionEscrow for this stage
        usdc.approve(address(missionEscrow), stage.budget);
        stage.missionId = missionEscrow.createMission(
            agentId,
            stage.budget,
            stage.deadline,
            wf.specIpfsHash
        );
        missionToWorkflow[stage.missionId] = workflowId;
        
        emit StageAssigned(workflowId, stageIndex, agentId);
    }
    
    function submitQualityGate(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 reportHash,
        uint8 score,
        bytes calldata signature
    ) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        Stage storage stage = wf.stages[stageIndex];
        require(stage.state == StageState.DELIVERED, "NOT_DELIVERED");
        
        // Verify reviewer signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            workflowId, stageIndex, reportHash, score
        ));
        address reviewer = _recoverSigner(messageHash, signature);
        
        // Reviewer must be the agent assigned to the NEXT stage (reviewer role)
        // OR an independent reviewer if this is the last stage
        _validateReviewer(workflowId, stageIndex, reviewer);
        
        bool passed = score >= stage.qgConfig.threshold;
        
        stage.qgAttestation = QualityGateAttestation({
            reportHash: reportHash,
            score: score,
            reviewer: reviewer,
            timestamp: block.timestamp,
            passed: passed,
            challenged: false,
            finalized: false
        });
        
        stage.state = StageState.QG_PENDING;
        
        emit QualityGateSubmitted(workflowId, stageIndex, score, passed);
        
        // Start challenge window — finalization happens after 24h or via finalizeQG()
    }
    
    function finalizeQualityGate(
        bytes32 workflowId, 
        uint8 stageIndex
    ) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        Stage storage stage = wf.stages[stageIndex];
        require(stage.state == StageState.QG_PENDING, "NOT_QG_PENDING");
        require(!stage.qgAttestation.challenged, "UNDER_CHALLENGE");
        require(
            block.timestamp >= stage.qgAttestation.timestamp + CHALLENGE_WINDOW,
            "CHALLENGE_WINDOW_OPEN"
        );
        
        stage.qgAt