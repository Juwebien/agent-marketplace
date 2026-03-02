

# Cycle zn — Budget-Tiered Workflows Architecture (Opus)

---

## 1. Core Insight de ce cycle

**Le budget n'achète ni du compute, ni du temps, ni même de la qualité — il achète une probabilité de succès contractuellement garantie.** Les cycles précédents (za, zm) ont établi que le budget achète de la réduction d'incertitude. Ce cycle va plus loin : la plateforme est un **marché d'options sur la qualité logicielle**. Chaque tier est un produit financier dont le prix est fonction non pas du coût marginal des agents mobilisés, mais de la probabilité conditionnelle de défaut sachant N stages de vérification indépendants. Si un agent seul a un taux de défaut p = 0.35, deux agents indépendants (coder + reviewer) donnent p² ≈ 0.12, trois agents p³ ≈ 0.04. Le client n'achète pas "3 agents" — il achète un put option contre le rework avec un strike calibré sur son budget. C'est ce framing qui permet de facturer le Premium à 2.5× le Basic plutôt qu'à 3× : la non-linéarité du pricing est le reflet de la non-linéarité de la réduction d'incertitude. L'insight actionnable est que le **WorkflowEscrow doit encoder cette sémantique** : le contrat ne gère pas une liste de missions, il gère un engagement de taux de défaut avec un mécanisme d'assurance proportionnel. Si le workflow échoue malgré le tier choisi, l'insurance pool rembourse proportionnellement au tier — ce qui ferme la boucle économique et distingue fondamentalement la plateforme de tout concurrent.

---

## 2. Workflow Engine Design

### 2.1 Décision structurelle : Pipeline séquentiel contraint en V1

Le cycle zm a tranché : pas de DAG arbitraire en V1. Ce cycle **détaille l'implémentation** du pipeline séquentiel et prépare la trappe V2.

### 2.2 Modèle de données du Workflow

```
Workflow {
    workflowId:    bytes32
    clientId:      address
    tier:          enum { BASIC, STANDARD, PREMIUM, ENTERPRISE }
    issueHash:     bytes32          // hash de l'issue GitHub source
    totalBudget:   uint256          // USDC total verrouillé
    stages:        Stage[]          // pipeline ordonné
    currentStage:  uint8            // index courant
    state:         WorkflowState
    createdAt:     uint256
    deadline:      uint256          // SLA global du workflow
    metadata:      bytes32          // IPFS hash de la spec complète
}

Stage {
    stageIndex:    uint8
    role:          enum { CODER, REVIEWER, SECURITY_AUDITOR, TESTER, OPTIMIZER }
    missionId:     bytes32          // ref vers MissionEscrow
    agentId:       bytes32          // agent assigné
    budget:        uint256          // part du budget allouée à ce stage
    qualityGate:   QualityGateConfig
    state:         StageState       // PENDING → ACTIVE → COMPLETED | FAILED | SKIPPED
    output:        bytes32          // IPFS hash du livrable
    startedAt:     uint256
    completedAt:   uint256
}

QualityGateConfig {
    threshold:         uint8        // score minimum (0-100)
    maxRetries:        uint8        // nombre de retries avant fail
    reviewerMinRep:    uint256      // réputation minimum du reviewer
    autoPassIfTimeout: bool         // auto-pass si reviewer ne répond pas en X
    timeoutSeconds:    uint256
}
```

### 2.3 State Machine du Workflow

```
CREATED ─── fund() ───→ FUNDED ─── startWorkflow() ───→ STAGE_ACTIVE
                                                              │
                              ┌────────────────────────────────┤
                              │                                │
                              ▼                                ▼
                        STAGE_QG_PENDING              STAGE_FAILED
                              │                          │
                     ┌────────┤                     ┌────┴────┐
                     │        │                     │         │
                     ▼        ▼                     ▼         ▼
              QG_PASSED   QG_FAILED            RETRY     WORKFLOW_FAILED
                  │           │                  │              │
                  │      retry ≤ max?            │              │
                  │       ┌───┴───┐              │              ▼
                  │       │       │              │         REFUND_PARTIAL
                  │       ▼       ▼              │
                  │    RETRY   STAGE_FAILED      │
                  │      │    (terminal)          │
                  │      └───────→ re-enter ─────┘
                  │           STAGE_ACTIVE
                  ▼
           ┌──────────────┐
           │ Last stage?   │
           ├──── YES ─────→ WORKFLOW_COMPLETED → payout()
           └──── NO ──────→ advance() → STAGE_ACTIVE (stage+1)
```

### 2.4 Invariants du pipeline

| Invariant | Vérification | Conséquence si violé |
|-----------|--------------|----------------------|
| `stages.length ≤ 6` | Enforced dans `createWorkflow()` | Revert |
| `sum(stages[].budget) == totalBudget - platformFees` | Vérifié dans `createWorkflow()` | Revert |
| `stages[i].state == COMPLETED` avant `stages[i+1].state = ACTIVE` | Enforced dans `advanceStage()` | Revert |
| `currentStage` monotone croissant | Pas de rollback de stage | Revert |
| Un seul stage ACTIVE à la fois | Mutex implicite via `currentStage` | Revert |
| Chaque stage a exactement un agent assigné | Enforced dans `assignAgent()` | Revert |

### 2.5 Trappe V2 : du Pipeline au DAG

Le `stageIndex: uint8` est remplaçable par `stageId: bytes32` + `dependencies: bytes32[]`. La fonction `advanceStage()` vérifie `stages[currentStage].state == COMPLETED` — en V2 elle vérifierait `∀ dep ∈ stage.dependencies : stages[dep].state == COMPLETED`. Migration non-breaking car le pipeline séquentiel est un cas particulier de DAG linéaire.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Définition des Tiers

| Dimension | BASIC | STANDARD | PREMIUM | ENTERPRISE |
|-----------|-------|----------|---------|------------|
| **Stages** | 1 | 2 (+1 QG) | 3 (+2 QG) | 4-6 (+3-5 QG), custom |
| **Pipeline** | Coder | Coder → Reviewer | Coder → Reviewer → Tester | Coder → Reviewer → Security → Tester → Optimizer (configurable) |
| **Budget range** | $10 – $100 | $50 – $500 | $200 – $2,000 | $1,000 – $50,000+ |
| **Taux de défaut cible** | ≤ 35% | ≤ 12% | ≤ 4% | ≤ 1% (SLA contractuel) |
| **SLA deadline** | Best effort (72h default) | 48h | 24h | Custom, pénalités financières |
| **QG threshold** | N/A | 60/100 | 75/100 | 85/100 |
| **QG retries** | N/A | 1 | 2 | 3 |
| **Insurance multiplier** | 1× mission value | 1.5× | 2× (cap existant) | 3× (nécessite governance vote) |
| **Dispute escalation** | Auto-resolve 48h | Reviewer panel (3) | Reviewer panel (5) + multisig fallback | Dedicated arbitration + SLA penalty clause |
| **Agent min reputation** | 0 (cold start OK) | 30/100 | 60/100 | 80/100 |
| **Agent min stake tier** | NONE | BRONZE | SILVER | GOLD |
| **Audit trail** | Basic (mission events) | Mission events + QG attestations | Full EAL + QG + diffs | Full EAL + QG + diffs + compliance export (SOC2) |
| **Auto-approve window** | 48h | 48h | 24h (client must review) | Disabled (explicit approval required) |

### 3.2 Budget Split par Tier

Le budget total du client est distribué entre les stages. La distribution n'est **pas** uniforme — le coder reçoit la part la plus importante car il produit le livrable primaire.

**STANDARD (2 stages) :**
```
Coder:    65% du budget net (après platform fees)
Reviewer: 35% du budget net
```

**PREMIUM (3 stages) :**
```
Coder:    50%
Reviewer: 25%
Tester:   25%
```

**ENTERPRISE (5 stages, exemple) :**
```
Coder:           35%
Reviewer:        20%
Security Audit:  20%
Tester:          15%
Optimizer:       10%
```

**Platform fees :** Prélevées sur le `totalBudget` avant la distribution aux stages. Le fee split existant (90/5/3/2) s'applique **à chaque mission individuelle**, pas au workflow global. Cela signifie :

```
workflow.totalBudget = $500 (PREMIUM)
platform_cut = $500 × 10% = $50  (5% insurance + 3% burn + 2% treasury)
net_for_agents = $450
  → Coder:    $225 (50%)
  → Reviewer: $112.50 (25%)
  → Tester:   $112.50 (25%)
```

**Décision :** Les fees sont prélevées au niveau du workflow, pas par mission individuelle. Sinon l'overhead de 10% × N stages pénalise les tiers hauts et crée un désincitation à choisir Premium. Un seul prélèvement de 10% sur le budget total aligne les incitations.

### 3.3 Tier Selection Logic

Le client ne doit **pas** choisir manuellement les stages. Il choisit un tier et la plateforme configure le pipeline. Le choix du tier peut être :

1. **Explicite** — Le client sélectionne dans l'UI ("Basic / Standard / Premium")
2. **Recommandé** — Le système analyse l'issue (taille, tags, complexité via embeddings) et recommande un tier
3. **Automatique (Enterprise)** — Politique d'organisation : "Tous les issues tagged `security` → Premium minimum"

```typescript
interface TierRecommendation {
  suggestedTier: Tier;
  confidence: number;        // 0-1
  reasoning: string;
  costEstimate: {
    min: number;
    max: number;
    expected: number;
  };
  defectProbability: number; // probabilité de rework avec ce tier
}

function recommendTier(issue: ParsedIssue): TierRecommendation {
  const complexity = estimateComplexity(issue);  // embeddings + heuristics
  const securitySensitive = issue.tags.includes('security') || issue.tags.includes('auth');
  const linesEstimate = estimateScope(issue);

  if (securitySensitive || linesEstimate > 500) return { suggestedTier: 'PREMIUM', ... };
  if (linesEstimate > 100 || complexity > 0.6) return { suggestedTier: 'STANDARD', ... };
  return { suggestedTier: 'BASIC', ... };
}
```

---

## 4. Quality Gates

### 4.1 Architecture (confirmée depuis zm)

Quality Gates = **attestation off-chain avec commitment on-chain**. Pas de jugement on-chain. Le smart contract vérifie uniquement :
- Le hash du rapport correspond à la signature
- Le score ≥ threshold configuré pour le tier
- Le reviewer est un agent registré avec réputation ≥ minimum requis
- Le reviewer n'est **pas** le même agent que le coder (anti-collusion)

### 4.2 Quality Gate Flow détaillé

```
Stage N complété
    │
    ▼
WorkflowEscrow émet event StageDelivered(workflowId, stageIndex, outputHash)
    │
    ▼
Orchestrateur off-chain détecte l'event
    │
    ▼
Sélection du reviewer (voir §6 Matching)
    │
    ▼
Reviewer reçoit:
  - outputHash du stage N (pour récupérer le livrable sur IPFS)
  - issue originale (contexte)
  - critères QG spécifiques au role du stage N
    │
    ▼
Reviewer produit:
  - rapport structuré (JSON) avec :
      - score: uint8 (0-100)
      - findings: Finding[]
      - summary: string
      - recommendation: PASS | FAIL | PASS_WITH_WARNINGS
    │
    ▼
Reviewer signe (EIP-712):
  domain: { name: "AgentMarketplace", version: "1", chainId: 8453 }
  types: { QGAttestation: [
    { name: "workflowId", type: "bytes32" },
    { name: "stageIndex", type: "uint8" },
    { name: "reportHash", type: "bytes32" },
    { name: "score", type: "uint8" },
    { name: "reviewer", type: "address" },
    { name: "timestamp", type: "uint256" }
  ]}
    │
    ▼
Transaction on-chain: submitQualityGate(workflowId, stageIndex, reportHash, score, signature)
    │
    ▼
WorkflowEscrow vérifie:
  1. ecrecover(signature) == reviewer registré
  2. reviewer != stage[stageIndex].agentId           // anti-collusion
  3. reviewer.reputation >= tier.reviewerMinRep
  4. score >= stage[stageIndex].qualityGate.threshold // pass/fail
  5. block.timestamp <= stage.completedAt + qg.timeoutSeconds
    │
    ├── Si pass → advanceStage(workflowId)
    │     → crée la mission du stage N+1 via MissionEscrow
    │
    ├── Si fail && retries < maxRetries → retry
    │     → recrée la mission du stage N avec un agent différent
    │     → le budget du retry est puisé dans une réserve (5% du stage budget)
    │
    └── Si fail && retries >= maxRetries → failStage
          → workflow state = WORKFLOW_FAILED
          → refund partiel au client (stages non exécutés)
          → agents complétés sont payés normalement
```

### 4.3 Critères QG par rôle

Les quality gates ne sont pas génériques. Chaque rôle a des critères spécifiques objectivables :

| Rôle du stage évalué | Critères QG | Poids dans le score | Objectivable? |
|----------------------|-------------|---------------------|---------------|
| **CODER** | Tests passent (CI green) | 30% | ✅ Oui — binaire |
| | Couverture de tests > seuil | 15% | ✅ Oui — mesurable |
| | Pas de vulnérabilités Semgrep critical | 20% | ✅ Oui — outillable |
| | Respect de la spec (issue) | 20% | ❌ Subjectif — reviewer judgment |
| | Code lisible/maintenable | 15% | ❌ Subjectif |
| **REVIEWER** | Findings pertinents (pas de faux positifs évidents) | 40% | ⚠️ Partiellement |
| | Tous les fichiers modifiés sont couverts | 30% | ✅ Oui — vérifiable |
| | Suggestions actionnables | 30% | ❌ Subjectif |
| **SECURITY_AUDITOR** | Check OWASP Top 10 | 40% | ✅ Oui — checklist |
| | Analyse des dépendances | 30% | ✅ Oui — outillable |
| | Vecteurs d'attaque identifiés | 30% | ⚠️ Exhaustivité non vérifiable |
| **TESTER** | Tests ajoutés couvrent la spec | 40% | ⚠️ Partiel |
| | Tests passent | 30% | ✅ Oui — binaire |
| | Edge cases couverts | 30% | ❌ Subjectif |

**Stratégie :** En V1, la partie objectivable (CI green, coverage, Semgrep) est automatisée par le sandbox d'exécution. Le score QG est un weighted average des critères objectifs (automatiques) et subjectifs (reviewer). Le poids des critères objectifs est majoré pour réduire le pouvoir discrétionnaire du reviewer :

```
finalScore = 0.6 × objectiveScore + 0.4 × subjectiveScore
```

### 4.4 Anti-collusion entre agents

Risque critique : un provider qui possède un agent CODER et un agent REVIEWER pourrait colluder pour que le reviewer passe systématiquement le code. Mitigations :

| Mitigation | Mécanisme | Efficacité |
|------------|-----------|------------|
| **Same-provider ban** | `stage[N].agent.provider != stage[N].qualityGate.reviewer.provider` | Haute — empêche collusion directe |
| **Reviewer rotation** | Un reviewer ne peut pas évaluer le même coder plus de 3× consécutivement | Moyenne — limite les arrangements |
| **Spot-check aléatoire** | 10% des QG sont re-évalués par un second reviewer indépendant | Haute — crée de l'incertitude |
| **Reviewer staking** | Le reviewer a du skin in the game : si une re-évaluation montre complaisance, slash | Haute — coût économique |
| **Score calibration** | Si un reviewer a un taux de PASS > 95%, flag automatique | Moyenne — détection statistique |

---

## 5. Smart Contract Changes

### 5.1 Nouveau contrat : `WorkflowEscrow.sol`

**Principe :** `WorkflowEscrow` ne modifie pas `MissionEscrow` (les 14 tests restent verts). Il **compose** avec `MissionEscrow` en agissant comme un meta-client.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MissionEscrow.sol";
import "./AgentRegistry.sol";

contract WorkflowEscrow is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ─── Types ───────────────────────────────────────────────────────

    enum Tier { BASIC, STANDARD, PREMIUM, ENTERPRISE }

    enum WorkflowState {
        CREATED,
        FUNDED,
        STAGE_ACTIVE,
        STAGE_QG_PENDING,
        WORKFLOW_COMPLETED,
        WORKFLOW_FAILED,
        CANCELLED
    }

    enum StageState { PENDING, ACTIVE, QG_PENDING, COMPLETED, FAILED, SKIPPED }

    enum StageRole { CODER, REVIEWER, SECURITY_AUDITOR, TESTER, OPTIMIZER }

    struct QualityGateConfig {
        uint8 threshold;           // 0-100
        uint8 maxRetries;
        uint256 reviewerMinRep;
        uint256 timeoutSeconds;
    }

    struct QualityGateAttestation {
        bytes32 reportHash;
        uint8 score;
        address reviewer;
        bytes signature;
        uint256 timestamp;
        bool passed;
    }

    struct Stage {
        uint8 stageIndex;
        StageRole role;
        bytes32 missionId;         // ref into MissionEscrow
        bytes32 agentId;
        uint256 budget;
        StageState state;
        QualityGateConfig qgConfig;
        QualityGateAttestation qgAttestation;
        uint8 retriesUsed;
        bytes32 outputHash;
        uint256 startedAt;
        uint256 completedAt;
    }

    struct Workflow {
        bytes32 workflowId;
        address client;
        Tier tier;
        uint256 totalBudget;
        uint8 stageCount;
        uint8 currentStage;
        WorkflowState state;
        uint256 createdAt;
        uint256 deadline;
        bytes32 issueHash;         // IPFS hash of the source issue
    }

    // ─── State ───────────────────────────────────────────────────────

    MissionEscrow public missionEscrow;
    AgentRegistry public agentRegistry;
    IERC20 public usdc;

    mapping(bytes32 => Workflow) public workflows;
    mapping(bytes32 => Stage[]) public workflowStages;

    // Tier → default configurations
    mapping(Tier => QualityGateConfig) public defaultQGConfigs;
    mapping(Tier => uint8) public tierStageCount;
    mapping(Tier => StageRole[]) public tierPipeline;

    // Anti-collusion: reviewer => coder agent => consecutive review count
    mapping(address => mapping(bytes32 => uint8)) public reviewerCoderCount;

    uint8 public constant MAX_STAGES = 6;
    uint256 public constant RETRY_RESERVE_BPS = 500; // 5% of stage budget

    bytes32 public constant ORCHESTRATOR_ROLE = keccak256("ORCHESTRATOR_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    // ─── Events ──────────────────────────────────────────────────────

    event WorkflowCreated(
        bytes32 indexed workflowId,
        address indexed client,
        Tier tier,
        uint256 totalBudget
    );
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageStarted(
        bytes32 indexed workflowId,
        uint8 stageIndex,
        bytes32 agentId,
        bytes32 missionId
    );
    event StageDelivered(
        bytes32 indexed workflowId,
        uint8 stageIndex,
        bytes32 outputHash
    );
    event QualityGateSubmitted(
        bytes32 indexed workflowId,
        uint8 stageIndex,
        uint8 score,
        bool passed
    );
    event StageRetried(
        bytes32 indexed workflowId,
        uint8 stageIndex,
        uint8 retryCount
    );
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowFailed(
        bytes32 indexed workflowId,
        uint8 failedAtStage,
        uint256 refundAmount
    );

    // ─── Initialization ──────────────────────────────────────────────

    function initialize(
        address _missionEscrow,
        address _agentRegistry,
        address _usdc
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        missionEscrow = MissionEscrow(_missionEscrow);
        agentRegistry = AgentRegistry(_agentRegistry);
        usdc = IERC20(_usdc);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORCHESTRATOR_ROLE, msg.sender);

        // Default tier configs
        tierStageCount[Tier.BASIC] = 1;
        tierStageCount[Tier.STANDARD] = 2;
        tierStageCount[Tier.PREMIUM] = 3;
        tierStageCount[Tier.ENTERPRISE] = 5; // configurable

        defaultQGConfigs[Tier.STANDARD] = QualityGateConfig({
            threshold: 60,
            maxRetries: 1,
            reviewerMinRep: 30,
            timeoutSeconds: 4 hours
        });
        defaultQGConfigs[Tier.PREMIUM] = QualityGateConfig({
            threshold: 75,
            maxRetries: 2,
            reviewerMinRep: 60,
            timeoutSeconds: 2 hours
        });
        defaultQGConfigs[Tier.ENTERPRISE] = QualityGateConfig({
            threshold: 85,
            maxRetries: 3,
            reviewerMinRep: 80,
            timeoutSeconds: 6 hours
        });
    }

    // ─── Core Functions ──────────────────────────────────────────────

    /// @notice Create a workflow — client chooses a tier, platform configures pipeline
    function createWorkflow(
        Tier _tier,
        uint256 _totalBudget,
        uint256 _deadline,
        bytes32 _issueHash,
        uint256[] calldata _budgetSplitBps  // basis points per stage, must sum to 10000
    ) external nonReentrant returns (bytes32) {
        uint8 stageCount = tierStageCount[_tier];
        require(stageCount > 0 && stageCount <= MAX_STAGES, "Invalid tier config");
        require(_budgetSplitBps.length == stageCount, "Budget split mismatch");
        require(_deadline > block.timestamp, "Deadline in the past");

        // Validate budget split sums to 100%
        uint256 totalBps;
        for (uint8 i = 0; i < stageCount; i++) {
            totalBps += _budgetSplitBps[i];
        }
        require(totalBps == 10_000, "Budget split must sum to 10000 bps");

        // Platform fee: 10% of total budget (5% insurance + 3% burn + 2% treasury)
        uint256 platformFee = (_totalBudget * 1_000) / 10_000; // 10%
        uint256 netBudget = _totalBudget - platformFee;

        bytes32 workflowId = keccak256(
            abi.encodePacked(msg.sender, block.timestamp, _issueHash, block.prevrandao)
        );

        workflows[workflowId] = Workflow({
            workflowId: workflowId,
            client: msg.sender,
            tier: _tier,
            totalBudget: _totalBudget,
            stageCount: stageCount,
            currentStage: 0,
            state: WorkflowState.CREATED,
            createdAt: block.timestamp,
            deadline: _deadline,
            issueHash: _issueHash
        });

        // Create stage stubs
        StageRole[] memory pipeline = tierPipeline[_tier];
        for (uint8 i = 0; i < stageCount; i++) {
            uint256 stageBudget = (netBudget * _budgetSplitBps[i]) / 10_000;

            // Last stage (and BASIC) has no QG
            QualityGateConfig memory qg;
            if (i < stageCount - 1 || _tier == Tier.ENTERPRISE) {
                qg = defaultQGConfigs[_tier];
            }
            // else: qg stays zeroed — no QG for the last stage of non-Enterprise tiers

            workflowStages[workflowId].push(Stage({
                stageIndex: i,
                role: pipeline[i],
                missionId: bytes32(0), // assigned when stage starts
                agentId: bytes32(0),   // assigned by orchestrator
                budget: stageBudget,
                state: StageState.PENDING,
                qgConfig: qg,
                qgAttestation: QualityGateAttestation({
                    reportHash: bytes32(0),
                    score: 0,
                    reviewer: address(0),
                    signature: "",
                    timestamp: 0,
                    passed: false
                }),
                retriesUsed: 0,
                outputHash: bytes32(0),
                startedAt: 0,
                completedAt: 0
            }));
        }

        emit WorkflowCreated(workflowId, msg.sender, _tier, _totalBudget);
        return workflowId;
    }

    /// @notice Client funds the workflow — USDC transferred to this contract
    function fundWorkflow(bytes32 _workflowId) external nonReentrant {
        Workflow storage wf = workflows[_workflowId];
        require(wf.client == msg.sender, "Not client");
        require(wf.state == WorkflowState.CREATED, "Wrong state");

        usdc.transferFrom(msg.sender, address(this), wf.totalBudget);
        wf.state = WorkflowState.FUNDED;

        emit WorkflowFunded(_workflowId, wf.totalBudget);
    }

    /// @notice Orchestrator assigns an agent and starts a stage
    /// @dev Creates a sub-mission in MissionEscrow
    function startStage(
        bytes32 _workflowId,
        bytes32 _agentId
    ) external onlyRole(ORCHESTRATOR_ROLE) nonReentrant {
        Workflow storage wf = workflows[_workflowId];
        require(
            wf.state == WorkflowState.FUNDED || wf.state == WorkflowState.STAGE_ACTIVE,
            "Wrong state"
        );

        Stage storage stage = workflowStages[_workflowId][wf.currentStage];
        require(
            stage.state == StageState.PENDING || stage.state == StageState.FAILED,
            "Stage not startable"
        );

        // Verify agent meets tier requirements
        AgentRegistry.Reputation memory rep = agentRegistry