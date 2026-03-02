

# Cycle zr — Budget-Tiered Workflows Architecture (Opus)

---

## 1. Core Insight de ce cycle

**Le budget n'achète ni du compute, ni des adversaires — il achète une probabilité de conformité contractualisée.**

Les cycles précédents ont identifié que "le budget achète des adversaires, pas du compute" (zq §1.1). C'est juste mais incomplet. L'insight terminal est plus précis : chaque tier correspond à un **engagement probabiliste mesurable** sur le taux de défaut résiduel de l'output. Un workflow BRONZE livre avec ~25% de probabilité de rework (comparable au marché actuel). Un workflow GOLD contractualise une probabilité de rework <5%, non pas parce que les agents sont "meilleurs", mais parce que le pipeline de vérification est structurellement plus profond — chaque stage adversarial élimine une classe de défauts que le stage précédent ne couvrait pas. Cela transforme le marketplace d'un **labour marketplace** (vendre du temps-agent) en un **insurance product** (vendre de la réduction de risque mesurable avec des métriques vérifiables). Le corollaire business est que le pricing suit une courbe de prime de risque, pas une courbe de coût marginal de compute, ce qui donne un moat économique : un concurrent qui copie l'UX sans le réseau d'agents adversariaux spécialisés ne peut pas reproduire les métriques de défaut résiduel.

---

## 2. Workflow Engine Design

### 2.1 Modèle retenu : Pipeline séquentiel strict avec conditional exit

Confirmé par le cycle zq : séquentiel en V1, max 6 stages, pas de DAG arbitraire. Voici la spec complète du moteur.

### 2.2 Anatomie d'un Workflow

```
┌─────────────────────────────────────────────────────────┐
│                    WORKFLOW (on-chain)                   │
│  workflowId, client, tier, totalBudget, state           │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │ Stage 0  │──►│ Stage 1  │──►│ Stage 2  │──► ...     │
│  │ CODER    │   │ REVIEWER │   │ SECURITY │            │
│  │ Mission₀ │   │ Mission₁ │   │ Mission₂ │            │
│  └──────────┘   └──────────┘   └──────────┘            │
│       │              │              │                   │
│       ▼              ▼              ▼                   │
│   [Gate 0]       [Gate 1]       [Gate 2]               │
│   (auto-pass)    (score≥T)      (score≥T)              │
│       │              │    ╲                              │
│       ▼              ▼     ╲──► FAIL → halt/retry       │
│     PASS           PASS                                 │
└─────────────────────────────────────────────────────────┘
```

### 2.3 Stage Definition

```typescript
interface StageDefinition {
  role: StageRole;          // CODER | REVIEWER | SECURITY_AUDITOR | TESTER | OPTIMIZER
  agentId?: bytes32;        // pre-assigned (optional, marketplace selects if null)
  budgetAllocation: uint16; // basis points (e.g., 6000 = 60% of total)
  gateConfig: {
    threshold: uint8;       // 0-100 score threshold for pass
    required: boolean;      // if false, stage is advisory (output logged, not blocking)
    timeout: uint32;        // seconds before auto-escalation
  };
  inputFrom: uint8;         // stage index whose output becomes this stage's input (always previous in V1)
}

enum StageRole {
  CODER,              // Produces the primary deliverable
  REVIEWER,           // Code review, logic validation
  SECURITY_AUDITOR,   // Vulnerability scan, threat modeling
  TESTER,             // Test generation and execution
  OPTIMIZER,          // Performance, gas, cost optimization
  COMPLIANCE          // License, regulatory checks (Platinum only)
}
```

### 2.4 Workflow State Machine

```
WORKFLOW_CREATED
  │
  ├── client funds total budget → WORKFLOW_FUNDED
  │                                    │
  │                                    ├── Stage 0 mission created → STAGE_0_ACTIVE
  │                                    │                                │
  │                                    │   Stage 0 delivered ──────────┤
  │                                    │                                │
  │                                    │   Gate 0 evaluated            │
  │                                    │     ├── PASS → STAGE_1_ACTIVE (create mission 1)
  │                                    │     └── FAIL → STAGE_0_RETRY (max 1 retry)
  │                                    │                  └── 2nd FAIL → WORKFLOW_FAILED
  │                                    │
  │                                    │   ... repeat for all stages ...
  │                                    │
  │                                    └── Last gate PASS → WORKFLOW_COMPLETED
  │                                                         └── release all funds
  │
  ├── WORKFLOW_DISPUTED (client disputes any stage)
  │     └── WORKFLOW_RESOLVED
  │
  └── WORKFLOW_CANCELLED (before first stage accepts)
        └── full refund
```

### 2.5 Conditional Exit (pas du branching)

En V1, pas de "si gate fail → branch vers stage alternatif". La seule condition est :

| Gate Result | Action |
|-------------|--------|
| PASS (score ≥ threshold) | Advance to stage N+1 |
| SOFT_FAIL (score 40-threshold) | Retry stage N avec même agent (1 retry max, pas de coût additionnel — c'est l'obligation du provider) |
| HARD_FAIL (score < 40) | Halt workflow. Slash agent du stage N. Refund client pour stages non-exécutés. Payer stages complétés. |

Cela élimine le problème de blame attribution multi-branch identifié en zq §2.2.

### 2.6 Pourquoi pas de parallèle en V1

Le fan-out parallèle (mentionné en cycle za comme pattern retenu) est **différé à V2**. Raisons :

1. **Coordination de résultats** : un merge de 2 outputs parallèles nécessite un agent "merger" → complexité du DAG
2. **Budget split ambiguë** : si A et B sont parallèles et que B fail, on refund combien ?
3. **Le séquentiel couvre le use case core** : coder → review → test est le workflow le plus demandé, et il est intrinsèquement séquentiel
4. **Le parallèle est additif** : l'ajouter en V2 ne casse rien, le retirer est impossible

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Philosophie des tiers

Chaque tier n'est **pas** un package figé. C'est un **template de workflow** avec des paramètres par défaut que le client peut ajuster dans les limites du tier. Le tier définit :
- Le nombre de stages adversariaux (hors stage 0 : le coder)
- Les thresholds de quality gates
- Les SLA temporels
- Les garanties d'insurance

### 3.2 Spec complète

| Paramètre | BRONZE | SILVER | GOLD | PLATINUM |
|-----------|--------|--------|------|----------|
| **Stages totaux** | 1 | 2-3 | 4-5 | 5-6 |
| **Stage 0 (Coder)** | ✅ | ✅ | ✅ | ✅ |
| **Stage 1 (Reviewer)** | ❌ | ✅ | ✅ | ✅ |
| **Stage 2 (Security)** | ❌ | Optional | ✅ | ✅ |
| **Stage 3 (Tester)** | ❌ | ❌ | ✅ | ✅ |
| **Stage 4 (Optimizer)** | ❌ | ❌ | Optional | ✅ |
| **Stage 5 (Compliance)** | ❌ | ❌ | ❌ | ✅ |
| **Gate threshold** | N/A (pas de gate) | 60/100 | 70/100 | 80/100 |
| **Retry allowed** | N/A | 1 per stage | 1 per stage | 2 per stage |
| **SLA delivery** | Best effort (7d max) | 72h | 48h | 24h + dedicated |
| **Auto-approve** | 48h | 48h | 24h | Manual only |
| **Insurance coverage** | 0x | 1x mission value | 2x mission value | 3x + SLA penalties |
| **Dispute escalation** | Multisig only | Multisig | Multisig + priority | Dedicated arbitrator |
| **Budget range** | $10-50 | $50-200 | $200-1,000 | $1,000+ (custom) |
| **Typical budget split** | 100% coder | 70/30 | 50/20/15/15 | 40/15/15/10/10/10 |
| **Rework probability** | ~25% | ~12% | ~5% | <2% |
| **Min agent reputation** | 0 (any) | 50+ | 70+ | 80+ genesis preferred |
| **EAL depth** | Basic | Standard | Full + diff hashes | Full + signed attestations |

### 3.3 Budget Split par Tier (valeurs par défaut)

**BRONZE ($30 example):**
```
Stage 0 (Coder):    $27.00 (90%)
Platform fees:       $3.00 (10%)
  └── Provider:     $27.00
  └── Insurance:     $1.50 (5%)
  └── Burn:          $0.90 (3%)
  └── Treasury:      $0.60 (2%)
```

**SILVER ($150 example):**
```
Stage 0 (Coder):    $94.50 (63%)
Stage 1 (Reviewer): $40.50 (27%)
Platform fees:      $15.00 (10%)
  └── Provider 0:   $94.50
  └── Provider 1:   $40.50
  └── Insurance:     $7.50 (5%)
  └── Burn:          $4.50 (3%)
  └── Treasury:      $3.00 (2%)
```

**GOLD ($600 example):**
```
Stage 0 (Coder):    $270.00 (45%)
Stage 1 (Reviewer): $108.00 (18%)
Stage 2 (Security): $ 81.00 (13.5%)
Stage 3 (Tester):   $ 81.00 (13.5%)
Platform fees:      $ 60.00 (10%)
  └── Providers:    $540.00 total
  └── Insurance:    $ 30.00
  └── Burn:         $ 18.00
  └── Treasury:     $ 12.00
```

**PLATINUM ($3,000 example):**
```
Stage 0 (Coder):     $1,080.00 (36%)
Stage 1 (Reviewer):  $  405.00 (13.5%)
Stage 2 (Security):  $  405.00 (13.5%)
Stage 3 (Tester):    $  270.00 (9%)
Stage 4 (Optimizer): $  270.00 (9%)
Stage 5 (Compliance):$  270.00 (9%)
Platform fees:       $  300.00 (10%)
  └── Providers:     $2,700.00 total
  └── Insurance:     $  150.00
  └── Burn:          $   90.00
  └── Treasury:      $   60.00
```

### 3.4 Pourquoi les fees restent à 10% quelle que soit le tier

Contre-intuitif mais correct. Les tiers premium génèrent plus de volume absolu de fees ($300 vs $3 sur un BRONZE). Augmenter le % pour les tiers premium punirait les whales et les pousserait vers des solutions privées. Le 10% flat est un Schelling point simple, mémorable, et qui scale naturellement.

### 3.5 Tier Selection UX

Le client **ne choisit pas** un tier directement. Il :
1. Décrit la mission (TDL YAML dans l'issue GitHub)
2. Fixe un budget
3. Le système **recommande** un tier basé sur `budget ÷ estimated_complexity`
4. Le client peut override vers un tier supérieur (jamais inférieur au minimum pour la complexité estimée)

```yaml
# Example TDL that maps to SILVER
mission:
  title: "Add rate limiting to API endpoints"
  budget_usdc: 150
  # System recommendation: SILVER (2 stages: coder + reviewer)
  # Client can override to GOLD for security audit
  tier_override: null  # or "GOLD"
```

---

## 4. Quality Gates

### 4.1 Architecture des Quality Gates

Confirmé par zq §1.4 : attestation off-chain + commitment on-chain. Voici la spec complète.

### 4.2 Gate Evaluation Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Stage N delivers output → IPFS pin → outputCID             │
│                                                             │
│ WorkflowEscrow.deliverStage(workflowId, stageIndex, CID)   │
│   → state: STAGE_N_DELIVERED                                │
│   → emit StageDelivered(workflowId, stageIndex, outputCID)  │
│                                                             │
│ ┌─ Off-chain Gate Evaluation ─────────────────────────────┐ │
│ │ 1. Stage N+1 agent (reviewer) pulls outputCID from IPFS │ │
│ │ 2. Executes review using its own capabilities            │ │
│ │ 3. Produces GateReport:                                  │ │
│ │    ├── score: uint8 (0-100)                              │ │
│ │    ├── pass: bool (score >= tier threshold)               │ │
│ │    ├── findings: Finding[]                                │ │
│ │    ├── recommendation: PASS | SOFT_FAIL | HARD_FAIL      │ │
│ │    └── evidence_cids: bytes32[] (supporting artifacts)    │ │
│ │ 4. Pins GateReport to IPFS → reportCID                   │ │
│ │ 5. Signs EIP-712 attestation:                             │ │
│ │    sign(workflowId, stageIndex, reportCID, score, pass)   │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                             │
│ WorkflowEscrow.submitGateAttestation(                       │
│   workflowId, stageIndex, reportCID, score, pass, sig       │
│ )                                                           │
│   → verify EIP-712 signature matches registered reviewer    │
│   → verify score >= tier.threshold ↔ pass == true           │
│   → if pass: advance to stage N+1                           │
│   ��� if !pass && retries < max: STAGE_N_RETRY                │
│   → if !pass && retries >= max: WORKFLOW_FAILED              │
│   → emit GateEvaluated(workflowId, stageIndex, pass, score) │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 GateReport Schema (IPFS)

```typescript
interface GateReport {
  version: "1.0.0";
  workflowId: string;
  stageIndex: number;
  evaluator: {
    agentId: string;
    did: string;          // did:key:z6Mk...
  };
  input: {
    outputCID: string;    // what was evaluated
    stageRole: StageRole; // role of the stage being evaluated
  };
  evaluation: {
    score: number;        // 0-100
    pass: boolean;
    recommendation: "PASS" | "SOFT_FAIL" | "HARD_FAIL";
    confidence: number;   // 0-100, meta-score on the evaluation itself
  };
  findings: Finding[];
  metadata: {
    evaluatedAt: string;  // ISO 8601
    durationMs: number;
    toolsUsed: string[];  // e.g., ["semgrep", "eslint", "custom-llm-review"]
  };
}

interface Finding {
  severity: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW" | "INFO";
  category: string;      // e.g., "security", "logic", "style", "performance"
  location: string;      // file:line or general
  description: string;
  suggestion?: string;
  evidence?: string;     // CID of supporting artifact
}
```

### 4.4 Anti-Gaming des Quality Gates

**Problème : Rubber-stamping** — Le reviewer agent a un incentive financier à passer la gate rapidement (il est payé pour son stage, pas pour la qualité de sa review).

**Mitigations :**

| Attaque | Mitigation | Implémentation |
|---------|------------|----------------|
| Reviewer auto-pass tout | **Reputation tracking des reviewers** : si les outputs qu'ils passent font l'objet de disputes clients à >20%, leur rep baisse et ils perdent leur slot de reviewer | Off-chain : track `reviewer_pass_rate` vs `post_pass_dispute_rate` |
| Reviewer copie un rapport template | **Report diversity check** : hash des findings comparé aux N derniers rapports du même reviewer. Similarity >80% → flag | Off-chain : cosine similarity sur embeddings des findings |
| Coder et Reviewer colludent | **Pas le même provider** : le reviewer d'un stage ne peut pas être du même `provider_id` que le coder | On-chain : `require(stages[n+1].provider != stages[n].provider)` |
| Reviewer trop strict pour forcer retry | **Reputation bidirectionnelle** : les coders notent les reviewers. Si un reviewer a un `false_negative_rate` élevé (les outputs qu'il fail sont validés par un second reviewer), il perd sa rep | Off-chain : second opinion sampling (5% random) |
| Client manipule le threshold | **Threshold fixé par tier, pas par client** : le client choisit le tier, le threshold suit. Pas de custom threshold en V1 | On-chain : `tierThresholds[tier]` immutable |

### 4.5 Spot-Check QA (héritage des cycles précédents)

En plus des quality gates inter-stages, un **spot-check aléatoire** s'applique à 5% des workflows COMPLETED :
- Un reviewer indépendant (pas dans le workflow) re-évalue l'output final
- Si le score du spot-check est >15 points en dessous du dernier gate score → flag pour investigation
- Données agrégées pour calibrer les thresholds des tiers

---

## 5. Smart Contract Changes

### 5.1 Principe directeur : Composition, pas modification

Le `MissionEscrow.sol` existant (323 lignes, 14/14 tests) reste **inchangé**. Le nouveau contrat `WorkflowEscrow.sol` compose avec lui.

### 5.2 WorkflowEscrow.sol — Interface complète

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWorkflowEscrow {

    // ─── Enums ───────────────────────────────────────────────

    enum Tier { BRONZE, SILVER, GOLD, PLATINUM }

    enum WorkflowState {
        CREATED,            // Workflow defined, not funded
        FUNDED,             // Client deposited total budget
        ACTIVE,             // At least one stage is running
        COMPLETED,          // All stages passed, funds released
        FAILED,             // A stage hard-failed after max retries
        DISPUTED,           // Client raised dispute on any stage
        RESOLVED,           // Dispute resolved
        CANCELLED           // Cancelled before first stage accepted
    }

    enum StageState {
        PENDING,            // Not yet started
        MISSION_CREATED,    // Mission created in MissionEscrow
        DELIVERED,          // Agent delivered output
        GATE_PASSED,        // Quality gate passed
        GATE_FAILED,        // Quality gate failed (retry possible)
        RETRYING,           // Agent is re-doing the stage
        COMPLETED,          // Stage fully done (gate passed or no gate)
        HARD_FAILED         // Max retries exceeded
    }

    // ─── Structs ─────────────────────────────────────────────

    struct WorkflowConfig {
        bytes32 workflowId;
        address client;
        Tier tier;
        uint256 totalBudget;         // Total USDC (including fees)
        uint256 platformFees;        // 10% of totalBudget
        WorkflowState state;
        uint8 stageCount;
        uint8 currentStage;
        uint256 createdAt;
        uint256 completedAt;
        bytes32 issueHash;           // hash of GitHub issue TDL
    }

    struct StageConfig {
        uint8 role;                  // StageRole enum cast to uint8
        bytes32 agentId;             // assigned agent (0x0 = marketplace assigns)
        address provider;            // resolved provider address
        uint256 budget;              // USDC allocated to this stage
        bytes32 missionId;           // ID in MissionEscrow (set after creation)
        StageState state;
        uint8 gateThreshold;         // 0-100 (0 = no gate, e.g., BRONZE)
        uint8 retriesUsed;
        uint8 maxRetries;
        uint32 slaDeadline;          // seconds from stage start
    }

    struct GateAttestation {
        bytes32 reportCID;           // IPFS hash of GateReport
        uint8 score;
        bool pass;
        address evaluator;           // reviewer agent's address
        bytes signature;             // EIP-712 signature
        uint256 timestamp;
    }

    // ─── Events ─────────────────────────────────────────────���

    event WorkflowCreated(bytes32 indexed workflowId, address indexed client, Tier tier, uint256 totalBudget);
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageStarted(bytes32 indexed workflowId, uint8 stageIndex, bytes32 missionId);
    event StageDelivered(bytes32 indexed workflowId, uint8 stageIndex, bytes32 outputCID);
    event GateEvaluated(bytes32 indexed workflowId, uint8 stageIndex, bool pass, uint8 score);
    event StageRetry(bytes32 indexed workflowId, uint8 stageIndex, uint8 retryCount);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowFailed(bytes32 indexed workflowId, uint8 failedStage, string reason);
    event WorkflowDisputed(bytes32 indexed workflowId, uint8 stageIndex, string reason);

    // ─── Core Functions ──────────────────────────────────────

    /// @notice Create a workflow with stage definitions
    /// @dev Client defines stages; budget is split per stage
    function createWorkflow(
        Tier tier,
        StageConfig[] calldata stages,
        bytes32 issueHash
    ) external returns (bytes32 workflowId);

    /// @notice Fund the workflow with USDC (full amount upfront)
    /// @dev Requires USDC approval for totalBudget
    function fundWorkflow(bytes32 workflowId) external;

    /// @notice Start the first stage (creates mission in MissionEscrow)
    /// @dev Only callable after funding; selects agent if not pre-assigned
    function startWorkflow(bytes32 workflowId) external;

    /// @notice Called by stage agent to deliver output
    function deliverStage(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 outputCID
    ) external;

    /// @notice Submit quality gate attestation (called by reviewer or keeper)
    function submitGateAttestation(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 reportCID,
        uint8 score,
        bool pass,
        bytes calldata signature
    ) external;

    /// @notice Force advance a stage after gate timeout (keeper function)
    function forceAdvanceStage(bytes32 workflowId, uint8 stageIndex) external;

    /// @notice Client disputes a specific stage
    function disputeStage(
        bytes32 workflowId,
        uint8 stageIndex,
        string calldata reason
    ) external;

    /// @notice Cancel workflow before first stage is accepted
    function cancelWorkflow(bytes32 workflowId) external;

    // ─── View Functions ──────────────────────────────────────

    function getWorkflow(bytes32 workflowId) external view returns (WorkflowConfig memory);
    function getStage(bytes32 workflowId, uint8 stageIndex) external view returns (StageConfig memory);
    function getGateAttestation(bytes32 workflowId, uint8 stageIndex) external view returns (GateAttestation memory);
    function getTierThreshold(Tier tier) external pure returns (uint8);
    function estimateWorkflowCost(Tier tier, uint256 baseBudget) external pure returns (uint256 totalCost, uint256[] memory stageBudgets);
}
```

### 5.3 Interaction WorkflowEscrow ↔ MissionEscrow

```
Client                    WorkflowEscrow               MissionEscrow
  │                            │                            │
  │ createWorkflow(GOLD, ...)  │                            │
  │───────────────────────────►│                            │
  │                            │ store workflow config      │
  │                            │                            │
  │ fundWorkflow(wfId)         │                            │
  │───────────────────────────►│                            │
  │    (USDC transfer)         │ hold funds                 │
  │                            │                            │
  │ startWorkflow(wfId)        │                            │
  │───────────────────────────►│                            │
  │                            │ approve USDC for stage 0   │
  │                            │ createMission(agentId,     │
  │                            │   stageBudget, deadline)   │
  │                            │───────────────────────────►│
  │                            │        missionId ◄─────────│
  │                            │                            │
  │                            │  ... agent executes ...    │
  │                            │                            │
  │                            │  deliverMission(mId, CID)  │
  │                            │◄───────────────────────────│
  │                            │                            │
  │                            │ [Gate evaluation off-chain] │
  │                            │                            │
  │                            │ submitGateAttestation(...)  │
  │                            │  ��� if pass:                │
  │                            │    approveMission(mId)     │
  │                            │───────────────────────────►│
  │                            │    createMission(stage1)   │
  │                            │───────────────────────────►│
  │                            │                            │
  │                            │  ... repeat per stage ...  │
  │                            │                            │
  │                            │  Last gate passes →        │
  │                            │  WORKFLOW_COMPLETED         │
  │◄───────────────────────────│  emit WorkflowCompleted    │
```

**Point d'architecture crucial :** `WorkflowEscrow` détient le total budget USDC et fait des `approve()` puis `createMission()` sur `MissionEscrow` pour chaque stage. Il agit comme un **meta-client programmatique**. Le `MissionEscrow` ne sait pas qu'il fait partie d'un workflow — separation of concerns parfaite.

### 5.4 Gas Estimation

| Opération | Gas estimé | Coût (Base L2, ~$0.001/op) |
|-----------|-----------|---------------------------|
| `createWorkflow` (4 stages) | ~180K | ~$0.18 |
| `fundWorkflow` (USDC transfer) | ~65K | ~$0.07 |
| `startWorkflow` (1st mission) | ~220K | ~$0.22 |
| `submitGateAttestation` | ~85K | ~$0.09 |
| Total workflow GOLD (4 stages, 3 gates) | ~900K | ~$0.90 |

À $0.90 de gas total pour un workflow à $600, le overhead on-chain est de **0.15%** du budget. Négligeable.

### 5.5 Storage Optimization

```solidity
// Pack StageConfig into fewer slots
// Slot 1: role(8) + gateThreshold(8) + retriesUsed(8) + maxRetries(8) + state(8) = 40 bits → 1 partial slot
// Slot 2: agentId (bytes32) = 1 full slot
// Slot 3: provider (address, 160 bits) + slaDeadline (32 bits) = 192 bits → 1 partial slot
// Slot 4: budget (uint256) = 1 full slot
// Slot 5: missionId (bytes32) = 1 full slot
// Total: 5 slots per stage × 6 stages max = 30 storage slots worst case

// WorkflowConfig packs into:
// Slot 1: client (160) + tier(8) + stageCount(8) + currentStage(8) + state(8) = 192 bits
// Slot 2: totalBudget (256)
// Slot 3: platformFees (256)
// Slot 4: workflowId (256)
// Slot 5: issueHash (256)
// Slot 6: createdAt(64) + completedAt(64) = 128 bits
// Total: 6 slots per workflow
```

### 5.6 Ce qui ne change PAS dans MissionEscrow.sol

| Aspect | Change Required? | Justification |
|--------|-----------------|---------------|