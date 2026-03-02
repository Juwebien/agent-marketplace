

# Cycle zp — Budget-Tiered Workflows Architecture

---

## 1. Core Insight de ce cycle

**Le budget n'achète pas du compute — il achète un pipeline de réduction d'incertitude dont la profondeur est proportionnelle au risque financier que le client veut éliminer.** C'est un changement de paradigme par rapport à tout ce qui existe sur le marché des agents IA. Aujourd'hui, un client qui paie plus cher obtient un "meilleur" agent (plus gros modèle, plus de GPU). Sur Agent Marketplace, un client qui paie plus cher obtient **plus d'étapes de vérification indépendantes** — chaque dollar supplémentaire finance un adversaire de plus dans une chaîne de confiance. C'est exactement le modèle de l'audit financier : PwC ne produit pas les comptes, elle les vérifie. La valeur est dans la vérification, pas dans la production. L'insight opérationnel clé est que ce modèle transforme le pricing d'un marché bilatéral opaque ("combien vaut cet agent ?") en un **menu lisible** ("combien de vérification voulez-vous ?") — ce qui résout le problem #1 du go-to-market : la discovery pricing pour un nouveau type de service.

---

## 2. Workflow Engine Design

### 2.1 Modèle retenu : Pipeline séquentiel strict (V1)

Conformément aux décisions du cycle zo, le modèle V1 est **strictement séquentiel**. Pas de DAG arbitraire, pas de fan-out parallèle. Les raisons sont définitives et ne seront pas re-débattues ici.

```
Stage[0] ──QG[0]──→ Stage[1] ──QG[1]──→ Stage[2] ──QG[2]──→ ... ──→ COMPLETED
              │                   │                   │
              ↓                   ↓                   ↓
           FAILED              FAILED              FAILED
              │                   │                   │
              └───────────────────┴───────────────────┘
                              REFUND (stages non-exécutés)
```

### 2.2 Entités du Workflow Engine

```
┌─────────────────────────────────────────────────────────┐
│                    Workflow                               │
│  workflowId: bytes32                                     │
│  client: address                                         │
│  tier: enum { BRONZE, SILVER, GOLD, PLATINUM }           │
│  totalBudget: uint256 (USDC)                             │
│  currentStage: uint8                                     │
│  state: WorkflowState                                    │
│  createdAt: uint256                                      │
│  deadline: uint256 (global)                               │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │ Stage[0] │→ │ Stage[1] │→ │ Stage[2] │→ ...          │
│  │ missionId│  │ missionId│  │ missionId│               │
│  │ role     │  │ role     │  │ role     │               │
│  │ budget % │  │ budget % │  │ budget % │               │
│  │ agentId  │  │ agentId  │  │ agentId  │               │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘               │
│        │             │             │                     │
│  ┌─────┴────┐  ┌─────┴────┐  ┌─────┴────┐               │
│  │  QG[0]   │  │  QG[1]   │  │  QG[2]   │               │
│  │reviewerId│  │reviewerId│  │reviewerId│               │
│  │threshold │  │threshold │  │threshold │               │
│  │attestHash│  │attestHash│  │attestHash│               │
│  └──────────┘  └──────────┘  └──────────┘               │
└─────────────────────────────────────────────────────────┘
```

### 2.3 Workflow State Machine

```
DRAFT → FUNDED → STAGE_ACTIVE → STAGE_REVIEW → STAGE_PASSED ──→ STAGE_ACTIVE (next)
                                     │                                    │
                                     ↓                              (last stage)
                                STAGE_FAILED → REMEDIATION ──→ STAGE_ACTIVE (retry)
                                     │              │                     │
                                     │         (max retries)              ↓
                                     ↓                              COMPLETED
                                 ABORTED → PARTIAL_REFUND
                                 
FUNDED → CANCELLED (client, before any stage starts)
Any → DISPUTED (client challenge on QG attestation)
```

**États détaillés :**

| State | Signification | Transitions possibles |
|---|---|---|
| `DRAFT` | Workflow créé mais pas encore financé | `FUNDED`, `CANCELLED` |
| `FUNDED` | USDC déposés dans l'escrow global | `STAGE_ACTIVE`, `CANCELLED` |
| `STAGE_ACTIVE` | Un stage est en cours d'exécution par un agent | `STAGE_REVIEW` |
| `STAGE_REVIEW` | L'output du stage est en review par un agent reviewer | `STAGE_PASSED`, `STAGE_FAILED` |
| `STAGE_PASSED` | QG passé, prêt pour le stage suivant | `STAGE_ACTIVE` (next), `COMPLETED` |
| `STAGE_FAILED` | QG échoué | `REMEDIATION`, `ABORTED` |
| `REMEDIATION` | L'agent exécutant corrige (max 1 retry en V1) | `STAGE_REVIEW` |
| `COMPLETED` | Tous les stages passés, paiements libérés | Terminal |
| `ABORTED` | Échec irrémédiable, refund partiel | Terminal |
| `CANCELLED` | Annulé avant exécution | Terminal |
| `DISPUTED` | Client conteste une attestation QG | `RESOLVED` |

### 2.4 Invariants critiques

1. **Un seul stage actif à la fois.** Pas de parallélisme en V1.
2. **Un stage ne commence que si le QG précédent est passé.** Enforced on-chain.
3. **Max 6 stages.** Hard cap dans le contrat. `require(stages.length <= 6)`.
4. **Max 1 retry par stage.** Au-delà, le workflow est `ABORTED` avec refund partiel.
5. **L'agent reviewer d'un stage ≠ l'agent exécutant de ce stage.** Enforced en V2 on-chain, soft en V1 (vérification off-chain).
6. **Le budget split est immutable après `FUNDED`.** Pas de réallocation dynamique.

---

## 3. Budget Tiers — Spec détaillée

### 3.1 Définition des Tiers

| | **Bronze** | **Silver** | **Gold** | **Platinum** |
|---|---|---|---|---|
| **Stages** | 1 | 3 | 5 | 6 (custom) |
| **Pipeline** | `[Execute]` | `[Execute → Review → Test]` | `[Execute → Review → Security → Test → Integration]` | Custom (négocié) |
| **Roles agents** | Coder | Coder, Reviewer, Tester | Coder, Reviewer, Security Auditor, Tester, Integration Engineer | Tout Gold + compliance/custom |
| **Quality Gates** | 0 (auto-approve 48h) | 2 (post-execute, post-review) | 4 (entre chaque stage) | 5+ |
| **QG Threshold** | N/A | score ≥ 6/10 | score ≥ 7/10 | score ≥ 8/10 |
| **Retry on fail** | 0 | 1 per stage | 1 per stage | 2 per stage |
| **SLA Deadline** | Best effort (72h default) | 48h | 24h | Custom (contractuel) |
| **Budget range** | $10–$50 | $50–$200 | $200–$1,000 | $1,000+ |
| **Insurance** | Standard (5%) | Standard (5%) | Enhanced (7%) | Premium (10%) |
| **Audit trail** | Minimal (output hash) | Standard (all stage hashes) | Full (EAL + all attestations) | Full + compliance export |
| **Dispute resolution** | Auto-approve only | Standard (reviewer pool) | Priority (senior reviewers) | Dedicated arbitrator |

### 3.2 Budget Split par Tier (du budget total après platform fees)

**Bronze (1 stage):**
```
Execute: 100%
QG:      0% (auto-approve)
```

**Silver (3 stages):**
```
Execute:  55%   ← agent principal
Review:   25%   ← reviewer indépendant
Test:     15%   ← testeur
QG pool:   5%   ← rémunère les attestations des quality gates
```

**Gold (5 stages):**
```
Execute:     40%
Review:      18%
Security:    18%
Test:        12%
Integration:  7%
QG pool:      5%
```

**Platinum (6 stages, custom):**
```
Négocié par le client et validé par le WorkflowEscrow.
Contrainte: aucun stage < 5% du budget total (anti-spam, sinon aucun agent sérieux ne bid).
QG pool: minimum 5%.
```

### 3.3 Justification économique

La question fondamentale : **pourquoi un client paierait-il Gold ($500) au lieu de Bronze ($30) pour la même issue ?**

**Modèle de valeur espérée :**

| Tier | Coût | P(rework) estimé | Coût rework (heures humaines) | Coût total espéré |
|---|---|---|---|---|
| Bronze | $30 | ~40% | 4h × $150/h = $600 | $30 + 0.4 × $600 = **$270** |
| Silver | $120 | ~15% | 4h × $150/h = $600 | $120 + 0.15 × $600 = **$210** |
| Gold | $500 | ~3% | 4h × $150/h = $600 | $500 + 0.03 × $600 = **$518** |

**Conclusion :** Gold n'est rationnel que pour des issues dont le coût de rework est élevé (>$2K). Le sweet spot pour la majorité des clients est **Silver**. Gold et Platinum ciblent les cas à haut risque (security-critical, production deployments, compliance-required).

> **Important :** Ces P(rework) sont des *hypothèses initiales*. Le marketplace collectera des données réelles et ajustera. C'est pourquoi on ne les encode PAS on-chain (décision zo §2.1).

### 3.4 Mapping vers les Personas

| Persona | Tier naturel | Raison |
|---|---|---|
| Startup (Persona A) | Bronze / Silver | Budget limité, tolérance au rework, itération rapide |
| Enterprise (Persona B) | Gold / Platinum | Compliance, auditabilité, coût du rework >> coût du workflow |
| Agent Coordinator (Persona D) | Crée des workflows custom | Orchestre ses propres pipelines, peut proposer des templates |

---

## 4. Quality Gates

### 4.1 Architecture hybride (rappel zo §1.4)

```
                    OFF-CHAIN                          ON-CHAIN
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ 1. Agent exécutant produit   │   │                              │
│    output → IPFS (CID)       │──→│ 3. submitStageOutput(        │
│                              │   │      workflowId,             │
│ 2. Agent reviewer évalue     │   │      stageIndex,             │
│    output off-chain          │   │      outputCID,              │
│    → rapport IPFS            │──→│      attestationHash,        │
│    → score [0-10]            │   │      score,                  │
│    → signature Ed25519       │   │      reviewerSig             │
│                              │   │    )                         │
└──────────────────────────────┘   │                              │
                                   │ 4. if score >= threshold:    │
                                   │      advanceStage()          │
                                   │    else:                     │
                                   │      failStage()             │
                                   └──────────────────────────────┘
```

### 4.2 Attestation struct on-chain

```solidity
struct QualityGateAttestation {
    bytes32 workflowId;
    uint8 stageIndex;
    bytes32 outputCID;        // IPFS hash de l'output du stage
    bytes32 reportCID;        // IPFS hash du rapport de review
    uint8 score;              // 0-10
    address reviewer;         // address de l'agent reviewer
    bytes signature;          // signature du reviewer sur hash(workflowId, stageIndex, outputCID, score)
    uint256 timestamp;
}
```

### 4.3 Critères de scoring par role

Le score 0-10 n'est **pas** subjectif. Chaque rôle de stage a une **rubrique de scoring** publiée et versionée sur IPFS. Cela réduit (sans éliminer) l'arbitraire.

**Rubrique "Code Review" (stage Review):**

| Score | Critères |
|---|---|
| 0-3 | Ne compile pas / erreurs de syntaxe / ne répond pas à l'issue |
| 4-5 | Fonctionne mais : pas de tests, style inconsistant, imports inutiles |
| 6-7 | Fonctionne, tests présents, style OK, edge cases partiellement couverts |
| 8-9 | Excellente qualité, tests complets, documentation, edge cases couverts |
| 10 | Production-ready, au-delà des attentes, optimisé |

**Rubrique "Security Audit" (stage Security):**

| Score | Critères |
|---|---|
| 0-3 | Vulnérabilités critiques (injection, auth bypass, data leak) |
| 4-5 | Vulnérabilités moyennes, pas de sanitization d'inputs |
| 6-7 | Pas de vulns critiques, OWASP Top 10 adressé, mais améliorations possibles |
| 8-9 | Audit clean, rate limiting, input validation, error handling robuste |
| 10 | Conforme audit de sécurité professionnel (Semgrep clean, deps auditées) |

**Rubrique "Test" (stage Test):**

| Score | Critères |
|---|---|
| 0-3 | Pas de tests ou tests triviaux (coverage < 20%) |
| 4-5 | Tests unitaires basiques (coverage 20-50%) |
| 6-7 | Tests unitaires + intégration (coverage 50-80%) |
| 8-9 | Tests complets (coverage > 80%), edge cases, error paths |
| 10 | Coverage > 90%, property-based tests, mutation testing passé |

### 4.4 Anti-gaming des Quality Gates

**Problème :** Un agent reviewer collusif avec l'agent exécutant peut rubber-stamp un output médiocre.

**Mitigations V1 :**

1. **Random reviewer assignment.** L'agent reviewer est sélectionné par le matching engine, pas choisi par l'agent exécutant. Le reviewer est tiré d'un pool d'agents avec le tag `reviewer:{domain}` et un `reputation_score >= 60`.

2. **Spot-check sampling.** 10% des QG attestations sont re-évaluées par un second reviewer indépendant. Divergence de score > 3 points → flag + enquête. Reviewer collusif → slash du stake.

3. **Skin in the game du reviewer.** Le reviewer est payé via le QG pool (5% du budget workflow). Si son attestation est contestée avec succès en dispute, il perd sa rémunération ET est slashé (même mécanisme que les agents exécutants).

4. **Reputation feedback loop.** Un reviewer dont les attestations sont fréquemment contestées ou divergent en spot-check voit son `reputation_score` baisser, ce qui le sort du pool de reviewers.

**Mitigations V2 :**
- `require(stageAgent != reviewerAgent)` on-chain
- Reviewer staking minimum spécifique (2,000 AGNT au lieu de 1,000)
- Arbitrage externe (Kleros/UMA) pour disputes QG

---

## 5. Smart Contract Changes

### 5.1 Principe fondamental : Composition, pas modification

`MissionEscrow.sol` (323 lignes, 14/14 tests verts) **ne change pas**. Le nouveau contrat `WorkflowEscrow.sol` est un orchestrateur qui :
- Appelle `MissionEscrow.createMission()` pour chaque stage
- Écoute les events `MissionCompleted` / `MissionFailed`
- Gère le séquencement et les quality gates

```
┌────────────────────┐
│  WorkflowEscrow    │  ← NOUVEAU
│  (orchestration)   │
│                    │
│  createWorkflow()  │
│  advanceStage()    │
│  failStage()       │
│  abortWorkflow()   │
│  disputeQG()       │
└──────┬─────────────┘
       │ calls
       ↓
┌────────────────────┐
│  MissionEscrow     │  ← EXISTANT (inchangé)
│  (finance)         │
│                    │
│  createMission()   │
│  deliverMission()  │
│  approveMission()  │
│  cancelMission()   │
└────────────────────┘
```

### 5.2 WorkflowEscrow.sol — Interface complète

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWorkflowEscrow {
    
    // ──────────── Enums ────────────
    
    enum WorkflowTier { BRONZE, SILVER, GOLD, PLATINUM }
    
    enum WorkflowState { 
        DRAFT,
        FUNDED, 
        STAGE_ACTIVE, 
        STAGE_REVIEW, 
        STAGE_PASSED,
        STAGE_FAILED,
        REMEDIATION,
        COMPLETED, 
        ABORTED, 
        CANCELLED,
        DISPUTED
    }
    
    // ──────────── Structs ────────────
    
    struct StageConfig {
        bytes32 roleTag;           // e.g., keccak256("coder"), keccak256("reviewer")
        uint16 budgetBps;          // basis points du budget total (e.g., 5500 = 55%)
        uint8 qgThreshold;         // score minimum pour passer (0 = pas de QG, auto-pass)
        uint32 stageDeadline;      // seconds à partir du start du stage
    }
    
    struct StageState {
        bytes32 missionId;         // ID dans MissionEscrow
        bytes32 agentId;           // agent assigné
        bytes32 reviewerAgentId;   // reviewer assigné (0x0 si pas de QG)
        bytes32 outputCID;         // IPFS hash de l'output
        bytes32 attestationCID;    // IPFS hash du rapport QG
        uint8 qgScore;            // score QG attribué
        uint8 retryCount;          // nombre de retries effectués
        bool completed;
        bool passed;
    }
    
    struct Workflow {
        bytes32 workflowId;
        address client;
        WorkflowTier tier;
        uint256 totalBudget;       // USDC total (incluant platform fees)
        uint8 stageCount;
        uint8 currentStageIndex;
        WorkflowState state;
        uint256 createdAt;
        uint256 globalDeadline;
        bytes32 specCID;           // IPFS hash du TDL/spec de la mission globale
    }
    
    // ──────────── Events ────────────
    
    event WorkflowCreated(
        bytes32 indexed workflowId, 
        address indexed client, 
        WorkflowTier tier, 
        uint256 totalBudget,
        uint8 stageCount
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
        bytes32 outputCID
    );
    
    event QualityGateSubmitted(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        uint8 score, 
        bool passed,
        address reviewer
    );
    
    event StageAdvanced(
        bytes32 indexed workflowId, 
        uint8 fromStage, 
        uint8 toStage
    );
    
    event StageFailed(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        uint8 score
    );
    
    event WorkflowCompleted(
        bytes32 indexed workflowId, 
        uint256 totalPaid
    );
    
    event WorkflowAborted(
        bytes32 indexed workflowId, 
        uint8 failedStageIndex, 
        uint256 refundedAmount
    );
    
    event QualityGateDisputed(
        bytes32 indexed workflowId, 
        uint8 stageIndex, 
        string reason
    );
    
    // ──────────── Core Functions ────────────
    
    /// @notice Crée un workflow avec ses stages configurés
    /// @dev Le budget split doit totaliser 10000 bps. Max 6 stages.
    function createWorkflow(
        WorkflowTier tier,
        uint256 totalBudget,
        uint256 globalDeadline,
        bytes32 specCID,
        StageConfig[] calldata stages
    ) external returns (bytes32 workflowId);
    
    /// @notice Crée un workflow depuis un template de tier prédéfini
    function createWorkflowFromTier(
        WorkflowTier tier,
        uint256 totalBudget,
        uint256 globalDeadline,
        bytes32 specCID
    ) external returns (bytes32 workflowId);
    
    /// @notice Finance le workflow (USDC transfer dans l'escrow)
    function fundWorkflow(bytes32 workflowId) external;
    
    /// @notice Démarre le stage courant en créant une mission dans MissionEscrow
    /// @dev Appelé par le matching engine ou le client
    function startStage(
        bytes32 workflowId, 
        bytes32 agentId
    ) external returns (bytes32 missionId);
    
    /// @notice Assigne un reviewer pour le QG du stage courant
    function assignReviewer(
        bytes32 workflowId, 
        uint8 stageIndex, 
        bytes32 reviewerAgentId
    ) external;
    
    /// @notice Soumet l'output d'un stage (appelé quand MissionEscrow.deliverMission est done)
    function submitStageOutput(
        bytes32 workflowId, 
        uint8 stageIndex, 
        bytes32 outputCID
    ) external;
    
    /// @notice Soumet l'attestation QG (appelé par le reviewer)
    function submitQualityGateAttestation(
        bytes32 workflowId,
        uint8 stageIndex,
        bytes32 reportCID,
        uint8 score,
        bytes calldata reviewerSignature
    ) external;
    
    /// @notice Force l'avancement si QG auto-approve (Bronze) ou timeout
    function autoAdvanceStage(bytes32 workflowId) external;
    
    /// @notice Retry un stage échoué (max retries selon tier)
    function retryStage(bytes32 workflowId) external;
    
    /// @notice Abort le workflow après échec irrémédiable
    function abortWorkflow(bytes32 workflowId) external;
    
    /// @notice Client annule avant que le premier stage ne commence
    function cancelWorkflow(bytes32 workflowId) external;
    
    /// @notice Client dispute une attestation QG
    function disputeQualityGate(
        bytes32 workflowId, 
        uint8 stageIndex, 
        string calldata reason
    ) external;
    
    // ──────────── View Functions ────────────
    
    function getWorkflow(bytes32 workflowId) external view returns (Workflow memory);
    function getStageConfig(bytes32 workflowId, uint8 stageIndex) external view returns (StageConfig memory);
    function getStageState(bytes32 workflowId, uint8 stageIndex) external view returns (StageState memory);
    function getWorkflowState(bytes32 workflowId) external view returns (WorkflowState);
    function getTierTemplate(WorkflowTier tier) external view returns (StageConfig[] memory);
    function calculateStageBudget(bytes32 workflowId, uint8 stageIndex) external view returns (uint256);
    function getRefundableAmount(bytes32 workflowId) external view returns (uint256);
}
```

### 5.3 Interaction WorkflowEscrow ↔ MissionEscrow

**Séquence d'un stage complet :**

```
WorkflowEscrow                        MissionEscrow
     │                                      │
     │  startStage(workflowId, agentId)     │
     │──────────────────────────────────────→│
     │  createMission(agentId, stageBudget,  │
     │               stageDeadline, specCID) │
     │←──────────────────────────────────────│
     │  returns missionId                    │
     │                                      │
     │  ... agent exécute ...               │
     │                                      │
     │  [Event: MissionDelivered]           │
     │←──────────────────────────────────────│
     │                                      │
     │  submitStageOutput(outputCID)        │
     │  → reviewer évalue off-chain         │
     │  submitQualityGateAttestation(...)   │
     │                                      │
     │  if passed:                          │
     │    approveMission(missionId)         │
     │──────────────────────────────────────→│
     │    → funds released to stage agent   │
     │    advanceStage()                    │
     │                                      │
     │  if failed:                          │
     │    failStage()                       │
     │    → retry or abort                  │
```

### 5.4 Gestion USDC — Qui détient les fonds ?

**Option A — WorkflowEscrow détient tout, fund chaque stage progressivement :**

```
Client ─── USDC ───→ WorkflowEscrow (holds total budget)
                         │
                         │ fund stage N budget
                         ↓
                    MissionEscrow (holds stage N budget)
                         │
                         │ release on approve
                         ↓
                    Agent (receives stage payment)
```

**Option B — MissionEscrow détient tout dès le départ (plusieurs missions pre-funded) :**

Problème : on ne connaît pas les agents de chaque stage à l'avance. On ne peut pas créer toutes les missions au moment du funding.

**Décision : Option A.** `WorkflowEscrow` agit comme un **trésorier** qui détient le budget total et libère progressivement vers `MissionEscrow` au fur et à mesure que chaque stage commence. Cela signifie que `WorkflowEscrow` **doit** toucher aux USDC, contrairement à l'intention initiale du cycle zo.

**Réconciliation avec la décision zo §2.3 :** La décision zo disait que `WorkflowEscrow` ne devait pas toucher aux USDC. C'était une aspiration correcte mais impraticable. Le compromis : `WorkflowEscrow` ne gère PAS le payout final aux agents — il délègue entièrement à `MissionEscrow` via `createMission()` avec le montant du stage. `WorkflowEscrow` ne fait que : (1) recevoir le USDC total du client, (2) transférer le budget de chaque stage à `MissionEscrow` quand le stage commence, (3) refund le reste si abort.

> **Note d'audit critique :** `WorkflowEscrow` aura un `USDC.approve(missionEscrow, stageBudget)` pour chaque stage. Cela crée une surface d'approbation. Mitiger via `approve()` pour le montant exact du stage, pas un blanket approval.

### 5.5 Modifications mineures nécessaires sur MissionEscrow

Malgré le principe de non-modification, **un seul changement** est nécessaire sur `MissionEscrow` :

```solidity
// AVANT: seul le client (EOA) peut createMission
function createMission(...) external returns (bytes32) {
    // msg.sender = client
}

// APRÈS: un contrat peut créer une mission au nom d'un client
function createMissionFor(
    address onBehalfOf,     // ← le vrai client
    bytes32 agentId, 
    uint256 totalAmount, 
    uint256 deadline, 
    string calldata ipfsMissionHash
) external returns (bytes32) {
    require(authorizedCallers[msg.sender], "Not authorized");
    // ... même logique, mais mission.client = onBehalfOf
}
```

**Justification :** Sans cela, `WorkflowEscrow` ne peut pas créer de missions dans `MissionEscrow