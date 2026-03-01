

# Cycle zi — Budget-Tiered Workflows Architecture

---

## 1. Core Insight de ce cycle

**Le workflow multi-agent est le produit, pas une feature.** Les cycles précédents ont traité le workflow tiered comme une extension du système de missions standalone. C'est une erreur de cadrage. L'insight central est que le marché des agents IA standalone (un client, un agent, une tâche) est déjà commoditisé — c'est ce que font Devin, Factory, Codegen, et tous les wrappers autour de Claude/GPT. Ce qui n'existe pas encore, c'est un **marché composable de chaînes de qualité** où le client n'achète pas un agent mais un *niveau de confiance vérifiable* dans le résultat. Le produit n'est pas "hire an agent" mais "buy an audited outcome". Concrètement, cela signifie que `WorkflowEscrow.sol` n'est pas un wrapper optionnel autour de `MissionEscrow.sol` — c'est le **contrat principal** que 80% des clients enterprise utiliseront. `MissionEscrow` devient l'unité atomique interne que le workflow orchestre, exactement comme un microservice est rarement exposé directement à l'utilisateur final. Ce reframing a des conséquences profondes : le pricing, le matching, la réputation, et l'insurance doivent tous être redesignés autour du workflow comme entité première, pas de la mission individuelle.

---

## 2. Workflow Engine Design

### 2.1 Modèle retenu : Pipeline Séquentiel Contraint (V1)

Le cycle zh a tranché : pas de DAG arbitraire. Je valide mais avec une nuance architecturale importante.

```
┌─────────────────────────────────────────────────────────────┐
│                    WORKFLOW (on-chain)                       │
│                                                             │
│  Stage 0        Stage 1        Stage 2        Stage 3       │
│  ┌──────┐  QG  ┌──────┐  QG  ┌──────┐  QG  ┌──────┐      │
│  │CODER │──→──│REVIEW│──→──│SECUITY│──→──│TESTER│      │
│  └──────┘  ↓   └──────┘  ↓   └──────┘  ↓   └──────┘      │
│         pass/fail     pass/fail     pass/fail               │
│            │             │             │                     │
│         [FAIL]        [FAIL]        [FAIL]                  │
│            ↓             ↓             ↓                     │
│      retry/abort    retry/abort   retry/abort               │
└─────────────────────────────────���───────────────────────────┘
```

### 2.2 Entités du modèle

```
Workflow
├── workflowId: bytes32
├── clientAddress: address
├── tier: enum {BRONZE, SILVER, GOLD, PLATINUM}
├── totalBudget: uint256 (USDC)
├── stages: Stage[] (ordered, max 6)
├── currentStage: uint8
├── state: WorkflowState
└── metadata: bytes32 (IPFS hash du TDL complet)

Stage
├── stageIndex: uint8
├── role: bytes32 (CODER | REVIEWER | SECURITY | TESTER | OPTIMIZER | CUSTOM)
├── missionId: bytes32 (→ MissionEscrow)
├── agentId: bytes32
├── budgetAllocation: uint256
├── qualityGateConfig: QualityGateConfig
├── state: StageState
├── maxRetries: uint8
└── retriesUsed: uint8

QualityGateConfig
├── minScore: uint8 (0-100, seuil pour pass)
├── disputeWindow: uint64 (seconds)
├── requiresHumanReview: bool (Platinum only)
└── attesters: address[] (whitelist optionnelle)
```

### 2.3 State Machine du Workflow

```
CREATED → FUNDED → STAGE_ACTIVE → STAGE_DELIVERED → GATE_PENDING
    │                                                    │
    │                                          ┌─────────┴────────┐
    │                                          │                  │
    │                                     GATE_PASSED        GATE_FAILED
    │                                          │                  │
    │                                   ┌──────┘           ┌──────┴──────┐
    │                                   │                  │             │
    │                              next stage?          retries       ABORTED
    │                                   │               left?         (partial
    │                              ┌────┴────┐           │            refund)
    │                              │         │        retry stage
    │                          COMPLETED   STAGE_ACTIVE
    │                         (release all)
    │
    └── CANCELLED (before FUNDED only)
```

**Points de design critiques :**

1. **Retry budget** : Chaque stage a un `maxRetries` (défaut: 1 pour Bronze, 2 pour Gold/Platinum). Un retry re-crée une mission dans MissionEscrow avec le *même* budget allocation du stage. Le coût du retry est absorbé par le provider du stage échoué (il ne touche pas sa part). Si un agent différent est matché au retry, le provider initial perd son allocation.

2. **Abort partiel** : Si un stage échoue après épuisement des retries, le workflow s'arrête. Les stages *complétés* sont payés. Le budget des stages *non exécutés* est refunded au client, moins les frais gas estimés.

3. **Pas de rollback** : Un stage validé est définitif. On ne revient pas en arrière. Si le stage 3 (tester) révèle un bug du stage 0 (coder), c'est un *nouveau* workflow ou une dispute sur le stage 0.

### 2.4 Pourquoi pas Fan-out en V1 — Challenge technique

Le fan-out (2 reviewers en parallèle) est tentant mais pose 3 problèmes non résolus :

| Problème | Impact | Mitigation V2 |
|----------|--------|----------------|
| **Merge strategy** | Que faire si reviewer A dit pass et reviewer B dit fail ? Majorité ? Pondération par rep ? | Voting scheme pondéré par rep score |
| **Budget split** | Comment répartir le budget du stage entre agents parallèles ? Égal ? Proportionnel ? | Auction intra-stage |
| **Timing** | L'agent le plus lent bloque tout le workflow ; timeout par agent ajoute de la complexité | Per-agent deadline avec fallback |

**Décision V1 :** Séquentiel strict. Un stage = un agent = un quality gate. La simplicité est une feature.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Principe fondamental

Le tier encode un **niveau de vérification**, pas une quantité de compute. La matrice :

| Tier | Agents | Stages | SLA Deadline | Dispute Window | Max Retries/Stage | Budget Range | Target Use Case |
|------|--------|--------|-------------|----------------|-------------------|-------------|-----------------|
| **BRONZE** | 1 | 1 (Coder) | 24h | 24h | 0 | $10–$50 | Typo fix, config change, docs update |
| **SILVER** | 2 | 2 (Coder → Reviewer) | 48h | 48h | 1 | $50–$200 | Feature implementation, bug fix |
| **GOLD** | 4 | 4 (Coder → Reviewer → Security → Tester) | 72h | 72h | 2 | $200–$1,000 | API endpoint, smart contract modification |
| **PLATINUM** | 6 | 5-6 (Coder → Reviewer → Security → Tester → Optimizer + Human QA) | 1 week | 1 week | 2 | $1,000+ | Production deployment, compliance-critical |

### 3.2 Stage Definitions par Tier

#### BRONZE — Exécution directe
```yaml
stages:
  - role: CODER
    budget_pct: 100
    quality_gate: NONE  # auto-pass, client 48h review window
```
C'est exactement le MissionEscrow actuel. Pas de workflow overhead. Le `WorkflowEscrow` crée une seule mission et agit comme un passthrough transparent.

#### SILVER — Code + Review
```yaml
stages:
  - role: CODER
    budget_pct: 70
    quality_gate:
      min_score: 60
      dispute_window: 48h
  - role: REVIEWER
    budget_pct: 30
    quality_gate:
      type: FINAL
      dispute_window: 48h
```

**Contrainte critique :** Le REVIEWER ne peut pas être du même provider que le CODER. Vérifié on-chain via `require(stages[i].provider != stages[i-1].provider)`.

#### GOLD — Full Engineering Pipeline
```yaml
stages:
  - role: CODER
    budget_pct: 50
    quality_gate:
      min_score: 70
      dispute_window: 72h
  - role: REVIEWER
    budget_pct: 20
    quality_gate:
      min_score: 70
      dispute_window: 72h
  - role: SECURITY_AUDITOR
    budget_pct: 15
    quality_gate:
      min_score: 80  # plus strict
      dispute_window: 72h
  - role: TESTER
    budget_pct: 15
    quality_gate:
      type: FINAL
      dispute_window: 72h
```

**Contrainte : au minimum 3 providers distincts sur 4 stages.** Le CODER peut être du même provider que le TESTER (ils ne s'évaluent pas mutuellement), mais REVIEWER et SECURITY doivent être indépendants.

#### PLATINUM — Enterprise Grade
```yaml
stages:
  - role: CODER
    budget_pct: 35
    quality_gate:
      min_score: 80
      dispute_window: 1w
  - role: REVIEWER
    budget_pct: 15
    quality_gate:
      min_score: 80
      dispute_window: 1w
  - role: SECURITY_AUDITOR
    budget_pct: 15
    quality_gate:
      min_score: 90
      dispute_window: 1w
  - role: TESTER
    budget_pct: 15
    quality_gate:
      min_score: 80
      dispute_window: 1w
  - role: OPTIMIZER
    budget_pct: 10
    quality_gate:
      min_score: 80
      dispute_window: 1w
  - role: HUMAN_QA
    budget_pct: 10
    quality_gate:
      type: FINAL_HUMAN
      requires_human_review: true
```

**HUMAN_QA** : Ce stage est exécuté par un human reviewer inscrit dans un registre séparé (`HumanReviewerRegistry`). C'est un différenciateur Platinum. Le human signe une attestation avec son wallet — même pattern que les autres quality gates mais avec un `isHuman: true` flag vérifié par le registry.

### 3.3 Budget Minimums par Tier (on-chain enforced)

```solidity
uint256 constant BRONZE_MIN = 10e6;    // $10 USDC
uint256 constant SILVER_MIN = 50e6;    // $50 USDC
uint256 constant GOLD_MIN = 200e6;     // $200 USDC
uint256 constant PLATINUM_MIN = 1000e6; // $1,000 USDC
```

Pas de maximum on-chain (le marché décide), mais le frontend affiche des warnings au-dessus de seuils raisonnables (e.g., > $5k pour Gold).

### 3.4 Tier Suggestion Algorithm (off-chain, Plan Compiler)

```python
def suggest_tier(tdl: TaskDefinition) -> TierSuggestion:
    risk_score = 0
    
    # Complexity signals
    if tdl.touches_smart_contracts: risk_score += 30
    if tdl.touches_auth_or_crypto: risk_score += 25
    if tdl.touches_database_schema: risk_score += 15
    if tdl.lines_estimate > 500: risk_score += 20
    if tdl.has_external_dependencies: risk_score += 10
    if tdl.is_production_deploy: risk_score += 40
    
    # Semantic analysis via embedding similarity
    risk_score += semantic_risk_score(tdl.description)  # 0-20
    
    if risk_score <= 15: return BRONZE
    if risk_score <= 40: return SILVER
    if risk_score <= 70: return GOLD
    return PLATINUM
```

Le client voit : *"Based on analysis, we recommend **Gold** tier for this task (touches smart contracts + auth). Estimated cost: $320-$450. [Accept] [Override to Silver ↓] [Override to Platinum ↑]"*

---

## 4. Quality Gates

### 4.1 Architecture confirmée : Off-chain judgment, On-chain commitment

Cycle zh a tranché et je renforce. Le quality gate est un **protocole en 3 phases** :

```
Phase 1: PRODUCTION (off-chain)
  L'agent du stage N produit son output → stocké IPFS → CID
  
Phase 2: REVIEW (off-chain)  
  L'agent du stage N+1 reçoit le CID comme input
  Il produit un QualityGateReport:
    - score: uint8 (0-100)
    - findings: Finding[] (severity, description, line_ref)
    - recommendation: PASS | FAIL | PASS_WITH_NOTES
    - report_cid: string (rapport complet sur IPFS)
  
Phase 3: COMMITMENT (on-chain)
  L'agent signe et soumet:
    advanceStage(workflowId, stageIndex, outputCID, score, reportCID, signature)
  Le contrat vérifie:
    - signature valide de l'agent assigné au stage N+1
    - score >= qualityGateConfig.minScore → auto-advance
    - score < minScore → GATE_FAILED
  Fenêtre de dispute ouverte.
```

### 4.2 Scoring Spec

Le score n'est pas arbitraire. Le Quality Gate Report suit un schema standardisé :

```json
{
  "$schema": "agent-marketplace/qg-report/v1",
  "categories": {
    "correctness": { "weight": 0.35, "score": 85 },
    "security": { "weight": 0.25, "score": 70 },
    "test_coverage": { "weight": 0.20, "score": 90 },
    "code_quality": { "weight": 0.10, "score": 75 },
    "documentation": { "weight": 0.10, "score": 60 }
  },
  "weighted_score": 79,
  "findings": [
    {
      "severity": "HIGH",
      "category": "security",
      "description": "Unchecked return value on external call",
      "file": "src/Handler.sol",
      "line": 42,
      "recommendation": "Add require() wrapper"
    }
  ],
  "recommendation": "PASS_WITH_NOTES",
  "attestation": {
    "agent_id": "0x...",
    "timestamp": 1709337600,
    "signature": "0x..."
  }
}
```

**Weights par tier :**

| Category | Bronze | Silver | Gold | Platinum |
|----------|--------|--------|------|----------|
| Correctness | 100% | 50% | 35% | 30% |
| Security | 0% | 15% | 25% | 25% |
| Test Coverage | 0% | 20% | 20% | 20% |
| Code Quality | 0% | 10% | 10% | 10% |
| Documentation | 0% | 5% | 10% | 15% |

Bronze n'a pas de quality gate formel (auto-pass), mais ces weights servent pour le score de réputation post-completion.

### 4.3 Seuils de passage

| Tier | Min Score Pass | Min Score Pass-with-Notes | Findings Block |
|------|---------------|--------------------------|----------------|
| Bronze | N/A | N/A | N/A |
| Silver | 60 | 50 (si 0 HIGH findings) | Any CRITICAL |
| Gold | 70 | 60 (si 0 HIGH findings) | Any HIGH or CRITICAL |
| Platinum | 80 | 75 (si 0 MEDIUM+ findings) | Any MEDIUM, HIGH, or CRITICAL |

### 4.4 Anti-gaming : Le problème du reviewer complaisant

**Risque :** Un agent reviewer systématiquement indulgent pour accumuler des missions (il approuve tout, les clients content à court terme, mais la qualité se dégrade).

**Mitigations :**

1. **Review of the reviewer** : Sur un échantillon aléatoire (10% des Gold+), un second reviewer indépendant re-score le même output. Si l'écart est > 20 points, le premier reviewer est flaggé. 3 flags = suspension temporaire + perte de rep.

2. **Calibration score** : Chaque reviewer a un `calibration_deviation` tracké. Si un reviewer donne systématiquement des scores 25+ points au-dessus de la médiane du pool, son rep baisse automatiquement.

3. **Post-hoc correction** : Si le client file un dispute sur le résultat final et gagne, tous les reviewers intermédiaires qui ont donné un PASS subissent un malus rep (proportionnel à leur score vs le score du disputeur).

4. **Skin in the game** : Les reviewers stakent aussi. Un reviewer Gold doit avoir au moins 2,000 AGNT stakés (2x le minimum provider). Platinum : 5,000 AGNT.

---

## 5. Smart Contract Changes

### 5.1 Nouveau contrat : `WorkflowEscrow.sol`

Ce contrat **compose** avec `MissionEscrow.sol` — il ne le modifie pas. Les 14 tests Foundry existants restent verts.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./MissionEscrow.sol";
import "./AgentRegistry.sol";

contract WorkflowEscrow is 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // ══════════════════════════════════════════════
    //                    ENUMS
    // ═��════════════════════════════════════════════
    
    enum Tier { BRONZE, SILVER, GOLD, PLATINUM }
    
    enum WorkflowState {
        CREATED,        // Workflow defined, not yet funded
        FUNDED,         // USDC deposited
        ACTIVE,         // At least one stage in progress
        COMPLETED,      // All stages passed
        ABORTED,        // Stage failed after max retries
        CANCELLED       // Client cancelled before funding
    }
    
    enum StageState {
        PENDING,        // Not yet started
        MISSION_CREATED,// MissionEscrow mission created
        DELIVERED,      // Agent delivered output
        GATE_PENDING,   // Awaiting quality gate attestation
        GATE_PASSED,    // Quality gate passed
        GATE_FAILED,    // Quality gate failed
        RETRYING,       // Re-executing with same or different agent
        SKIPPED         // Stage skipped (abort scenario)
    }
    
    // ══════════════════════════════════════════════
    //                   STRUCTS
    // ══════════════════════════════════════════════
    
    struct QualityGateConfig {
        uint8 minScore;          // 0-100
        uint64 disputeWindow;    // seconds
        bool requiresHumanReview;
        uint8 maxRetries;
    }
    
    struct Stage {
        bytes32 role;            // keccak256("CODER"), keccak256("REVIEWER"), etc.
        bytes32 agentId;         // assigned agent
        address provider;        // agent provider address
        bytes32 missionId;       // → MissionEscrow
        uint256 budgetAllocation;// USDC amount for this stage
        StageState state;
        QualityGateConfig gateConfig;
        uint8 retriesUsed;
        bytes32 outputCID;       // IPFS hash of stage output
        bytes32 gatteReportCID;  // IPFS hash of QG report
        uint8 gateScore;
    }
    
    struct Workflow {
        bytes32 workflowId;
        address client;
        Tier tier;
        uint256 totalBudget;     // USDC total
        uint256 totalFees;       // platform fees (split per existing 90/5/3/2)
        uint8 stageCount;
        uint8 currentStage;
        WorkflowState state;
        bytes32 tdlHash;         // IPFS hash of Task Definition
        uint256 createdAt;
        uint256 completedAt;
        uint256 slaDeadline;     // absolute deadline for entire workflow
    }
    
    // ══════════════════════════════════════════════
    //                   STORAGE
    // ══════════════════════════════════════════════
    
    MissionEscrow public missionEscrow;
    AgentRegistry public agentRegistry;
    IERC20 public usdc;
    
    mapping(bytes32 => Workflow) public workflows;
    mapping(bytes32 => Stage[]) public workflowStages;
    
    // Tier minimum budgets (USDC, 6 decimals)
    mapping(Tier => uint256) public tierMinBudget;
    mapping(Tier => uint8) public tierStageCount;
    
    // Provider independence constraint
    // workflowId => stageIndex => provider cannot be same as these stages
    // Enforced: reviewer != coder, security != coder
    
    uint8 public constant MAX_STAGES = 6;
    
    // ══════════════════════════════════════════════
    //                   EVENTS
    // ══════════════════════════════════════════════
    
    event WorkflowCreated(
        bytes32 indexed workflowId, 
        address indexed client, 
        Tier tier, 
        uint256 totalBudget,
        uint8 stageCount
    );
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageStarted(bytes32 indexed workflowId, uint8 stageIndex, bytes32 missionId);
    event StageDelivered(bytes32 indexed workflowId, uint8 stageIndex, bytes32 outputCID);
    event QualityGateSubmitted(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        uint8 score, 
        bool passed
    );
    event StageRetrying(bytes32 indexed workflowId, uint8 stageIndex, uint8 retryCount);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowAborted(bytes32 indexed workflowId, uint8 failedStage, uint256 refundAmount);
    
    // ══════════════════════════════════════════════
    //                CORE FUNCTIONS
    // ══════════════════════════════════════════════
    
    /// @notice Create a workflow with pre-defined stages based on tier
    /// @param tier The quality tier (determines number of stages)
    /// @param totalBudget Total USDC to allocate across all stages
    /// @param tdlHash IPFS hash of the Task Definition Language document
    /// @param agentIds Pre-selected agents for each stage (can be bytes32(0) for auto-match)
    /// @param budgetSplits Percentage allocation per stage (must sum to 10000 = 100.00%)
    function createWorkflow(
        Tier tier,
        uint256 totalBudget,
        bytes32 tdlHash,
        bytes32[] calldata agentIds,
        uint16[] calldata budgetSplits,
        uint256 slaDeadline
    ) external returns (bytes32 workflowId) {
        require(totalBudget >= tierMinBudget[tier], "Budget below tier minimum");
        require(agentIds.length == tierStageCount[tier], "Wrong number of agents");
        require(budgetSplits.length == tierStageCount[tier], "Wrong number of splits");
        require(slaDeadline > block.timestamp, "Deadline in past");
        
        // Verify budget splits sum to 100%
        uint16 totalSplit;
        for (uint8 i = 0; i < budgetSplits.length; i++) {
            totalSplit += budgetSplits[i];
        }
        require(totalSplit == 10000, "Splits must sum to 10000");
        
        workflowId = keccak256(abi.encodePacked(
            msg.sender, 
            block.timestamp, 
            tdlHash,
            block.chainid
        ));
        
        // Calculate platform fees on total budget
        uint256 netBudget = _deductPlatformFees(totalBudget);
        
        Workflow storage wf = workflows[workflowId];
        wf.workflowId = workflowId;
        wf.client = msg.sender;
        wf.tier = tier;
        wf.totalBudget = totalBudget;
        wf.totalFees = totalBudget - netBudget;
        wf.stageCount = uint8(agentIds.length);
        wf.currentStage = 0;
        wf.state = WorkflowState.CREATED;
        wf.tdlHash = tdlHash;
        wf.createdAt = block.timestamp;
        wf.slaDeadline = slaDeadline;
        
        // Create stages
        bytes32[] memory roles = _getRolesForTier(tier);
        QualityGateConfig[] memory gateConfigs = _getGateConfigsForTier(tier);
        
        for (uint8 i = 0; i < agentIds.length; i++) {
            Stage memory stage;
            stage.role = roles[i];
            stage.agentId = agentIds[i];
            stage.budgetAllocation = (netBudget * budgetSplits[i]) / 10000;
            stage.state = StageState.PENDING;
            stage.gateConfig = gateConfigs[i];
            
            // Enforce provider independence for review stages
            if (agentIds[i] != bytes32(0)) {
                address provider = agentRegistry.getAgent(agentIds[i]).provider;
                stage.provider = provider;
                _enforceProviderIndependence(workflowId, i, provider, roles[i]);
            }
            
            workflowStages[workflowId].push(stage);
        }
        
        emit WorkflowCreated(workflowId, msg.sender, tier, totalBudget, wf.stageCount);
    }
    
    /// @notice Fund the workflow — transfers USDC from client to this contract
    function fundWorkflow(bytes32 workflowId) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(wf.client == msg.sender, "Not client");
        require(wf.state == WorkflowState.CREATED, "Already funded");
        
        usdc.transferFrom(msg.sender, address(this), wf.totalBudget);
        wf.state = WorkflowState.FUNDED;
        
        emit WorkflowFunded(workflowId, wf.totalBudget);
    }
    
    /// @notice Start the first (or next) stage by creating a mission in MissionEscrow
    function startNextStage(bytes32 workflowId) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(wf.state == WorkflowState.FUNDED || wf.state == WorkflowState.ACTIVE, "Not active");
        
        uint8 idx = wf.currentStage;
        Stage storage stage = workflowStages[workflowId][idx];
        require(stage.state == StageState.PENDING || stage.state == StageState.RETRYING, "Stage not ready");
        
        // If first stage, transition to ACTIVE
        if (wf.state == WorkflowState.FUNDED) {
            wf.state = WorkflowState.ACTIVE;
        }
        
        // Approve USDC for MissionEscrow
        usdc.approve(address(missionEscrow), stage.budgetAllocation);
        
        // Create mission in MissionEscrow — WorkflowEscrow acts as the "client"
        bytes32 missionId = missionEscrow.createMission(
            stage.agentId,
            stage.budgetAllocation,
            wf.slaDeadline,  // TODO: per-stage deadline calculation
            string(abi.encodePacked(wf.tdlHash)) // pass TDL as mission spec
        );
        
        stage.missionId = missionId;
        stage.state = StageState.MISSION_CREATED;
        
        emit StageStarted(workflowId, idx, missionId);
    }
    
    /// @notice Submit quality gate attestation for a completed stage
    /// @dev Called by the next-stage agent or an authorized reviewer
    function submitQualityGate(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 outputCID,
        bytes32 reportCID,
        uint8 score,
        bytes calldata attestorSignature
    ) external {
        Workflow storage wf = workflows[workflowId];
        Stage storage stage = workflowStages[workflowId][stageIndex];
        
        require(stage.state == StageState.DELIVERED, "Stage not delivered");
        
        // Verify attestor is authorized (next stage agent or whitelisted reviewer)
        _verifyAttestor(workflowId, stageIndex, msg.sender, attestorSignature);
        
        stage.outputCID = outputCID;
        stage.gatteReportCID = reportCID;
        stage.g