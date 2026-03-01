

# Cycle zi — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le workflow est le produit principal, pas la mission standalone

**Justification :** Le reframing est correct et stratégiquement différenciant. Le marché du "hire a single AI agent" est déjà saturé (Devin, Factory, Codegen, Cursor background agents). Ce qui n'existe pas, c'est un marché de **chaînes de confiance composables** où le livrable final est audité par construction. `WorkflowEscrow.sol` devient le contrat principal. `MissionEscrow.sol` reste l'unité atomique interne — exactement comme un pod Kubernetes n'est pas exposé directement au user, mais c'est l'unité d'exécution.

**Conséquence architecturale concrète :** L'API publique du marketplace (ce que voit le client) est `createWorkflow()`, pas `createMission()`. `createMission()` devient un appel interne déclenché par `WorkflowEscrow` à chaque avancement de stage.

### 1.2 ✅ Pipeline séquentiel contraint, max 6 stages (V1)

**Justification :** Le DAG arbitraire est un piège d'ingénierie prématurée. Les workflows réels de dev (code → review → security → test) sont séquentiels dans 90%+ des cas. Les 10% restants (parallélisation code frontend + backend) sont un problème V2. Le cap à 6 stages est empiriquement solide : au-delà, le coût de coordination inter-stages dépasse la valeur du stage additionnel.

**Nuance ajoutée :** Le plafond de 6 n'est pas arbitraire — il correspond au maximum observé dans les pipelines CI/CD enterprise réels qui convergent. Un workflow PLATINUM typique fait 4 stages (code → review → security → test). Le 5ème et 6ème sont réservés à des cas spécifiques (optimization, documentation formelle).

### 1.3 ✅ WorkflowEscrow compose MissionEscrow, ne le modifie pas

**Justification :** Les 14 tests Foundry verts sont un actif. Les casser pour ajouter le workflow serait une faute d'architecture. Le pattern retenu :

```solidity
// WorkflowEscrow.sol agit comme meta-client de MissionEscrow
function advanceStage(bytes32 workflowId) external {
    // Vérifie quality gate du stage précédent
    // Appelle missionEscrow.createMission() pour le stage suivant
    // Transfère le budget alloué à ce stage
}
```

`WorkflowEscrow` est un **state machine** qui orchestre des appels à `MissionEscrow`. Aucune modification du contrat existant. Composition pure.

### 1.4 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Justification :** C'est la seule architecture viable. Trois raisons irréfutables :

1. **Impossibilité computationnelle** — Un smart contract ne peut pas évaluer la qualité d'un code review. Même avec un oracle IA, le coût gas pour transmettre un rapport complet est prohibitif.
2. **Conflit d'intérêt** — Si l'agent reviewer est juge et partie, l'attestation doit être challengeable. Ça nécessite un mécanisme de dispute, pas un automate on-chain.
3. **Coût** — Stocker un rapport de review on-chain coûterait des dizaines de dollars en gas. Le hash + score + signature coûte <$0.10 sur L2.

**Pattern retenu :**

```
┌──────────────────────────────────────────────────────────────────┐
│                    QUALITY GATE FLOW                             │
│                                                                  │
│  Agent Reviewer                     On-Chain                     │
│  ┌─────────────┐                   ┌──────────────────┐         │
│  │ Exécute      │                   │ QualityGate-     │         │
│  │ review       │──→ Rapport ──→   │ Attestation      │         │
│  │ off-chain    │    (IPFS)        │                  │         │
│  └─────────────┘                   │ • reportHash     │         │
│                                     │ • score (0-100) │         │
│                                     │ • agentSig      │         │
│                                     │ • timestamp      │         │
│                                     └──────┬───────────┘         │
│                                            │                     │
│                              ┌─────────────┼─────────────┐      │
│                              │ score ≥     │ score <      │      │
│                              │ threshold   │ threshold    │      │
│                              ▼             ▼              │      │
│                          ADVANCE       FAIL/RETRY         │      │
│                          STAGE         (or DISPUTE)       │      │
│                                                           │      │
│  Challenge window: 24h après attestation                  │      │
│  Dispute: Client soumet counter-evidence → arbitrage V2   │      │
└──────────────────────────────────────────────────────────────────┘
```

### 1.5 ✅ Tiers comme templates de workflows prédéfinis

**Justification :** Le client ne doit pas designer son workflow from scratch. Les tiers sont des **templates** avec des paramètres par défaut sensés.

| Tier | Stages | Quality Gates | Budget Range | SLA |
|------|--------|---------------|--------------|-----|
| **BRONZE** | 1 (code only) | Aucun | $5-50 | Best-effort |
| **SILVER** | 2 (code + review) | Score ≥ 60 | $50-200 | 48h |
| **GOLD** | 3 (code + review + test) | Score ≥ 75 | $200-1000 | 24h |
| **PLATINUM** | 4 (code + review + security + test) | Score ≥ 85 | $1000+ | 12h |

---

## 2. Décisions Rejetées

### 2.1 ❌ WorkflowEscrow comme smart contract monolithique séparé

**Rejeté.** Le cycle propose `WorkflowEscrow.sol` comme contrat autonome qui "inherits/composes MissionEscrow". Le risque est un contrat de 600+ lignes avec une surface d'attaque doublée.

**Décision retenue à la place :** Architecture en deux contrats distincts avec interaction via interfaces :

```
WorkflowOrchestrator.sol (nouveau, ~250 lignes)
├── State machine du workflow (stages, transitions, tiers)
├── Quality gate verification (hash + score + sig)
├── Budget split logic
└── Calls IMissionEscrow pour chaque stage

MissionEscrow.sol (existant, 323 lignes, inchangé)
├── Escrow atomique par mission/stage
├── Paiement conditionnel
└── Dispute basique
```

**Pourquoi :** Séparation des responsabilités. `WorkflowOrchestrator` gère la logique métier du pipeline. `MissionEscrow` gère l'argent. Le contrat qui gère l'argent reste petit, auditable, et déjà testé. Le contrat qui gère l'orchestration peut évoluer plus vite avec moins de risque financier.

### 2.2 ❌ Retry infini sur failure de stage

**Rejeté.** Le diagramme original montre `retry/abort` à chaque stage failure, mais sans contrainte de retry. Un agent médiocre qui retry en boucle consomme du temps client et bloque le workflow.

**Décision retenue :**

```
maxRetries par stage (configurable par tier) :
  BRONZE:   0 retries (fail = abort)
  SILVER:   1 retry
  GOLD:     2 retries
  PLATINUM: 2 retries + escalation vers agent backup

Retry ≠ même agent qui recommence.
Retry = reassignment vers un autre agent du même rôle.
```

**Justification :** Le retry par le même agent est insensé — si son output a échoué au quality gate, le reprendre avec le même modèle/config produit le même résultat. Le retry doit être un **reassignment** avec pénalité de réputation pour l'agent qui a échoué.

### 2.3 ❌ Score de quality gate entièrement poussé par l'agent reviewer

**Rejeté.** Conflit d'intérêt pur. L'agent reviewer est payé quand le stage passe. Il a intérêt à donner un score juste au-dessus du seuil pour être payé rapidement.

**Décision retenue : Dual attestation model**

```
Score final = weighted_average(
    agent_reviewer_score × 0.4,
    automated_checks_score × 0.6
)

automated_checks = {
    compilation_success: bool → 0/25 points,
    test_pass_rate: float → 0-25 points,
    lint_score: float → 0-25 points,
    coverage_delta: float → 0-25 points
}
```

La composante automatisée (60% du poids) est objective et vérifiable. La composante agent (40%) capture le jugement qualitatif (architecture, lisibilité, pertinence métier). Ce split rend la manipulation par l'agent reviewer non-viable : même un score agent de 100/100 ne suffit pas si les checks automatisés échouent.

### 2.4 ❌ Pricing linéaire par nombre de stages

**Rejeté.** Le coût réel d'un workflow n'est pas `n × coût_stage`. Il y a un **overhead de coordination** non-linéaire : context passing entre stages, latence cumulée, risque de failure cascade.

**Décision retenue : Pricing avec coordination premium**

```
workflow_price = Σ(stage_costs) × coordination_multiplier × tier_margin

coordination_multiplier:
  1 stage:  1.0x (pas d'overhead)
  2 stages: 1.15x
  3 stages: 1.25x
  4 stages: 1.35x

tier_margin:
  BRONZE:   1.0x (no margin, loss leader)
  SILVER:   1.1x
  GOLD:     1.2x
  PLATINUM: 1.4x

Exemple GOLD (3 stages):
  Coder: $80 + Reviewer: $30 + Tester: $40 = $150
  × 1.25 (coordination) × 1.2 (tier) = $225
```

Le `coordination_multiplier` capture le coût réel de context serialization, quality gate execution, et retry probability. Le `tier_margin` finance l'insurance pool et le platform revenue.

---

## 3. Nouveaux Insights

### 3.1 🆕 Context Serialization est le bottleneck technique critique

Les cycles précédents n'ont pas abordé le problème le plus dur du pipeline séquentiel : **comment le Stage N+1 reçoit-il le contexte du Stage N ?**

L'output d'un stage coder n'est pas un simple artefact — c'est un diff Git, des choix architecturaux, des trade-offs, des contraintes découvertes en cours de route. Si le stage reviewer reçoit uniquement le diff sans le raisonnement, il ne peut pas faire un review pertinent.

**Proposition : Structured Stage Output Protocol (SSOP)**

```json
{
  "stageOutput": {
    "artifacts": ["ipfs://Qm.../diff.patch"],
    "reasoning": "ipfs://Qm.../reasoning.md",
    "decisions": [
      {
        "decision": "Used SQLite instead of Postgres",
        "rationale": "Client spec says 'simple setup', SQLite fits",
        "trade_offs": ["No concurrent writes", "Max 1TB"]
      }
    ],
    "open_questions": [
      "Auth strategy not specified — assumed JWT"
    ],
    "test_hints": [
      "Edge case: empty input on /api/parse needs handling"
    ]
  }
}
```

Chaque agent est **contractuellement tenu** (via le quality gate) de produire un output conforme au SSOP. Un output sans `reasoning` est automatiquement rejeté (score automated_checks = 0 sur la composante structure).

**C'est un insight nouveau et critique** parce qu'il transforme le quality gate d'un simple pass/fail binaire en un **protocole de communication inter-agents**. Sans ça, le pipeline séquentiel est une chaîne de black boxes qui ne se comprennent pas.

### 3.2 🆕 Le workflow crée un nouveau type d'agent : le Coordinator

Les cycles précédents modélisent uniquement des agents exécutants (coder, reviewer, tester). Mais un pipeline de 4 stages avec quality gates, retries, et context passing nécessite un **agent orchestrateur** qui :

- Décompose la spec client en instructions par stage
- Adapte le contexte entre stages (reformate l'output du coder en input du reviewer)
- Décide du retry vs abort vs escalation
- Agrège les résultats finaux pour le client

**Ce coordinator n'est pas le smart contract.** Le smart contract est la state machine. Le coordinator est un **agent IA off-chain** qui pilote les transitions.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Client                                                     │
│    │                                                        │
│    ▼                                                        │
│  Coordinator Agent (off-chain)                              │
│    │  ├── Décompose spec → stage instructions               │
│    │  ├── Adapte context entre stages                       │
│    │  ├── Décide retry/abort/escalate                       │
│    │  └── Agrège résultat final                             │
│    │                                                        │
│    ├──→ WorkflowOrchestrator.sol (on-chain state machine)   │
│    │       ├── advanceStage()                               │
│    │       ├── failStage()                                  │
│    │       └── completeWorkflow()                           │
│    │                                                        │
│    ├──�� Coder Agent                                         │
│    ├──→ Reviewer Agent                                      │
│    ├──→ Security Agent                                      │
│    └──→ Tester Agent                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Conséquence sur le business model :** Le coordinator prend un fee (inclus dans le `coordination_multiplier`). Les meilleurs coordinators deviennent un avantage compétitif de la plateforme. En V1, c'est un service platform-operated. En V2, des coordinators tiers peuvent se register sur le marketplace.

### 3.3 🆕 Le workflow failure mode le plus dangereux n'est pas technique — c'est le "Stage 3 failure on a $1000 workflow"

Scénario cauchemar : un client paie $1000 pour un workflow PLATINUM. Stages 1-2-3 passent (coder, reviewer, security — $700 dépensés). Stage 4 (test) échoue après 2 retries. Le workflow avorte.

Le client a dépensé $700 pour un livrable inutilisable (code non testé = code non livrable). Les agents des stages 1-3 ont été payés. Le client est furieux.

**Ce n'est pas un edge case. C'est le scénario principal de churn client.**

**Proposition : Budget escrow progressif avec refund conditionnel**

```
On-chain budget flow pour un workflow $1000 PLATINUM :
  
  Workflow creation: Client dépose $1000 dans WorkflowOrchestrator
  
  Stage 1 complete: $250 → MissionEscrow stage 1 → released to coder
                    $750 reste en escrow
  
  Stage 2 complete: $150 → MissionEscrow stage 2 → released to reviewer
                    $600 reste en escrow
  
  Stage 3 complete: $200 → MissionEscrow stage 3 → released to security
                    $400 reste en escrow
  
  Stage 4 FAILS:    $400 reste en escrow → ?
  
  Resolution options:
    a) Full retry workflow: $400 utilisé pour retry stage 4 (max 2x)
    b) Partial refund: $400 × 0.7 = $280 refunded, $120 → insurance pool
    c) Salvage mode: Client accepte le livrable partiel, 
       $400 × 0.5 = $200 refunded, $200 → partial payment agents stage 4
```

**L'insight critique :** Les agents des stages 1-3 **ne devraient pas être payés intégralement si le workflow échoue**. Proposition :

```
Agent payment = base_payment × 0.7 (released at stage completion)
              + success_bonus × 0.3 (released only if FULL workflow succeeds)

Stage 1 coder au stage completion: $250 × 0.7 = $175 released
Stage 1 coder at workflow success: $250 × 0.3 = $75 released
Stage 1 coder at workflow failure:  $75 → insurance pool (not returned to client)
```

Cela aligne les incentives : chaque agent a intérêt à produire un output qui facilite le succès des stages suivants (meilleur context passing, meilleure qualité), pas juste à passer son quality gate local.

### 3.4 🆕 Le matching d'agents pour un workflow est un problème combinatoire, pas unitaire

Un workflow GOLD nécessite 3 agents (coder, reviewer, tester) qui doivent être :
- Disponibles dans la même fenêtre temporelle (SLA 24h)
- Compétents sur le même stack technique
- **Non-collusifs** (un agent operator qui contrôle le coder ET le reviewer peut rubber-stamp ses propres reviews)

**Anti-collusion rule :** Pour un workflow de N stages, au maximum `floor(N/2)` stages peuvent être assignés à des agents du même operator. Pour un workflow GOLD (3 stages), max 1 stage par operator.

```
Workflow GOLD - code + review + test
  ✅ Valid:   Coder(OpA) → Reviewer(OpB) → Tester(OpC)
  ✅ Valid:   Coder(OpA) → Reviewer(OpB) → Tester(OpA)  // 2 stages OpA, mais non-adjacents
  ❌ Invalid: Coder(OpA) → Reviewer(OpA) → Tester(OpB)  // review du propre code
  ❌ Invalid: Coder(OpA) → Reviewer(OpA) → Tester(OpA)  // 3/3 même operator
```

**Rule spécifique :** Un agent du même operator ne peut JAMAIS occuper un stage d'exécution ET le stage de review/audit immédiatement suivant. C'est la contrainte dure. Le reste est soft (warning, pas blocking).

---

## 4. PRD Changes Required

### 4.1 `MASTER.md` — Section Architecture

| Section actuelle | Changement requis | Priorité |
|---|---|---|
| Smart Contract Architecture | Ajouter `WorkflowOrchestrator.sol` comme contrat principal exposé aux clients. `MissionEscrow.sol` reclassé comme contrat interne. | **P0** |
| Contract Interaction Diagram | Nouveau diagramme montrant le flow Client → WorkflowOrchestrator → MissionEscrow × N stages | **P0** |
| Escrow Flow | Réécrire complètement : budget progressif avec 70/30 split (immediate/completion bonus) | **P0** |

### 4.2 `MASTER.md` — Section Product

| Section actuelle | Changement requis | Priorité |
|---|---|---|
| User Journey | Réécrire autour du workflow, pas de la mission. Le client crée un workflow (choisit un tier), pas une mission. | **P0** |
| Pricing | Ajouter coordination_multiplier et tier_margin. Supprimer le pricing linéaire par mission. | **P0** |
| Tier Definitions | Formaliser les 4 tiers (BRONZE-PLATINUM) avec stages, QG thresholds, SLAs, budget ranges | **P1** |

### 4.3 `MASTER.md` — Nouvelles sections à créer

| Nouvelle section | Contenu | Priorité |
|---|---|---|
| Structured Stage Output Protocol (SSOP) | Spécification du format d'output inter-stage (artifacts, reasoning, decisions, open_questions, test_hints) | **P1** |
| Quality Gate Specification | Dual attestation model (40% agent / 60% automated), challenge window, dispute flow | **P0** |
| Coordinator Agent Spec | Rôle, responsabilités, fee structure, V1 (platform-operated) vs V2 (marketplace) | **P1** |
| Anti-Collusion Rules | Contraintes d'assignment par operator, adjacency rules | **P1** |
| Workflow Failure Modes | Taxonomy des failures, refund rules, salvage mode, insurance pool feeding | **P0** |

### 4.4 `WorkflowOrchestrator.sol` — Nouvelle spec technique

```solidity
// Interface minimale à spécifier dans le PRD
interface IWorkflowOrchestrator {
    // Lifecycle
    function createWorkflow(
        WorkflowTier tier,
        bytes32 specHash,         // IPFS hash de la spec client
        StageConfig[] stages,     // max 6
        uint256 totalBudget       // USDC, déposé à la création
    ) external returns (bytes32 workflowId);
    
    function advanceStage(
        bytes32 workflowId,
        bytes32 outputHash,       // IPFS hash du SSOP output
        QualityGateAttestation attestation
    ) external;
    
    function failStage(
        bytes32 workflowId,
        bytes32 reason
    ) external;
    
    function abortWorkflow(
        bytes32 workflowId
    ) external; // triggers partial refund
    
    // Views
    function getWorkflowState(bytes32 workflowId) external view returns (WorkflowState);
    function getStageState(bytes32 workflowId, uint8 stageIndex) external view returns (StageState);
    
    // Events
    event WorkflowCreated(bytes32 indexed workflowId, WorkflowTier tier, uint256 budget);
    event StageAdvanced(bytes32 indexed workflowId, uint8 stageIndex, uint8 score);
    event StageFailed(bytes32 indexed workflowId, uint8 stageIndex, uint8 retriesUsed);
    event WorkflowCompleted(bytes32 indexed workflowId, uint256 totalPaid);
    event WorkflowAborted(bytes32 indexed workflowId, uint256 refunded);
}
```

---

## 5. Implementation Priority

### Phase 1 : Fondations (Semaines 1-3)

```
Priority  Component                          Dependency    Est. Effort
────────────────────────────────────────────────────────────────────────
P0.1      WorkflowOrchestrator.sol            MissionEscrow  5 days
          └── State machine (create, advance, fail, abort)
          └── Budget split + progressive escrow
          └── 70/30 payment split logic
          
P0.2      Foundry tests for Orchestrator     P0.1           3 days
          └── Happy path: 4-stage workflow complete
          └── Failure path: stage fail + retry + abort
          └── Refund path: partial refund calculation
          └── Edge: max retries exceeded
          └── Edge: abort mid-workflow
          └── Target: 20+ tests, all green
          
P0.3      Quality Gate Attestation struct     P0.1           1 day
          └── On-chain: hash + score + signature + timestamp
          └── Verification: ecrecover agent signature
```

### Phase 2 : Off-chain orchestration (Semaines 3-5)

```
P1.1      SSOP Schema Definition             None           2 days
          └── JSON Schema for stage outputs
          └── Validation library (TypeScript)
          
P1.2      Coordinator Agent (V1)             P0.1, P1.1     5 days
          └── Spec decomposition (LLM-powered)
          └── Context adaptation between stages
          └── Retry/abort decision logic
          └── Calls WorkflowOrchestrator on-chain
          
P1.3      Automated Quality Checks           P1.1           3 days
          └── Compilation verification
          └── Test execution + pass rate
          └── Lint + coverage measurement
          └── Score computation (60% weight)
```

### Phase 3 : Tier templates + matching (Semaines 5-7)

```
P2.1      Tier Template Registry             P0.1           2 days
          └── BRONZE/SILVER/GOLD/PLATINUM configs
          └── Default stage configs per tier
          └── Budget range validation
          
P2.2      Anti-Collusion Matching            P2.1           3 days
          └── Operator adjacency constraints
          └── Availability window matching
          └── Stack compatibility filtering
          
P2.3      Pricing Engine                     P2.1           2 days
          └── coordination_multiplier calculation
          └── tier_margin application
          └── Dynamic pricing based on agent availability
```

### Phase 4 : Safety + Dispute (Semaines 7-9)

```
P3.1      Insurance Pool Contract            P0.1           3 days
          └── Fed by: 30% bonus forfeiture on failed workflows
          └── Fed by: partial refund delta ($400 × 0.3 on abort)
          └── Pays out: client compensation on platform-fault failures
          
P3.2      Dispute Flow (V1 - Admin)          P0.1           2 days
          └── Client challenges QG attestation
          └── Admin reviews (centralized V1)
          └── Resolution: override stage pass/fail
          
P3.3      E2E Integration Tests             All            3 days
          └── Full GOLD workflow: issue → code → review → test → payment
          └── Failure scenario: stage 3 fail → retry → abort → refund
          └── Dispute scenario: client challenges → admin overrides
```

---

## 6. Next Cycle Focus

### Question centrale du Cycle zj :

> **Comment le Coordinator Agent décompose-t-il une spec client en instructions per-stage, et comment évalue-t-on la qualité de cette décomposition ?**

C'est le problème le plus critique non résolu. Le Coordinator est le single point of failure du workflow entier. Si sa décomposition est mauvaise :
- Le coder reçoit des instructions ambiguës → mauvais code
- Le reviewer ne sait pas quoi vérifier → rubber-stamp
- Le tester ne sait pas quoi tester → faux positifs

**Sous-questions à traiter :**

1. **Decomposition protocol :** Quel format le Coordinator produit-il ? Comment garantir que chaque stage reçoit suffisamment de contexte sans information overload ?

2. **Coordinator accountability :** Si un workflow échoue parce que la décomposition était mauvaise (pas parce que les agents ont mal exécuté), qui paie ? Le Coordinator doit-il staker ?

3. **Coordinator selection :** En V1 c'est platform-operated, mais le design doit anticiper V2. Comment évalue-t-on la qualité d'un Coordinator ? Métrique : taux de succès des workflows qu'il orchestre ?

4. **Spec ambiguity detection :** Le Coordinator doit-il pouvoir rejeter une spec client comme "insuffisamment spécifiée" avant de créer le workflow ? Si oui, comment on-chain ?

5. **Feedback loop :** Quand un stage échoue, le Coordinator doit adapter les instructions du retry. Comment cette adaptation est-elle capturée et évaluée ?

---

## 7. Maturity Score

### Score global : **6.5 / 10**

| Dimension | Score | Justification |
|---|---|---|
| **Problem framing** | 9/10 | Le reframing "workflow is the product" est clair, différenciant, et validé. La proposition de valeur ("buy an audited outcome") est nette. |
| **Smart contract architecture** | 7/10 | `WorkflowOrchestrator` + `MissionEscrow` composition est saine. Le 70/30 payment split est innovant. Mais pas encore implémenté ni testé — le diable est dans les edge cases Solidity (reentrancy sur multi-stage, gas limits sur 6 stages). |
| **Quality Gate design** | 7/10 | Dual attestation (40/60) est le bon tradeoff. Challenge window + dispute flow sont esquissés. Manque : spécification précise des automated checks par type de stage (un security audit n'a pas les mêmes checks qu'un code stage). |
| **Economic model** | 6/10 | Le coordination_multiplier et le tier_margin sont posés. Le 70/30 split aligne les incentives. **Mais :** le modèle n'est pas backtesté. Les multipliers (1.25x pour 3 stages) sont des estimations. Il faut des simulations Monte Carlo sur les scénarios de failure cascade. |
| **Coordinator Agent** | 4/10 | Identifié comme critique, mais quasi-rien n'est spécifié. C'est le plus gros trou. Le workflow ne peut pas fonctionner sans un Coordinator compétent, et on n'a ni son architecture, ni sa spec, ni sa métrique de performance. |
| **Anti-collusion & matching** | 5/10 | Les rules d'adjacency sont posées. Mais le matching combinatoire (trouver N agents compatibles dans la même fenêtre) est un problème algorithmique non trivial qui n'est pas spécifié. Sur un marketplace naissant avec peu d'agents, il peut être impossible de satisfaire les contraintes anti-collusion pour un workflow PLATINUM. |
| **Failure modes & refund** | 7/10 | Le scénario "stage 3 fail on $1000 workflow" est bien identifié. Le salvage mode est une bonne idée. Manque : formalisation complète des refund rules par cas (qui paie quoi dans chaque scénario de failure). |
| **Implementation readiness** | 6/10 | Le plan est séquencé en 4 phases, les dépendances sont cl