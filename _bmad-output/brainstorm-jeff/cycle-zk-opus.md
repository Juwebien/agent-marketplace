

# Cycle zk — Budget-Tiered Workflows Architecture (Opus)

---

## 1. Core Insight de ce cycle

**Le Budget-Tiered Workflow n'est pas un feature — c'est le _business model_ de la plateforme.** Les cycles précédents ont construit un escrow mission-par-mission. Ce cycle transforme la plateforme d'un "marché d'agents unitaires" en une **usine d'assurance qualité programmable**. L'insight central : le client n'achète pas des agents, il achète une **probabilité de succès garantie par un pipeline vérifiable**. Un budget Bronze dit "je tolère 30% de rework, donne-moi un résultat vite fait". Un budget Gold dit "je ne tolérerai pas de rework, fais passer mon code par 4 spécialistes avec des seuils exigeants avant de me livrer". C'est un changement de paradigme : le "produit" de la marketplace n'est plus l'agent individuel, c'est le **workflow orchestré avec un contrat de confiance mesurable**. Cela positionne la plateforme dans un espace complètement vide — ni Fiverr (pas de quality pipeline), ni GitHub Actions (pas de marketplace d'agents), ni les DAO de bounties (pas d'escrow multi-étapes avec quality gates). Le corollaire économique est puissant : le revenu moyen par mission passe de ~$100 (un agent) à ~$500-$2000 (un workflow Gold/Platinum), et les fees du protocole suivent proportionnellement. C'est la mécanique qui transforme l'AGNT burn en pression déflationnaire réelle.

---

## 2. Workflow Engine Design

### 2.1 Modèle retenu : Pipeline séquentiel contraint (V1) avec extension points

Le cycle zj a validé : **pipeline séquentiel uniquement en V1**. Ce cycle durcit cette décision et spécifie exactement le modèle de données et les transitions.

#### Pourquoi pas un DAG libre en V1

| Critère | Pipeline séquentiel | DAG arbitraire |
|---------|---------------------|----------------|
| Gas prévisible | Oui (O(n) stages) | Non (traversée récursive) |
| Chemins de dispute | 1 par stage | 2^n combinatoire |
| UX client | "Votre mission passe par 4 étapes" | "Voici un graphe de 12 nœuds" |
| Testabilité | 14 tests existants suffisent comme base | Explosion combinatoire des test cases |
| Temps d'implémentation | ~2 semaines | ~8 semaines |

#### Modèle de données : WorkflowPlan

```typescript
interface WorkflowPlan {
  id: string;                    // UUID
  planHash: bytes32;             // keccak256(abi.encode(stages, budgetSplits, qgConfigs))
  tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';
  totalBudgetUSDC: number;
  stages: Stage[];               // ordered, max 6
  qualityGates: QualityGateConfig[]; // stages.length - 1 gates (between stages)
  compiledAt: number;            // timestamp
  compiledBy: string;            // version du WorkflowCompiler
}

interface Stage {
  index: number;                 // 0-based
  role: AgentRole;               // 'CODER' | 'REVIEWER' | 'SECURITY_AUDITOR' | 'TESTER' | 'OPTIMIZER'
  budgetPercentage: number;      // sum across all stages = 100
  budgetUSDC: number;            // calculated
  timeoutMinutes: number;        // max time for this stage
  requiredCapabilities: string[];// tags that agent must match
  minReputationScore: number;    // minimum rep pour être eligible
}

interface QualityGateConfig {
  afterStageIndex: number;       // gate sits between stage[i] and stage[i+1]
  type: 'AUTOMATED' | 'PEER_REVIEW' | 'SECURITY_SCAN' | 'HUMAN_OVERRIDE';
  threshold: number;             // 0-100, score minimum to pass
  timeoutMinutes: number;        // max time for QG evaluation
  fallbackOnTimeout: 'PASS' | 'FAIL'; // what happens if reviewer doesn't respond
}
```

#### Machine à états du Workflow

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                                                         │
PLAN_CREATED ──→ FUNDED ──→ STAGE_0_ACTIVE ──→ STAGE_0_DELIVERED            │
                                                      │                      │
                                          ┌───────────┴───────────┐          │
                                          ▼                       ▼          │
                                    QG_0_PASSED             QG_0_FAILED      │
                                          │                       │          │
                                          ▼                       ▼          │
                                 STAGE_1_ACTIVE           WORKFLOW_FAILED ◄──┘
                                          │                       │
                                         ...                 (refund logic)
                                          │
                                          ▼
                               FINAL_STAGE_DELIVERED
                                          │
                                          ▼
                              WORKFLOW_COMPLETED (funds released)
                              
Parallel track at any active stage:
  STAGE_n_ACTIVE ──→ STAGE_n_DISPUTED ──→ DISPUTE_RESOLVED ──→ (back to flow or FAILED)
```

**Points critiques de design :**

1. **Chaque stage est une Mission** — Le `WorkflowOrchestrator` crée des `Mission` via le `MissionEscrow` existant. Pas de duplication de logique d'escrow.

2. **Les fonds sont lockés en totalité à la création** — Le client `approve(totalBudget)` une seule fois. Le WorkflowOrchestrator distribue par stage. Pas de risque de sous-financement mid-workflow.

3. **Fail-fast : un stage en échec arrête le pipeline** — En V1, pas de retry automatique. Le client récupère les fonds non consommés des stages restants. La logique de retry/rebranching vient en V1.5.

4. **L'output du stage N est l'input du stage N+1** — Chaîné via IPFS CID. Le `Stage.outputCID` du stage courant est passé en `Stage.inputCID` du suivant. Ça crée une trace d'audit immutable.

### 2.2 Extension points V1.5+

Pour ne pas se bloquer, le design V1 inclut des hooks :

```solidity
// Dans WorkflowOrchestrator.sol
event StageCompleted(uint indexed workflowId, uint8 stageIndex, bytes32 outputHash);
event QualityGateEvaluated(uint indexed workflowId, uint8 gateIndex, uint8 score, bool passed);
event WorkflowBranched(uint indexed workflowId, uint8 fromStage, uint8 toBranch); // V1.5

// Le struct Workflow inclut dès V1 :
uint8 public constant MAX_STAGES = 6;
// Et un champ réservé :
bytes32 reserved; // pour future extension (branching config, parallel sync, etc.)
```

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Philosophie de pricing

Le prix d'un tier ne se calcule pas en additionnant les coûts des agents. Le prix se calcule à partir de la **valeur de la réduction de rework pour le client**.

Formule fondamentale :

```
Tier_Value = Base_Cost × (1 + Quality_Multiplier)

where:
  Base_Cost        = Estimated cost of the task by a single capable agent
  Quality_Multiplier = f(number_of_gates, threshold_strictness, SLA_guarantees)
```

### 3.2 Tier Matrix détaillée

| | **Bronze** | **Silver** | **Gold** | **Platinum** |
|---|---|---|---|---|
| **Budget Range** | $10 – $200 | $200 – $1,000 | $1,000 – $5,000 | $5,000+ (custom) |
| **Stages** | 1–2 | 3 | 4–5 | 6 + custom |
| **Pipeline type** | `Code → (optional Test)` | `Code → Review → Test` | `Code → Review → Security → Test → (Optimize)` | Custom pipeline + dedicated reviewers |
| **Quality Gates** | 0–1 (automated only) | 2 (automated + peer) | 3–4 (auto + peer + security + regression) | 4+ (all + human-in-the-loop possible) |
| **QG Threshold** | 60/100 | 75/100 | 85/100 | 90/100 |
| **QG Timeout Fallback** | PASS (best effort) | PASS (avec warning) | FAIL (strict) | FAIL (zero tolerance) |
| **Stage Timeouts** | 60min per stage | 120min per stage | 180min per stage | Custom SLA |
| **Agent Min Rep** | 0 (any agent) | 50/100 | 70/100 | 85/100 |
| **Agent Min Stake Tier** | NONE | BRONZE | SILVER | GOLD |
| **Dispute Resolution** | Auto-resolve (48h) | Reviewer panel (3) | Reviewer panel (5) + multisig | Dedicated arbitrator + insurance |
| **Insurance Coverage** | None | 1x mission value | 2x mission value | Custom (up to 5x) |
| **SLA Commitment** | Best effort | 90% on-time | 95% on-time | 99% on-time + penalty clause |
| **Audit Trail** | Basic (mission events) | Full (stage outputs + QG reports) | Full + security scan artifacts | Full + compliance export (SOC2) |
| **Expected Rework Rate** | ~30% (baseline) | ~15% | ~5% | <2% |

### 3.3 Budget Split par Tier (default, overridable par le WorkflowCompiler)

**Bronze (2 stages) :**
| Stage | Role | Budget % |
|-------|------|----------|
| 0 | Coder | 85% |
| 1 | Tester (auto) | 15% |

**Silver (3 stages) :**
| Stage | Role | Budget % |
|-------|------|----------|
| 0 | Coder | 60% |
| 1 | Reviewer | 20% |
| 2 | Tester | 20% |

**Gold (5 stages) :**
| Stage | Role | Budget % |
|-------|------|----------|
| 0 | Architect/Planner | 10% |
| 1 | Coder | 40% |
| 2 | Reviewer | 20% |
| 3 | Security Auditor | 15% |
| 4 | Tester + Regression | 15% |

**Platinum (6 stages, example) :**
| Stage | Role | Budget % |
|-------|------|----------|
| 0 | Architect/Planner | 8% |
| 1 | Coder | 35% |
| 2 | Reviewer | 15% |
| 3 | Security Auditor | 15% |
| 4 | Performance Optimizer | 12% |
| 5 | Integration Tester | 15% |

### 3.4 Tier auto-detection

Le WorkflowCompiler propose un tier basé sur :

```python
def suggest_tier(budget_usdc: float, issue_complexity: str, client_history: dict) -> Tier:
    if budget_usdc < 200:
        return Tier.BRONZE
    if budget_usdc < 1000:
        base = Tier.SILVER
    elif budget_usdc < 5000:
        base = Tier.GOLD
    else:
        base = Tier.PLATINUM
    
    # Upgrade si l'issue est complexe (NLP analysis du TDL)
    if issue_complexity == 'high' and base.value < Tier.GOLD.value:
        base = Tier(base.value + 1)
    
    # Downgrade si le client a un historique de missions simples réussies
    if client_history.get('avg_rework_rate', 0.3) < 0.1 and base.value > Tier.BRONZE.value:
        # Client a peu de rework → il peut se permettre un tier moins élevé
        pass  # on suggère mais on ne force pas
    
    return base
```

**Crucial :** Le client peut TOUJOURS override le tier. La suggestion est advisory. Forcer un tier = tuer l'adoption.

---

## 4. Quality Gates

### 4.1 Le problème fondamental

Un Quality Gate (QG) est un point de décision binaire : `PASS` ou `FAIL`. La difficulté : **qui décide ?** Le output d'un agent (code, review, scan) est subjectif. Un smart contract ne peut pas parser du code. On a donc un **oracle problem** appliqué à la qualité logicielle.

### 4.2 Architecture retenue : 3 types de QG

#### Type A — Automated Gate (tous tiers)

```
Trigger : Stage N deliver son outputCID
Process :
  1. WorkflowOrchestrator émet event StageDelivered(workflowId, stageIndex, outputCID)
  2. QG Runner (off-chain) fetch l'output depuis IPFS
  3. Exécute des checks objectifs :
     - Tests passent ? (exit code 0)
     - Coverage > seuil ? (lcov parse)
     - Linter clean ? (0 errors)
     - Semgrep security scan ? (0 critical findings)
  4. Produit un rapport JSON + score [0-100]
  5. Signe le rapport : sign(keccak256(rapport), qg_runner_key)
  6. Submit on-chain : submitGateAttestation(workflowId, stageIndex, reportHash, score, signature)
  7. Smart contract : score >= threshold ? advance : fail
```

**Composants objectifs du score :**

| Check | Weight (default) | Source |
|-------|-----------------|--------|
| Tests pass | 30 | exit code |
| Test coverage | 20 | lcov |
| Lint clean | 10 | eslint/ruff |
| Security scan | 25 | Semgrep |
| Build success | 15 | compilation |
| **Total** | **100** | |

Ces weights sont configurables par tier et par stage dans le `QualityGateConfig`.

#### Type B — Peer Review Gate (Silver+)

```
Trigger : Automated Gate passed OR tier requires peer review
Process :
  1. WorkflowOrchestrator demande un reviewer au MatchingEngine
  2. Constraint HARD : reviewer.address != stage_agent.address
  3. Constraint HARD : reviewer.provider != stage_agent.provider (pas le même provider)
  4. Reviewer agent reçoit le webhook : { outputCID, stage_context, previous_stages_outputs }
  5. Reviewer produit : code review comments + score [0-100] + rapport
  6. Submit attestation on-chain (même flow que Type A)
  7. Score >= threshold ? advance : fail
```

**Anti-collusion (critique) :**
- Le reviewer est sélectionné par le **protocole**, pas par le provider du stage courant
- Le reviewer est payé par le **workflow budget** (inclus dans le budget split), pas par le provider
- Si un reviewer donne systématiquement 100/100, sa réputation de reviewer baisse (détection statistique off-chain, impact on-chain via `RecordReviewerOutcome`)

#### Type C — Security Scan Gate (Gold+)

Extension du Type A avec des checks spécialisés :

```
Additional checks:
  - Dependency audit (npm audit / pip-audit) : 0 critical vulns
  - License compliance (SPDX scan) : no GPL in MIT project
  - Secret detection (truffleHog) : 0 findings
  - OWASP Top 10 patterns (Semgrep rulesets)
  - Docker image CVE scan (Trivy) if applicable
```

Le score security est un **sub-score** séparé du score qualité général. Un seul finding `CRITICAL` = score plafonné à 40/100, ce qui fait fail sur Gold (threshold 85).

#### Type D — Human Override Gate (Platinum only, V2)

Un humain (désigné par le client ou un arbitre de la plateforme) peut intervenir pour :
- Override un `FAIL` → forcer `PASS` (avec attestation signée)
- Override un `PASS` → forcer `FAIL` + dispute
- Ajouter des commentaires libres

Non implémenté en V1. Le hook existe :

```solidity
function humanOverride(uint workflowId, uint8 gateIndex, bool pass, bytes calldata signature) 
    external 
    onlyRole(HUMAN_ARBITER_ROLE) 
{
    // V2 implementation
    revert("Not implemented in V1");
}
```

### 4.3 QG Timeout & Fallback

| Tier | Timeout per QG | Fallback |
|------|---------------|----------|
| Bronze | 15min | PASS |
| Silver | 30min | PASS + warning event |
| Gold | 60min | FAIL + refund stage |
| Platinum | 120min | FAIL + escalate to arbiter |

**Pourquoi Bronze/Silver default PASS :** Pour ne pas bloquer le pipeline sur un reviewer absent. Le client de ces tiers a accepté un niveau de risque plus élevé. Sur Gold/Platinum, la promesse de qualité exige que l'absence de review = échec.

### 4.4 Flux on-chain du QG

```solidity
struct QualityGateAttestation {
    bytes32 workflowId;
    uint8 stageIndex;
    bytes32 reportHash;      // keccak256(JSON report stored on IPFS)
    uint8 score;             // 0-100
    address reviewer;        // address of the reviewing agent/runner
    uint64 timestamp;
    bytes signature;          // reviewer's signature over (workflowId, stageIndex, reportHash, score)
}

mapping(bytes32 => mapping(uint8 => QualityGateAttestation)) public gateAttestations;

function submitGateAttestation(
    bytes32 workflowId,
    uint8 stageIndex,
    bytes32 reportHash,
    uint8 score,
    bytes calldata signature
) external {
    Workflow storage wf = workflows[workflowId];
    require(wf.state == WorkflowState.GATE_PENDING, "Not in gate phase");
    require(stageIndex == wf.currentStageIndex, "Wrong stage");
    
    // Verify signature
    bytes32 message = keccak256(abi.encodePacked(workflowId, stageIndex, reportHash, score));
    address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(message), signature);
    require(signer != address(0), "Invalid signature");
    require(signer != wf.stages[stageIndex].agent, "Reviewer cannot be stage agent");
    
    gateAttestations[workflowId][stageIndex] = QualityGateAttestation({
        workflowId: workflowId,
        stageIndex: stageIndex,
        reportHash: reportHash,
        score: score,
        reviewer: signer,
        timestamp: uint64(block.timestamp),
        signature: signature
    });
    
    QualityGateConfig memory config = wf.qualityGates[stageIndex];
    
    if (score >= config.threshold) {
        _advanceStage(workflowId);
        emit QualityGatePassed(workflowId, stageIndex, score);
    } else {
        _failWorkflow(workflowId, stageIndex);
        emit QualityGateFailed(workflowId, stageIndex, score, config.threshold);
    }
}
```

---

## 5. Smart Contract Changes

### 5.1 Principes architecturaux

1. **`MissionEscrow.sol` ne change PAS** — Les 14 tests restent verts. Le workflow compose par-dessus.
2. **Nouveau contrat : `WorkflowOrchestrator.sol`** — UUPS upgradeable, compose `MissionEscrow`.
3. **Le WorkflowOrchestrator agit comme un "meta-client"** — Il crée des missions dans MissionEscrow au nom du vrai client.
4. **Les fonds sont dans le WorkflowOrchestrator** — Le client `approve()` vers l'Orchestrator, qui `approve()` vers MissionEscrow par stage.

### 5.2 WorkflowOrchestrator.sol — Interface complète

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface IWorkflowOrchestrator {
    
    // ─── Enums ──────────────────────────────────────────────
    
    enum WorkflowState {
        CREATED,          // Plan committed, not funded
        FUNDED,           // USDC locked in orchestrator
        STAGE_ACTIVE,     // Current stage mission is in progress
        GATE_PENDING,     // Waiting for QG attestation
        COMPLETED,        // All stages passed, funds distributed
        FAILED,           // QG failed, partial refund
        DISPUTED,         // Client challenged a QG attestation
        CANCELLED         // Client cancelled before first stage started
    }
    
    enum Tier { BRONZE, SILVER, GOLD, PLATINUM }
    
    enum GateType { AUTOMATED, PEER_REVIEW, SECURITY_SCAN, HUMAN_OVERRIDE }
    
    // ─── Structs ────────────────────────────────────────────
    
    struct StageConfig {
        bytes32 agentRole;           // keccak256("CODER"), keccak256("REVIEWER"), etc.
        uint16 budgetBps;            // basis points (sum = 10000)
        uint32 timeoutSeconds;
        bytes32[] requiredCapabilities;
        uint8 minReputationScore;    // 0-100
    }
    
    struct QualityGateConfig {
        GateType gateType;
        uint8 threshold;             // 0-100
        uint32 timeoutSeconds;
        bool failOnTimeout;          // true = FAIL if timeout, false = PASS
    }
    
    struct Workflow {
        bytes32 id;
        address client;
        Tier tier;
        uint256 totalBudgetUSDC;
        bytes32 planHash;            // keccak256 of the full plan (stages + gates)
        
        StageConfig[] stages;
        QualityGateConfig[] gates;   // length = stages.length - 1
        
        WorkflowState state;
        uint8 currentStageIndex;
        bytes32 currentMissionId;    // mission ID in MissionEscrow
        
        uint256 createdAt;
        uint256 fundedAt;
        uint256 completedAt;
        
        // Tracking
        bytes32[] stageOutputCIDs;   // IPFS hashes of each stage output
        address[] stageAgents;       // agents assigned to each stage
        uint256 fundsConsumed;       // total USDC spent so far
    }
    
    // ─── Events ────────────────��────────────────────────────
    
    event WorkflowCreated(bytes32 indexed workflowId, address indexed client, Tier tier, uint256 budget);
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageStarted(bytes32 indexed workflowId, uint8 stageIndex, bytes32 missionId, address agent);
    event StageDelivered(bytes32 indexed workflowId, uint8 stageIndex, bytes32 outputCID);
    event QualityGatePassed(bytes32 indexed workflowId, uint8 gateIndex, uint8 score);
    event QualityGateFailed(bytes32 indexed workflowId, uint8 gateIndex, uint8 score, uint8 threshold);
    event QualityGateTimedOut(bytes32 indexed workflowId, uint8 gateIndex, bool passedByDefault);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowFailed(bytes32 indexed workflowId, uint8 failedAtStage, uint256 refunded);
    event WorkflowDisputed(bytes32 indexed workflowId, uint8 stageIndex, string reason);
    event WorkflowCancelled(bytes32 indexed workflowId, uint256 refunded);
    
    // ─── Core Functions ─────────────────────────────────────
    
    /// @notice Create a workflow from a compiled plan
    /// @param planHash The keccak256 of the full plan (for integrity verification)
    /// @param tier The quality tier
    /// @param totalBudget Total USDC budget (must be pre-approved)
    /// @param stages Ordered array of stage configurations
    /// @param gates Quality gate configs (length = stages.length - 1)
    function createWorkflow(
        bytes32 planHash,
        Tier tier,
        uint256 totalBudget,
        StageConfig[] calldata stages,
        QualityGateConfig[] calldata gates
    ) external returns (bytes32 workflowId);
    
    /// @notice Fund the workflow (transfer USDC from client to orchestrator)
    function fundWorkflow(bytes32 workflowId) external;
    
    /// @notice Assign an agent to the current stage and start it
    /// @dev Called by the matching engine (ORCHESTRATOR_ROLE)
    function startStage(
        bytes32 workflowId,
        address agent,
        bytes32 agentId
    ) external;
    
    /// @notice Called when a stage's mission is delivered (via MissionEscrow callback)
    function onStageDelivered(
        bytes32 workflowId,
        bytes32 outputCID
    ) external;
    
    /// @notice Submit a quality gate attestation
    function submitGateAttestation(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 reportHash,
        uint8 score,
        bytes calldata signature
    ) external;
    
    /// @notice Handle QG timeout — can be called by anyone after timeout
    function triggerGateTimeout(bytes32 workflowId) external;
    
    /// @notice Client disputes a QG attestation
    function disputeGate(
        bytes32 workflowId,
        uint8 gateIndex,
        string calldata reason
    ) external;
    
    /// @notice Cancel workflow (only before first stage starts)
    function cancelWorkflow(bytes32 workflowId) external;
    
    // ─── View Functions ─────────────────────────────────────
    
    function getWorkflow(bytes32 workflowId) external view returns (Workflow memory);
    function getWorkflowState(bytes32 workflowId) external view returns (WorkflowState);
    function getStageOutput(bytes32 workflowId, uint8 stageIndex) external view returns (bytes32 outputCID);
    function getGateAttestation(bytes32 workflowId, uint8 gateIndex) external view returns (QualityGateAttestation memory);
    function estimateWorkflowCost(Tier tier, uint256 baseBudget) external view returns (uint256);
}
```

### 5.3 Interactions MissionEscrow ↔ WorkflowOrchestrator

```
┌───────────────┐     createMission()     ┌─────────────────┐
│  Workflow      │ ──────────────────────→ │  MissionEscrow  │
│  Orchestrator  │                         │  (unchanged)    │
│                │ ←── missionId ───────── │                 │
│                │                         │                 │
│  (holds total  │     approveMission()    │                 │
│   USDC budget) │ ──────────────────────→ │  (releases to   │
│                │                         │   provider)     │
│                │ ←── event Completed ─── │                 │
└───────────────┘                         └─────────────────┘
        │
        │  Per stage, the Orchestrator:
        │  1. approve(missionEscrow, stageBudget) — USDC for this stage
        │  2. createMission(agentId, stageBudget, deadline, ipfsHash)
        │  3. Waits for mission delivery
        │  4. Runs QG
        │  5. If QG pass: approveMission() → advance
        │  6. If QG fail: disputeMission() or cancel remaining
```

**Modification minimale requise sur MissionEscrow :**

Un seul changement : permettre au `WorkflowOrchestrator` d'agir **au nom du client**. Deux options :

**Option A — Delegation pattern (préféré) :**
```solidity
// Ajout dans MissionEscrow.sol (minimal, non-breaking)
mapping(address => mapping(address => bool)) public approvedDelegates;

function setDelegate(address delegate, bool approved) external {
    approvedDelegates[msg.sender][delegate] = approved;
    emit DelegateSet(msg.sender, delegate, approved);
}

modifier onlyClientOrDelegate(bytes32 missionId) {
    Mission storage m = missions[missionId];
    require(
        msg.sender == m.client || approvedDelegates[m.client][msg.sender],
        "Not authorized"
    );
    _;
}

// Modifier les fonctions existantes pour utiliser onlyClientOrDelegate au lieu de onlyClient
// Affecte : approveMission(), disputeMission(), cancelMission()
```

**Impact sur les 14 tests :** Aucun test ne casse. Le `approvedDelegates` est vide par défaut, donc le comportement existant est inchangé. On ajoute 3-4 tests pour le delegation.

**Option B — WorkflowOrchestrator crée les missions en