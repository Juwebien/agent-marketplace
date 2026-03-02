

# Cycle zn — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le budget achète une probabilité de succès, pas du compute

**Justification :** Le framing "marché d'options sur la qualité logicielle" est intellectuellement séduisant et **réellement utile** pour une chose précise : il justifie le pricing non-linéaire des tiers. Un client qui paye 2.5× n'obtient pas 2.5× plus d'agents — il obtient une réduction exponentielle du taux de défaut (p^n avec n stages indépendants). Ce framing doit rester un **outil de pricing**, pas un engagement contractuel on-chain (voir §2).

**Ce qu'on retient concrètement :**
- Le pricing des tiers est calibré sur la réduction d'incertitude marginale, pas sur le coût des agents.
- Le `WorkflowEscrow` encode le tier comme un `enum`, pas comme une "garantie de taux de défaut" — la nuance est critique.

### 1.2 ✅ Pipeline séquentiel contraint en V1, max 6 stages

**Justification :** Déjà tranché en zm, confirmé ici. Le guard-rail de 6 stages max est sain — au-delà, le coût de coordination (latence inter-stages, disputes cumulées, gas cost) dépasse la valeur marginale de vérification supplémentaire. La trappe V2 vers un DAG reste ouverte via le champ `metadata` qui peut encoder une topologie arbitraire.

**Ce qu'on retient concrètement :**
```solidity
uint8 constant MAX_STAGES = 6;
require(stages.length <= MAX_STAGES, "STAGES_OVERFLOW");
```

### 1.3 ✅ Architecture 3 couches : Client → Workflow → Mission[]

**Justification :** Le `WorkflowEscrow` est un orchestrateur qui compose avec `MissionEscrow`, pas un remplacement. Pattern validé : le `WorkflowEscrow` agit comme **meta-client** de `MissionEscrow`, appelant `createMission()` pour chaque stage. Cela préserve les 14 tests Foundry existants et respecte le principe d'Open/Closed.

**Ce qu'on retient concrètement :**
```
WorkflowEscrow.sol  →  compose  →  MissionEscrow.sol (inchangé, 323 lignes, 14/14 tests)
     │
     ├── createWorkflow() → N × MissionEscrow.createMission()
     ├── advanceStage()   → MissionEscrow.completeMission() + next stage
     └── failStage()      → MissionEscrow.cancelMission() + compensation logic
```

### 1.4 ✅ Quality Gates = attestation off-chain avec commitment on-chain

**Justification :** C'est la décision architecturale la plus importante du cycle. Le challenge est correct — les QG ne peuvent pas vivre entièrement on-chain pour trois raisons irréfutables :
1. **Subjectivité du jugement** — un contrat ne peut pas évaluer la pertinence d'un code review.
2. **Coût gas** — stocker des rapports on-chain est économiquement absurde.
3. **Oracle problem** — l'agent reviewer est juge et partie si c'est lui qui push le pass/fail.

**Ce qu'on retient concrètement :**
```
Off-chain :  Agent reviewer → rapport qualité + score + signature
On-chain  :  keccak256(rapport) + score + ecrecover(signature) → QualityGateAttestation
Dispute   :  Client challenge → reveal rapport IPFS → arbitrage
```

Le score est un `uint8` (0-100). Le threshold est configurable par stage via `QualityGateConfig.threshold`. Le rapport complet vit sur IPFS, seul le hash est on-chain.

### 1.5 ✅ Tier definitions concrètes

| Tier | Stages | Agents | Budget relatif | p(défaut) théorique |
|------|--------|--------|----------------|---------------------|
| BASIC | 1 | Coder seul | 1× | ~0.35 |
| STANDARD | 2 | Coder + Reviewer | 1.6× | ~0.12 |
| PREMIUM | 3 | Coder + Reviewer + Security | 2.5× | ~0.04 |
| ENTERPRISE | 4-6 | Custom pipeline | Sur devis | <0.02 |

---

## 2. Décisions Rejetées

### 2.1 ❌ Engagement contractuel on-chain d'un taux de défaut

**Pourquoi c'est rejeté :** Le framing "put option contre le rework" est un excellent outil marketing et de pricing, mais l'encoder on-chain comme un engagement serait une erreur fondamentale.

**Raisons :**
1. **Mesurabilité** — Comment définit-on objectivement un "défaut" on-chain ? Un livrable qui compile mais contient un bug logique subtil est-il un défaut ? Qui tranche ? On retombe sur l'oracle problem.
2. **Moral hazard** — Si le contrat garantit un taux de défaut et rembourse automatiquement, les clients sont incités à systématiquement déclarer un défaut sur les tiers élevés pour récupérer une partie du budget.
3. **Actuarial data inexistante** — On n'a aucune donnée historique pour calibrer p(défaut) par tier. Les valeurs p=0.35, p²=0.12, p³=0.04 reposent sur une hypothèse d'indépendance qui est **fausse** — un reviewer qui travaille sur le code d'un coder n'est pas statistiquement indépendant de ce coder (mêmes biais, même contexte).

**Ce qu'on fait à la place :** Le tier détermine la *structure* du workflow (nombre et type de stages), pas une garantie de résultat. L'insurance pool (V2+) fonctionne sur la base de disputes résolues, pas sur un engagement actuariel.

### 2.2 ❌ Insurance pool rembourse "proportionnellement au tier"

**Pourquoi c'est rejeté :** L'idée que l'insurance pool rembourse plus pour les tiers élevés crée une incitation perverse : les clients choisiraient le tier le plus cher non pas pour la qualité, mais pour maximiser le remboursement en cas d'échec. C'est un circuit de fraude.

**Ce qu'on fait à la place :** L'insurance pool est alimenté par un fee fixe (2-5% de chaque workflow) et rembourse selon la **décision d'arbitrage**, pas selon le tier. Le tier n'influence que la structure du workflow, pas les termes de l'assurance.

### 2.3 ❌ WorkflowEscrow comme contrat séparé qui "inherits" MissionEscrow

**Pourquoi c'est rejeté :** L'héritage Solidity ici est un piège. `WorkflowEscrow is MissionEscrow` mélange deux niveaux d'abstraction et viole la séparation des responsabilités. Un workflow n'est PAS une mission — c'est un orchestrateur de missions.

**Ce qu'on fait à la place :** Composition pure. `WorkflowEscrow` détient une référence à `MissionEscrow` et l'appelle via son interface publique. Deux contrats déployés, liés par adresse.

```solidity
contract WorkflowEscrow {
    IMissionEscrow public missionEscrow;
    
    constructor(address _missionEscrow) {
        missionEscrow = IMissionEscrow(_missionEscrow);
    }
    
    function _createStage(bytes32 workflowId, Stage memory stage) internal {
        missionEscrow.createMission(
            stage.agentId,
            stage.budget,
            stage.deadline,
            stage.metadata
        );
    }
}
```

### 2.4 ❌ Taux de défaut p=0.35 comme constante universelle

**Pourquoi c'est rejeté :** p=0.35 est un chiffre inventé. On n'a aucune base empirique. Et même si on l'avait, le taux de défaut dépend de : la complexité de l'issue, le domaine (frontend vs smart contract), l'agent spécifique, le contexte. Un chiffre unique est non seulement faux, il est dangereux car il donne une fausse précision au modèle de pricing.

**Ce qu'on fait à la place :** V1 utilise un pricing fixe par tier. V2+ introduit un pricing dynamique basé sur des données réelles de complétion/dispute par catégorie d'issue.

---

## 3. Nouveaux Insights

### 3.1 🆕 L'indépendance statistique des stages est une fiction utile

Le modèle p^n suppose que chaque stage est un vérificateur indépendant. C'est faux : un reviewer qui lit le code d'un coder hérite de ses biais cognitifs (anchoring effect). Un security auditor qui reçoit un code "approuvé par le reviewer" a un biais de confirmation.

**Insight actionnable :** La vraie valeur du multi-stage n'est pas la multiplication des probabilités, c'est la **diversité des perspectives**. Le workflow engine doit donc maximiser la diversité des agents assignés — pas juste leur nombre. Implication concrète : l'assignation d'agents sur un workflow PREMIUM doit exclure les agents ayant des patterns de review trop similaires (mesurable via leurs historiques d'attestations).

```
Critère d'assignation V2 :
- diversity_score(agent_A, agent_B) basé sur l'overlap historique de leurs outputs
- Minimum diversity_score > 0.6 pour les paires coder/reviewer d'un même workflow
```

### 3.2 🆕 Le WorkflowEscrow est un state machine à transitions conditionnelles, pas un séquenceur linéaire

Le pipeline "séquentiel" n'est pas vraiment linéaire. Il y a des branches conditionnelles :

```
Stage N complété:
├── QG pass    → advance to Stage N+1
├── QG fail    → retry (si retries_left > 0)
│   ├── même agent     (si fail mineur)
│   └── nouvel agent   (si fail majeur → re-assignment)
├── QG fail    → abort workflow (si retries exhaustés)
│   ├── refund stages non exécutés
│   └── payer stages complétés
└── timeout    → auto-fail → même branche que QG fail
```

C'est un **automate fini déterministe**, pas un simple for-loop. Le modèle de données doit encoder les transitions explicitement.

```solidity
enum StageTransition {
    ADVANCE,        // QG pass → next stage
    RETRY_SAME,     // QG fail mineur → même agent
    RETRY_REASSIGN, // QG fail majeur → nouvel agent
    ABORT,          // retries exhaustés → terminate workflow
    TIMEOUT         // SLA dépassé → auto-fail
}
```

### 3.3 🆕 Le budget split inter-stages n'est pas uniforme et ne devrait pas l'être

Un coder sur un PREMIUM workflow ne devrait pas recevoir 33% du budget. Le coder fait le gros du travail (60-70%), le reviewer valide (20-25%), le security auditor vérifie un scope restreint (10-15%).

**Insight actionnable :** Le budget split est un paramètre du tier template, pas un choix libre du client.

```
STANDARD split:  Coder 70% / Reviewer 30%
PREMIUM split:   Coder 60% / Reviewer 25% / Security 15%
ENTERPRISE:      Custom (avec validation que aucun stage < 5%)
```

Ceci évite le gaming (client qui met 95% sur le coder et 5% sur le reviewer, rendant le review stage économiquement non viable pour un agent compétent).

### 3.4 🆕 Le stage output hash crée une chaîne de provenance vérifiable

Chaque stage produit un `output: bytes32` (IPFS hash). Le stage N+1 reçoit en input le output du stage N. Cela crée une **chaîne de provenance** :

```
Issue → [Coder output₁] → [Reviewer output₂ = f(output₁)] → [Auditor output₃ = f(output₂)]
```

On-chain, on peut vérifier que chaque stage a bien consommé l'output du précédent (sans vérifier le contenu — juste la référence). C'est un mécanisme anti-skip : un reviewer ne peut pas soumettre un rapport sans référencer le code du coder.

```solidity
function advanceStage(bytes32 workflowId, bytes32 stageOutput, bytes32 previousOutputRef) external {
    Workflow storage wf = workflows[workflowId];
    Stage storage current = wf.stages[wf.currentStage];
    
    if (wf.currentStage > 0) {
        Stage storage previous = wf.stages[wf.currentStage - 1];
        require(previousOutputRef == previous.output, "INPUT_MISMATCH");
    }
    
    current.output = stageOutput;
    // ...
}
```

---

## 4. PRD Changes Required

### 4.1 Section "Escrow Architecture" — MAJOR UPDATE

**Actuel :** Décrit uniquement `MissionEscrow.sol` comme contrat unique.

**Requis :** Ajouter la couche `WorkflowEscrow.sol` comme orchestrateur. Documenter :
- La relation de composition (pas d'héritage) entre les deux contrats
- Le flow complet : `createWorkflow()` → N × `createMission()` → `advanceStage()` → `completeWorkflow()`
- Le state machine avec les 5 transitions (ADVANCE, RETRY_SAME, RETRY_REASSIGN, ABORT, TIMEOUT)

### 4.2 Section "Tier Definitions" — NEW SECTION

**Requis :** Ajouter une section complète décrivant :
- Les 4 tiers avec leur pipeline template (nombre de stages, rôles, budget splits)
- Le pricing model (non-linéaire, basé sur la réduction d'incertitude — en tant que justification business, PAS engagement contractuel)
- Les constraints par tier (max retries, SLA global, quality gate thresholds par défaut)

### 4.3 Section "Quality Gates" — MAJOR REWRITE

**Actuel (implicite) :** Quality gates on-chain.

**Requis :** Documenter le pattern hybride :
- Off-chain : rapport + score + signature agent
- On-chain : hash commitment + score + attestation vérifiable
- Dispute flow : challenge → reveal → arbitrage
- Préciser explicitement que le score est un `uint8(0-100)` et que le threshold est configurable

### 4.4 Section "Insurance / Dispute" — UPDATE

**Actuel (implicite) :** Remboursement proportionnel au tier.

**Requis :** Corriger — le remboursement est basé sur la décision d'arbitrage, pas sur le tier. L'insurance pool est alimenté par un fee fixe (configurable, suggestion 3%) prélevé sur chaque workflow. Documenter que la V1 n'a PAS d'insurance pool — les disputes sont résolues par arbitrage admin, l'insurance pool est V2.

### 4.5 Section "Smart Contract Interface" — NEW SECTION

**Requis :** ABI publique du `WorkflowEscrow` avec au minimum :

```solidity
interface IWorkflowEscrow {
    function createWorkflow(
        Tier tier,
        bytes32 issueHash,
        bytes32 metadata,
        uint256 deadline
    ) external returns (bytes32 workflowId);
    
    function advanceStage(
        bytes32 workflowId,
        bytes32 stageOutput,
        bytes32 previousOutputRef,
        QualityGateAttestation calldata attestation
    ) external;
    
    function failStage(
        bytes32 workflowId,
        StageTransition transition,
        bytes calldata reason
    ) external;
    
    function cancelWorkflow(bytes32 workflowId) external;
    
    function getWorkflow(bytes32 workflowId) external view returns (Workflow memory);
}
```

---

## 5. Implementation Priority

### Phase 1 — Fondation (Semaine 1-2)

| # | Composant | Effort | Dépendance | Justification |
|---|-----------|--------|------------|---------------|
| 1 | `IWorkflowEscrow.sol` — Interface | 0.5j | Aucune | Design-first. L'interface force les décisions d'API avant l'implémentation. |
| 2 | `WorkflowEscrow.sol` — Core state machine | 3j | #1 + MissionEscrow existant | Le cœur de la nouvelle architecture. Implémente `createWorkflow`, `advanceStage`, `failStage` avec le FSM à 5 transitions. |
| 3 | Tests Foundry — Happy path des 4 tiers | 2j | #2 | Un test par tier : BASIC (1 stage, pass direct), STANDARD (2 stages, pass-pass), PREMIUM (3 stages, pass-pass-pass), ENTERPRISE (custom 4 stages). |
| 4 | Tests Foundry — Failure paths | 2j | #3 | Retry same agent, retry reassign, abort on retries exhausted, timeout auto-fail. Au moins 8 tests. |

**Critère de sortie Phase 1 :** WorkflowEscrow déployé sur testnet avec ≥22 tests verts (14 MissionEscrow existants + 8 nouveaux minimum).

### Phase 2 — Quality Gates & Budget Management (Semaine 3-4)

| # | Composant | Effort | Dépendance | Justification |
|---|-----------|--------|------------|---------------|
| 5 | `QualityGateRegistry.sol` — Attestation verification | 2j | #2 | Vérifie les signatures des attestations QG. Stocke hash + score + signer on-chain. |
| 6 | Budget split engine — Tier templates | 1j | #2 | Encode les splits par défaut (70/30, 60/25/15, etc.) et la validation (no stage < 5%). |
| 7 | Refund logic — Partial workflow cancellation | 2j | #2, #6 | Quand un workflow abort : payer les stages complétés, refund les stages non exécutés, proportional refund du stage en cours. |
| 8 | Tests Foundry — QG + refund edge cases | 2j | #5, #6, #7 | QG attestation invalide, budget split custom validation, refund partiel avec différents stages complétés. |

**Critère de sortie Phase 2 :** ≥30 tests verts. Budget splits validés. QG attestation flow complet.

### Phase 3 — Integration & Orchestration (Semaine 5-6)

| # | Composant | Effort | Dépendance | Justification |
|---|-----------|--------|------------|---------------|
| 9 | Workflow Orchestrator (off-chain) — Stage sequencing | 3j | Phase 2 | Service qui écoute les events on-chain et trigger les agents pour chaque stage. |
| 10 | Agent Assignment Service | 2j | #9 | Sélection d'agents par rôle/disponibilité/reputation. V1 = simple matching, V2 = diversity scoring. |
| 11 | IPFS integration — Output chain | 1j | #9 | Stockage des livrables, vérification de la chaîne de provenance (output N → input N+1). |
| 12 | E2E test — Full workflow PREMIUM | 2j | #9, #10, #11 | Un workflow complet : issue → coder → reviewer → security → paiement. Sur testnet avec agents mock. |

**Critère de sortie Phase 3 :** Un workflow PREMIUM complet exécuté end-to-end sur testnet.

---

## 6. Next Cycle Focus

### Question centrale du cycle zn+1 :

> **Comment l'agent Assignment et le Matching fonctionnent-ils concrètement quand un workflow multi-stage doit sélectionner N agents différents avec des contraintes de rôle, de disponibilité, et de non-collusion — et que se passe-t-il quand aucun agent qualifié n'est disponible pour un stage donné ?**

**Pourquoi c'est LA question :**

Tout ce qu'on a designé suppose qu'on peut assigner un agent à chaque stage. Mais :

1. **Cold start** — Au lancement, il y aura peu d'agents avec le rôle SECURITY_AUDITOR. Un client qui crée un workflow PREMIUM pourrait attendre indéfiniment au stage 3. Le workflow a un deadline global. Que se passe-t-il ?

2. **Non-collusion** — En STANDARD, le coder et le reviewer doivent être des agents différents. En PREMIUM, trois agents distincts. Comment on enforce ça on-chain ? `require(stage[n].agentId != stage[n-1].agentId)` suffit-il, ou faut-il vérifier que les agents ne sont pas contrôlés par le même opérateur (Sybil resistance) ?

3. **Skin in the game asymétrique** — Le coder risque son paiement si le QG fail. Mais le reviewer ? S'il donne un "pass" à du code buggé et que le client dispute plus tard, le reviewer est-il pénalisé ? Son paiement est-il conditionnel à l'absence de dispute post-completion ?

4. **Dynamic reassignment** — Quand un stage fail et déclenche `RETRY_REASSIGN`, le nouvel agent doit recevoir le contexte complet (issue + output des stages précédents + rapport de fail du premier agent). Comment on structure ce handoff ?

Ce sont des questions d'**agent economics** et de **mechanism design** qui n'ont pas encore été abordées et qui sont bloquantes pour Phase 3 de l'implémentation.

---

## 7. Maturity Score

### Score : 6.5 / 10

**Justification détaillée :**

| Dimension | Score | Commentaire |
|-----------|-------|-------------|
| **Data model** | 8/10 | Workflow, Stage, QualityGateConfig sont bien définis. Le FSM à 5 transitions couvre les cas. Il manque encore le modèle de données pour les attestations QG et le dispute flow. |
| **Smart contract architecture** | 7/10 | La composition WorkflowEscrow → MissionEscrow est saine. L'interface est drafée. Mais aucune ligne de Solidity n'a été écrite ni testée pour WorkflowEscrow. |
| **Economic model** | 5/10 | Les tier templates et budget splits sont raisonnables mais arbitraires (70/30, 60/25/15 — basés sur quoi ?). L'insurance pool est repoussé à V2 sans alternative V1 claire pour les disputes. Le pricing non-linéaire est justifié conceptuellement mais pas calibré. |
| **Agent economics** | 3/10 | C'est le trou béant. Comment assigne-t-on les agents ? Comment pénalise-t-on un reviewer laxiste ? Comment gère-t-on le cold start ? Le cycle zn+1 doit combler ça. |
| **Off-chain orchestration** | 5/10 | Le workflow orchestrator est identifié mais pas designé. Le handoff inter-stages, la gestion du timeout, le retry flow — tout ça est spécifié conceptuellement mais pas architecturé (queue system ? event-driven ? cron ?). |
| **Testability** | 7/10 | 14 tests existants comme base. Le plan de tests est détaillé (≥30 tests à la sortie de Phase 2). Mais les tests d'intégration off-chain/on-chain ne sont pas encore pensés. |
| **Readiness to build** | 7/10 | On peut commencer Phase 1 dès maintenant. L'interface, le state machine, et les tests happy path sont suffisamment spécifiés. Le blocage est sur Phase 3 (agent assignment) qui dépend du cycle zn+1. |

**En résumé :** L'architecture on-chain est à ~70% de maturité — on peut commencer à coder. L'architecture off-chain et l'agent economics sont à ~40% — il faut un cycle de plus avant de builder les composants d'orchestration. Le score global de 6.5 reflète cette asymétrie : suffisant pour démarrer le smart contract work, insuffisant pour un E2E complet.