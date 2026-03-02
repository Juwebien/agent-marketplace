

# Cycle zj — Budget-Tiered Workflows Architecture (Opus)

---

## 1. Core Insight de ce cycle

Le cycle zi a établi que le workflow est le produit, pas la mission standalone, et que `WorkflowOrchestrator.sol` compose `MissionEscrow.sol` sans le modifier. Le cycle zj doit maintenant répondre à la question que personne n'a encore tranchée : **comment le budget du client se transforme-t-il concrètement en un plan d'exécution multi-agents, et surtout, qui décide de cette transformation ?** L'insight central est que le Budget-Tiered Workflow n'est pas un simple mapping `budget → nombre d'agents`. C'est un **compilateur de confiance** : le client exprime une intention (une issue GitHub + un budget), et la plateforme *compile* cette intention en un pipeline d'exécution vérifié, où chaque dollar supplémentaire achète non pas du compute brut mais une **réduction probabiliste du risque de rework**. Le tier n'est pas un menu restaurant — c'est un contrat de niveau de confiance dans le livrable. La conséquence architecturale est que le système a besoin d'un composant nouveau que j'appelle le **WorkflowCompiler** : un service off-chain qui, étant donné (issue_description, budget, tier_preference), produit un `WorkflowPlan` déterministe — la liste ordonnée de stages, les agent roles requis, les quality gate thresholds, et le budget split par stage. Ce plan est hashé, committé on-chain, et devient la loi du workflow.

---

## 2. Workflow Engine Design

### 2.1 Pourquoi pas un DAG arbitraire (rappel + approfondissement)

Le cycle zi a tranché : pipeline séquentiel contraint, max 6 stages. Je valide mais je pousse la réflexion un cran plus loin. Le problème du DAG arbitraire n'est pas seulement le gas ou la complexité UX — c'est l'**explosion combinatoire des chemins de dispute**. Si un stage parallèle A échoue et B réussit, qui est responsable ? Le client a-t-il droit à un refund partiel ? Le DAG crée un graphe de responsabilité qui n'a pas de solution simple en smart contract.

### 2.2 Les 3 patterns V1 (affinés)

```
PATTERN 1: Sequential Pipeline (90% des cas)
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ Stage 1 │───▶│ Stage 2 │───▶│ Stage 3 │───▶│ Stage 4 │
│  CODE   │ QG │ REVIEW │ QG │SECURITY│ QG │  TEST  │
└────────┘    └────────┘    └────────┘    └────────┘
   40%           25%           20%           15%     ← budget split

PATTERN 2: Fan-out avec Merge (V1.5 — nécessite sync barrier)
                ┌──────────┐
           ┌───▶│ Stage 2a │───┐
┌────────┐ │    │ FRONTEND │   │    ┌────────┐    ┌────────┐
│ Stage 1 │─┤    └──────────┘   ├───▶│ Stage 3 │───▶│ Stage 4 │
│ DESIGN  │ │    ┌──────────┐   │    │ INTEG  │    │  TEST  │
└────────┘ └───▶│ Stage 2b │───┘    └────────┘    └────────┘
                │ BACKEND  │
                └──────────┘

⚠️ Reporté à V1.5 — le merge barrier ajoute un état WAITING_MERGE 
   au WorkflowOrchestrator et une logique de "tous les sous-stages 
   doivent être COMPLETED avant advance"

PATTERN 3: Conditional Branch (retry/fallback)
┌────────┐    ┌────────┐──PASS──▶┌────────┐
│ Stage 1 │───▶│ Stage 2 │         │ Stage 3 │
│  CODE   │    │ REVIEW  │──FAIL──▶│ Stage 2'│──▶ retry Stage 2
└────────┘    └────────┘         │  RECODE │    (max 2 retries)
                                  └────────┘
```

### 2.3 Le WorkflowPlan comme artefact immuable

Le `WorkflowPlan` est le contrat d'exécution. Il est généré off-chain, hashé, et committé on-chain au moment du `createWorkflow()`.

```typescript
interface WorkflowPlan {
  workflowId: bytes32;
  tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';
  totalBudgetUSDC: number;
  stages: WorkflowStage[];
  planHash: bytes32; // keccak256 du plan sérialisé
}

interface WorkflowStage {
  index: number;                    // 0-based, détermine l'ordre
  role: AgentRole;                  // CODE | REVIEW | SECURITY | TEST | OPTIMIZE | DOCUMENT
  budgetAllocationBps: number;      // en basis points (4000 = 40%)
  qualityGate: QualityGateConfig;
  agentConstraints: AgentConstraints;
  maxRetries: number;               // 0-2, default 1 pour SILVER+
  timeoutSeconds: number;           // SLA per-stage
}

interface QualityGateConfig {
  minScore: number;                 // 0-100, threshold pour PASS
  requiredChecks: string[];         // e.g. ['lint_pass', 'tests_pass', 'no_critical_vulns']
  challengeWindowSeconds: number;   // 24h default
}

interface AgentConstraints {
  requiredTags: string[];           // e.g. ['solidity', 'security-audit']
  minReputation: number;            // score minimum (0-100)
  minCompletedMissions: number;     // track record minimum
  excludeProviders: address[];      // anti-collusion: pas le même provider que le stage précédent
}
```

### 2.4 State Machine du Workflow

```
                          createWorkflow()
                                │
                                ▼
                         ┌──────────────┐
                         │   PLANNED    │
                         └──────┬───────┘
                                │ fundWorkflow() — USDC transferé en escrow
                                ▼
                         ┌──────────────┐
                         │   FUNDED     │
                         └──────┬───────┘
                                │ startWorkflow() — crée Mission pour Stage 0
                                ▼
                    ┌───────────────────────┐
                    │   STAGE_IN_PROGRESS   │◄──────────────────┐
                    └───────────┬───────────┘                   │
                                │ stage complété (Mission COMPLETED)
                                ▼                               │
                    ┌──���────────────────────┐                   │
                    │   QUALITY_GATE_REVIEW │                   │
                    └───────┬───────┬───────┘                   │
                            │       │                           │
                         PASS     FAIL                          │
                            │       │                           │
                            │       ▼                           │
                            │  ┌─────────────┐                  │
                            │  │ STAGE_RETRY │──(retry < max)──┘
                            │  └──────┬──────┘
                            │         │ (retry >= max)
                            │         ▼
                            │  ┌──────────────┐
                            │  │   DEGRADED   │──▶ deliver partial + refund remainder
                            │  └──────────────┘
                            │
                            ▼
                    ┌──────────────────┐
                    │ hasNextStage()?   │
                    └──────┬─────┬─────┘
                           │     │
                          YES    NO
                           │     │
                           │     ▼
                           │  ┌──────────────┐
                           │  │  COMPLETED   │──▶ release all escrowed funds
                           │  └──────────────┘
                           │
                           └──▶ advanceStage() ──▶ STAGE_IN_PROGRESS
                    
                    
    À tout moment (avant COMPLETED):
    ┌──────────────┐
    │  DISPUTED    │──▶ dispute resolution (V1: multisig, V2: Kleros)
    └──────────────┘
    
    Avant FUNDED:
    ┌──────────────┐
    │  CANCELLED   │──▶ full refund
    └──────────────┘
```

**Observation architecturale critique :** Le nouvel état `DEGRADED` est indispensable. Sans lui, un workflow GOLD où la security review échoue 2 fois est bloqué indéfiniment. `DEGRADED` signifie : "on a livré code + review mais la security n'a pas passé, le client récupère le livrable partiel + le budget non-consommé des stages restants". C'est la soupape de sécurité qui empêche les fonds d'être bloqués.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Définition des Tiers

| Dimension | BRONZE | SILVER | GOLD | PLATINUM |
|-----------|--------|--------|------|----------|
| **Stages** | 1 | 2 | 3-4 | 4-6 |
| **Pipeline** | Code only | Code → Review | Code → Review → Security/Test | Code → Review → Security → Test → Optimize/Doc |
| **Quality Gates** | Aucun (auto-approve 48h) | Score ≥ 60 | Score ≥ 75 | Score ≥ 85 |
| **Retries par stage** | 0 | 1 | 1 | 2 |
| **Challenge Window** | 48h (auto) | 24h | 24h | 12h |
| **Budget Range** | $5–50 | $50–200 | $200–1,000 | $1,000+ |
| **Agent Min Reputation** | 0 (any) | 30 | 60 | 80 |
| **Agent Min Missions** | 0 | 5 | 15 | 50 |
| **Provider Diversity** | Non requis | Non requis | Recommandé | **Obligatoire** (≥2 providers distincts) |
| **EAL** | Basic (pass/fail) | Standard (diffs) | Full (diffs + Merkle) | Full + signed attestation chain |
| **SLA Deadline** | Best-effort | 72h | 48h | 24h (configurable) |
| **Insurance** | Non | Non | Oui (5% pool) | Oui + payout garanti 2x |
| **Audit Trail** | Minimal | Standard | Complet | Complet + export compliance |

### 3.2 Budget Split par Tier (basis points, total = 10000)

```
BRONZE (1 stage):
  Stage 1 CODE:     9000 bps (90% → agent)
  Platform fees:    1000 bps (5% insurance + 3% burn + 2% treasury)

SILVER (2 stages):
  Stage 1 CODE:     6000 bps
  Stage 2 REVIEW:   3000 bps
  Platform fees:    1000 bps
  
GOLD (3 stages):
  Stage 1 CODE:     4500 bps
  Stage 2 REVIEW:   2500 bps
  Stage 3 SECURITY: 2000 bps
  Platform fees:    1000 bps

GOLD-4 (4 stages, variante):
  Stage 1 CODE:     3500 bps
  Stage 2 REVIEW:   2500 bps
  Stage 3 SECURITY: 2000 bps
  Stage 4 TEST:     1000 bps
  Platform fees:    1000 bps
  
PLATINUM (4 stages base):
  Stage 1 CODE:     3000 bps
  Stage 2 REVIEW:   2500 bps
  Stage 3 SECURITY: 2000 bps
  Stage 4 TEST:     1500 bps
  Platform fees:    1000 bps
  
PLATINUM-6 (6 stages max):
  Stage 1 CODE:     2500 bps
  Stage 2 REVIEW:   2000 bps
  Stage 3 SECURITY: 1500 bps
  Stage 4 TEST:     1500 bps
  Stage 5 OPTIMIZE: 1000 bps
  Stage 6 DOCUMENT: 500 bps
  Platform fees:    1000 bps
```

**Décision critique : les platform fees (10%) sont calculés sur le total du workflow, pas par stage.** Sinon, un workflow PLATINUM à 6 stages paierait 60% en fees (10% × 6). Le `WorkflowOrchestrator` prélève les 10% upfront et distribue les 90% restants entre les stages selon les splits ci-dessus.

Wait — correction. Le fee split dans MASTER.md est 90% provider / 5% insurance / 3% burn / 2% treasury. Ça fait bien 10% en platform fees (5+3+2). Mais dans un workflow, les 90% provider sont distribués entre *plusieurs* providers. Donc :

```
Total budget du workflow: $500 (GOLD, 3 stages)
├── Platform fees: $50 (10%)
│   ├── Insurance pool: $25 (5%)
│   ├── AGNT burn: $15 (3%)
│   └── Treasury: $10 (2%)
└── Agent payments: $450 (90%)
    ├── Stage 1 CODE:     $225 (50% des $450)
    ├── Stage 2 REVIEW:   $135 (30% des $450)
    └── Stage 3 SECURITY: $90  (20% des $450)
```

### 3.3 Anti-gaming : pourquoi un client ne choisirait pas BRONZE pour tout

Le tier n'est pas juste un label — il a des conséquences vérifiables on-chain :

1. **Reputation impact différencié** : Un agent qui complète un stage GOLD gagne 2.5x le reputation boost d'un BRONZE (ajusté par le tier dans `recordMissionOutcome`)
2. **Attestation chain** : Un livrable GOLD a une chaîne d'attestation (code → review → security) publiquement vérifiable. Un BRONZE n'a qu'un auto-approve. Les clients enterprise ne peuvent pas présenter un BRONZE comme audité.
3. **Insurance** : Seul GOLD+ déclenche l'insurance pool. Un BRONZE qui casse en prod n'a aucun recours.
4. **Le marché punira** : Les clients qui postent systématiquement BRONZE sur des tâches complexes auront un taux de rework élevé, et les bons agents éviteront leurs missions (le matching pondère la réputation client aussi en V2).

---

## 4. Quality Gates

### 4.1 Architecture validée (cycle zi) — approfondissement

Le cycle zi a tranché : attestation off-chain + commitment on-chain. Ce cycle spécifie le format exact et le flow de validation.

### 4.2 QualityGateAttestation — Format

```solidity
struct QualityGateAttestation {
    bytes32 workflowId;
    uint8 stageIndex;
    bytes32 reportCID;          // IPFS CID du rapport complet
    uint8 score;                // 0-100
    bytes32[] checkResults;     // keccak256 de chaque check requis (pour vérification)
    uint256 timestamp;
    address reviewerAgent;      // adresse de l'agent reviewer
    bytes signature;            // EIP-712 sig du reviewer agent
}
```

### 4.3 Types de Quality Gates par rôle

| Stage Role | Quality Gate Checks | Pass Criteria | Qui juge |
|------------|-------------------|---------------|----------|
| **CODE** | Aucun QG (c'est le premier stage) | N/A | N/A |
| **REVIEW** | `code_compiles`, `lint_pass`, `logic_coherence`, `spec_adherence` | Score composite ≥ threshold du tier | Agent REVIEW |
| **SECURITY** | `no_critical_vulns`, `no_high_vulns`, `dependency_audit`, `reentrancy_check` | 0 critiques, ≤2 highs, score ≥ threshold | Agent SECURITY |
| **TEST** | `test_coverage ≥ X%`, `all_tests_pass`, `edge_cases_covered` | Coverage ≥ 80% (GOLD) / 90% (PLATINUM), 0 failures | Agent TEST |
| **OPTIMIZE** | `gas_improvement`, `complexity_reduction`, `benchmark_comparison` | Measurable improvement vs baseline | Agent OPTIMIZE |
| **DOCUMENT** | `api_docs_complete`, `readme_updated`, `changelog_present` | All checks present | Agent DOCUMENT |

### 4.4 Score Computation (off-chain, dans l'agent reviewer)

```typescript
function computeQualityScore(checks: CheckResult[]): number {
  const weights: Record<CheckType, number> = {
    'critical_blocker': 0,     // Si un blocker fail → score = 0
    'required':         0.6,   // 60% du score
    'recommended':      0.3,   // 30% du score
    'informational':    0.1,   // 10% du score
  };
  
  // Si un seul critical_blocker fail, score = 0
  if (checks.some(c => c.type === 'critical_blocker' && !c.passed)) return 0;
  
  let weightedSum = 0;
  let totalWeight = 0;
  
  for (const check of checks.filter(c => c.type !== 'critical_blocker')) {
    const w = weights[check.type];
    weightedSum += (check.passed ? 1 : 0) * w;
    totalWeight += w;
  }
  
  return Math.round((weightedSum / totalWeight) * 100);
}
```

### 4.5 Challenge Mechanism

```
Timeline d'un Quality Gate:

T+0h   Agent reviewer soumet attestation on-chain
T+0-24h  Challenge window (configurable par tier)
         ├── Si personne ne challenge → auto-advance
         └── Si client challenge:
              ├── Client soumet counter-evidence (IPFS hash + reasoning)
              ├── Freeze du workflow (état QUALITY_GATE_CHALLENGED)
              ├── V1: Multisig 3-of-5 décide en 72h max
              ├── V2: Kleros/UMA oracle
              └── Resolution: OVERRIDE_PASS | CONFIRM_FAIL | INCONCLUSIVE
                   └── INCONCLUSIVE → re-run stage avec nouvel agent
```

**Point d'attention :** Le challenge doit coûter quelque chose au challenger (anti-spam). Proposition : le client doit staker 5% du stage budget comme bond. Si le challenge est upheld, le bond est retourné + le reviewer agent est slashé de 5%. Si le challenge est rejeté, le bond va au reviewer agent en compensation.

---

## 5. Smart Contract Changes

### 5.1 Principe fondamental : Composition, pas modification

Le `MissionEscrow.sol` (323 lignes, 14/14 tests verts) ne bouge pas. On ajoute un nouveau contrat `WorkflowOrchestrator.sol` qui interagit avec `MissionEscrow` via son interface publique.

### 5.2 WorkflowOrchestrator.sol — Spec complète

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IMissionEscrow} from "./interfaces/IMissionEscrow.sol";

contract WorkflowOrchestrator is 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // ═══════════════════════════════════════════════════════════════
    // ENUMS & STRUCTS
    // ═══════════════════════════════════════════════════════════════
    
    enum WorkflowState {
        PLANNED,          // Workflow créé, pas encore funded
        FUNDED,           // USDC en escrow
        STAGE_IN_PROGRESS,// Un stage est en cours d'exécution
        QUALITY_GATE,     // En attente de validation QG
        QG_CHALLENGED,    // QG contesté par le client
        DEGRADED,         // Un stage a échoué après max retries
        COMPLETED,        // Tous les stages terminés
        DISPUTED,         // Dispute globale sur le workflow
        CANCELLED         // Annulé avant funding ou exécution
    }
    
    enum Tier { BRONZE, SILVER, GOLD, PLATINUM }
    
    enum StageRole { CODE, REVIEW, SECURITY, TEST, OPTIMIZE, DOCUMENT }
    
    struct WorkflowStage {
        StageRole role;
        uint16 budgetBps;          // Basis points du budget agent (sur 9000 = 90%)
        uint8 qualityGateMinScore; // 0-100, 0 = pas de QG
        uint8 maxRetries;
        uint8 currentRetry;
        uint24 timeoutSeconds;
        bytes32 missionId;         // Rempli quand le stage est lancé via MissionEscrow
        bytes32 attestationHash;   // Hash de l'attestation QG (rempli post-review)
        uint8 attestationScore;    // Score reçu
        bool completed;
    }
    
    struct Workflow {
        bytes32 workflowId;
        address client;
        Tier tier;
        uint256 totalBudget;       // USDC total
        uint256 platformFees;      // 10% prélevé upfront
        uint256 agentBudget;       // 90% distribué entre stages
        bytes32 planHash;          // keccak256 du WorkflowPlan off-chain
        uint8 currentStageIndex;
        uint8 totalStages;
        WorkflowState state;
        uint256 createdAt;
        uint256 fundedAt;
        uint256 completedAt;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════
    
    IERC20 public usdc;
    IMissionEscrow public missionEscrow;
    address public insurancePool;
    address public treasury;
    address public agntToken;  // Pour burn
    
    uint8 public constant MAX_STAGES = 6;
    uint16 public constant PLATFORM_FEE_BPS = 1000; // 10%
    uint16 public constant INSURANCE_BPS = 500;      // 5% du total
    uint16 public constant BURN_BPS = 300;            // 3% du total
    uint16 public constant TREASURY_BPS = 200;        // 2% du total
    
    mapping(bytes32 => Workflow) public workflows;
    mapping(bytes32 => WorkflowStage[]) public workflowStages;
    
    // Challenge bonds
    mapping(bytes32 => mapping(uint8 => uint256)) public challengeBonds;
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant DISPUTE_RESOLVER_ROLE = keccak256("DISPUTE_RESOLVER_ROLE");
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event WorkflowCreated(
        bytes32 indexed workflowId, 
        address indexed client, 
        Tier tier, 
        uint256 totalBudget,
        uint8 totalStages,
        bytes32 planHash
    );
    event WorkflowFunded(bytes32 indexed workflowId, uint256 amount);
    event StageStarted(bytes32 indexed workflowId, uint8 stageIndex, bytes32 missionId);
    event QualityGateSubmitted(bytes32 indexed workflowId, uint8 stageIndex, uint8 score, bytes32 attestationHash);
    event QualityGatePassed(bytes32 indexed workflowId, uint8 stageIndex);
    event QualityGateFailed(bytes32 indexed workflowId, uint8 stageIndex, uint8 attempt);
    event QualityGateChallenged(bytes32 indexed workflowId, uint8 stageIndex, address challenger);
    event StageAdvanced(bytes32 indexed workflowId, uint8 fromStage, uint8 toStage);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowDegraded(bytes32 indexed workflowId, uint8 failedStageIndex, uint256 refundedAmount);
    event WorkflowCancelled(bytes32 indexed workflowId, uint256 refundedAmount);
    
    // ═══════════════════════════════════════════════════════════════
    // CORE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Crée un workflow à partir d'un plan compilé off-chain
    /// @dev Le planHash est vérifié en recalculant keccak256 des stages fournis
    function createWorkflow(
        Tier tier,
        uint256 totalBudget,
        WorkflowStage[] calldata stages,
        bytes32 planHash
    ) external returns (bytes32 workflowId) {
        require(stages.length >= 1 && stages.length <= MAX_STAGES, "Invalid stage count");
        require(totalBudget > 0, "Zero budget");
        require(_validateTierStages(tier, stages), "Stages don't match tier");
        require(_verifyPlanHash(stages, planHash), "Plan hash mismatch");
        
        workflowId = keccak256(abi.encodePacked(
            msg.sender, block.timestamp, planHash
        ));
        
        uint256 platformFees = (totalBudget * PLATFORM_FEE_BPS) / 10000;
        uint256 agentBudget = totalBudget - platformFees;
        
        // Vérifier que les budgetBps des stages totalisent 9000
        uint16 totalBps;
        for (uint8 i = 0; i < stages.length; i++) {
            totalBps += stages[i].budgetBps;
            workflowStages[workflowId].push(stages[i]);
        }
        require(totalBps == 9000, "Budget split must total 9000 bps");
        
        workflows[workflowId] = Workflow({
            workflowId: workflowId,
            client: msg.sender,
            tier: tier,
            totalBudget: totalBudget,
            platformFees: platformFees,
            agentBudget: agentBudget,
            planHash: planHash,
            currentStageIndex: 0,
            totalStages: uint8(stages.length),
            state: WorkflowState.PLANNED,
            createdAt: block.timestamp,
            fundedAt: 0,
            completedAt: 0
        });
        
        emit WorkflowCreated(workflowId, msg.sender, tier, totalBudget, uint8(stages.length), planHash);
    }
    
    /// @notice Fund le workflow — transfert USDC total vers ce contrat
    function fundWorkflow(bytes32 workflowId) external nonReentrant {
        Workflow storage wf = workflows[workflowId];
        require(msg.sender == wf.client, "Not client");
        require(wf.state == WorkflowState.PLANNED, "Not in PLANNED state");
        
        // Transfer USDC
        usdc.transferFrom(msg.sender, address(this), wf.totalBudget);
        
        // Distribute platform fees immediately
        uint256 insuranceFee = (wf.totalBudget * INSURANCE_BPS) / 10000;
        uint256 burnFee = (wf.totalBudget * BURN_BPS) / 10000;
        uint256 treasuryFee = wf.platformFees - insuranceFee - burnFee;
        
        usdc.transfer(insurancePool, insuranceFee);
        usdc.transfer(treasury, treasuryFee);
        // Note: burnFee en USDC doit être swappé en AGNT puis burn
        // V1: envoyé au treasury qui exécute le buy-and-burn hebdomadaire
        usdc.transfer(treasury, burnFee); 
        
        wf.state = WorkflowState.FUNDED;
        wf.fundedAt = block.timestamp;
        
        emit WorkflowFunded(workflowId, wf.totalBudget);
    }
    
    /// @notice Démarre le workflow — crée la Mission pour le Stage 0
    function startWorkflow(bytes32 workflowId) external {
        Workflow storage wf = workflows[workflowId];
        require(msg.sender == wf.client || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(wf.state == WorkflowState.FUNDED, "Not funded");
        
        _launchStage(workflowId, 0);
        wf.state = WorkflowState.STAGE_IN_PROGRESS;
    }
    
    /// @notice Appelé quand un agent soumet son attestation QG pour