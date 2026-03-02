

# Cycle zj — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le WorkflowCompiler comme composant off-chain dédié

**Validé.** C'est l'insight structurant du cycle. Le passage d'une intention client `(issue, budget, tier)` à un `WorkflowPlan` exécutable nécessite un composant explicite, pas une logique diffuse dans le backend.

**Justification :** Sans ce composant, la "compilation" se fait implicitement — soit le client compose manuellement son workflow (UX désastreuse), soit le matching engine fait de l'orchestration (violation de responsabilité unique). Le WorkflowCompiler isole la logique de planification et permet de la tester, versionner, et auditer indépendamment.

**Décision concrète :**
```
WorkflowCompiler.compile(issue_description, budget, tier) → WorkflowPlan {
  stages: Stage[],          // max 6, ordonnés
  budget_splits: uint[],    // pourcentages par stage, sum = 100
  quality_gates: QGConfig[],// threshold + type par gate
  agent_roles: Role[],      // rôles requis par stage
  plan_hash: bytes32        // keccak256 du plan entier
}
```

Le `plan_hash` est committé on-chain à la création du workflow. Toute déviation du plan = dispute légitime. **C'est le contrat de confiance.**

### 1.2 ✅ Pipeline séquentiel uniquement en V1, fan-out reporté à V1.5

**Validé.** L'argument décisif n'est pas technique (un sync barrier se code), c'est l'explosion combinatoire des chemins de dispute. Un fan-out `A → (B1 || B2) → C` produit 4 chemins de failure possibles au lieu de 1. En V1, chaque edge-case de dispute non géré = un client qui perd confiance dans l'escrow.

**Règle V1 :** Un workflow est une liste ordonnée `[Stage_1, Stage_2, ..., Stage_n]` avec `n ∈ [1,6]` et une unique transition `Stage_k → Stage_{k+1}`.

### 1.3 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Validé et renforcé.** C'est la bonne séparation. Le smart contract ne juge jamais la qualité — il enregistre des attestations et gère les disputes.

**Architecture concrète :**
```
┌─────────────────────────────────────────────────┐
│                   OFF-CHAIN                      │
│                                                  │
│  Agent Reviewer exécute QG check                 │
│  → Produit: rapport JSON + score [0-100]         │
│  → Signe: sign(hash(rapport), agent_private_key) │
│                                                  │
├─────────────────────────────────────────────────┤
│                   ON-CHAIN                       │
│                                                  │
│  QualityGateAttestation {                        │
│    workflow_id,                                  │
│    stage_index,                                  │
│    report_hash: bytes32,                         │
│    score: uint8,                                 │
│    reviewer: address,                            │
│    signature: bytes                              │
│  }                                               │
│                                                  │
│  Rule: score >= threshold → auto-advance         │
│  Rule: score < threshold → stage FAILED          │
│  Rule: client.challenge(attestation) → DISPUTED  │
└─────────────────────────────────────────────────┘
```

**Point critique ajouté :** Le reviewer ne peut PAS être le même agent que l'exécutant du stage. C'est une contrainte hard-coded dans le WorkflowOrchestrator : `require(reviewer != stage_agent)`. Sinon le modèle de confiance s'effondre.

### 1.4 ✅ Le budget tier comme contrat de niveau de confiance (pas un menu)

**Validé conceptuellement.** Un tier plus élevé n'achète pas "plus d'agents" — il achète un pipeline avec plus de quality gates, des seuils de passage plus exigeants, et donc une probabilité de rework plus basse.

**Mapping V1 concret :**

| Tier | Budget Range | Stages | Quality Gates | QG Threshold | Rework Probability |
|------|-------------|--------|---------------|-------------|-------------------|
| **Bronze** | $50–$200 | 2 (Code → Test) | 1 (automated) | 60/100 | ~30% |
| **Silver** | $200–$1000 | 3 (Code → Review → Test) | 2 (auto + peer) | 75/100 | ~15% |
| **Gold** | $1000–$5000 | 4–5 (Design → Code → Review → Security → Test) | 3–4 (auto + peer + security) | 85/100 | ~5% |

**Note :** Ces chiffres de probabilité sont des targets, pas des garanties. Ils serviront de baseline pour mesurer la performance réelle du marketplace une fois en production.

### 1.5 ✅ WorkflowOrchestrator compose MissionEscrow sans le modifier

**Re-validé** (décision du cycle zi, renforcée ici). Le pattern est :

```solidity
contract WorkflowOrchestrator {
    MissionEscrow public immutable missionEscrow;
    
    function advanceStage(uint workflowId) external {
        Workflow storage wf = workflows[workflowId];
        // Finalise la mission du stage courant
        missionEscrow.completeMission(wf.currentMissionId);
        // Crée la mission du stage suivant
        wf.currentStageIndex++;
        wf.currentMissionId = missionEscrow.createMission(
            wf.plan.stages[wf.currentStageIndex],
            wf.plan.budgetSplits[wf.currentStageIndex]
        );
    }
}
```

Les 14 tests Foundry existants restent la baseline. Tout nouveau test de WorkflowOrchestrator est **additif**.

---

## 2. Décisions Rejetées

### 2.1 ❌ WorkflowPlan déterministe calculé entièrement par le compiler

**Partiellement rejeté.** Le cycle propose que le WorkflowCompiler produit un plan "déterministe". Problème : le mot "déterministe" est trompeur ici. Deux inputs identiques `(issue, budget, tier)` ne devraient PAS forcément produire le même plan, parce que :

1. **L'offre d'agents varie** — le plan doit tenir compte des agents disponibles et de leur réputation actuelle
2. **L'issue est du texte libre** — le NLP/LLM qui interprète l'issue est intrinsèquement non-déterministe
3. **Le client peut avoir des préférences** — "je veux que l'agent X fasse le code review"

**Décision retenue à la place :** Le WorkflowCompiler produit un **plan proposé** que le client review et confirme. Le plan devient immutable une fois committé on-chain (le hash). Mais la génération n'est pas déterministe — c'est un **suggestion engine**, pas un compilateur au sens strict.

```
Flux réel :
1. Client soumet (issue, budget, tier_preference)
2. WorkflowCompiler génère plan_draft
3. Client review le plan (UI: voir stages, budget splits, agent roles)
4. Client confirme → createWorkflow(plan) on-chain → plan_hash immutable
5. Exécution suit le plan committé
```

**Pourquoi ça importe :** Si le plan est auto-généré sans confirmation client, tout échec sera blâmé sur le "mauvais plan". Le client doit avoir skin in the game sur le plan qu'il valide.

### 2.2 ❌ Budget split figé dans les tier templates

**Rejeté.** Le cycle propose des splits fixes (40/25/20/15). En réalité, le budget split dépend de la nature de l'issue :

- Un fix de bug → 60% Code, 10% Review, 30% Test (le test est critique)
- Une feature UI → 30% Design, 40% Code, 15% Review, 15% Test
- Un audit sécurité → 20% Code, 30% Review, 50% Security

**Décision retenue :** Le WorkflowCompiler propose un split basé sur l'analyse de l'issue + le tier choisi. Le client peut ajuster dans des bornes :
- Aucun stage ne peut avoir < 10% du budget (sinon l'agent n'a pas d'incentive)
- Aucun stage ne peut avoir > 60% du budget (sinon un point de failure concentre le risque)

```solidity
// Contraintes on-chain
require(budgetSplit[i] >= 1000, "Min 10% per stage"); // basis points
require(budgetSplit[i] <= 6000, "Max 60% per stage");
require(sum(budgetSplit) == 10000, "Must total 100%");
```

### 2.3 ❌ Conditional branching en V1 (Pattern 3 du cycle)

**Reporté à V2.** Le cycle mentionne un Pattern 3 "Conditional" mais n'en détaille pas la mécanique. J'écarte formellement ce pattern parce que :

1. **Les conditions vivent où ?** Si off-chain, le smart contract ne peut pas les vérifier. Si on-chain, il faut un oracle pour évaluer "est-ce que le code a > 80% coverage ?"
2. **Les branches conditionnelles cassent la prévisibilité du coût.** Le client ne sait plus combien il va payer.
3. **Le rework loop est le vrai besoin.** Ce que les gens veulent quand ils pensent "conditionnel", c'est : "si le QG échoue, renvoyer au stage précédent". C'est un retry, pas un branch.

**Ce qu'on implémente à la place en V1 :** Un mécanisme de **retry** :
```
Stage FAILED (QG score < threshold)
  → Client choisit: RETRY (même agent) | REASSIGN (nouvel agent) | ABORT (refund remaining)
  → Max 2 retries par stage
  → Retry ne coûte pas plus (l'escrow du stage est toujours locked)
  → 3ème failure → ABORT automatique
```

### 2.4 ❌ Plan hash comme seul mécanisme de binding

**Insuffisant.** Hasher le plan et le stocker on-chain c'est bien, mais insuffisant pour les disputes. Si le client dit "l'agent n'a pas suivi le plan", comment l'arbitre vérifie-t-il ?

**Décision retenue :** Le plan complet est stocké **off-chain sur IPFS** (ou Arweave pour la persistence). On-chain, on stocke :
```solidity
struct Workflow {
    bytes32 planHash;      // keccak256(plan JSON)
    string planURI;        // ipfs://Qm... 
    uint8 currentStage;
    WorkflowStatus status;
    // ... 
}
```

L'arbitre (humain en V1, Kleros en V2) peut pull le plan depuis IPFS, vérifier `keccak256(fetched_plan) == planHash`, et juger la dispute sur la base du plan validé par les deux parties.

---

## 3. Nouveaux Insights

### 3.1 🆕 Le "Compilation Gap" — le vrai risque produit

Le cycle révèle un gap fondamental non adressé précédemment : **la distance entre l'intention du client et le plan exécuté**. Ce gap est le risque #1 du produit.

```
Client intention: "Fix the login bug on mobile"
     ↓ [COMPILATION GAP] ← ici naissent 80% des disputes
WorkflowPlan: Stage1=Code(fix auth flow), Stage2=Review(peer), Stage3=Test(mobile e2e)
     ↓ 
Execution: Agent code → Agent review → Agent test
     ↓
Livrable: PR merged
```

Si le client voulait un fix visuel et que le compiler interprète "auth flow", le workflow entier est correct mais le livrable est mauvais. **Le bug n'est dans aucun composant — il est dans le gap.**

**Mitigation concrète :** Le WorkflowCompiler doit produire, pour chaque stage, un **acceptance criteria** en langage naturel que le client valide :
```json
{
  "stage": "Code",
  "acceptance_criteria": "PR that fixes login button not responding on iOS Safari. Must handle the touch event propagation issue described in #1234.",
  "definition_of_done": "Login works on iOS Safari 16+, no regression on Chrome mobile"
}
```

Ces critères sont inclus dans le plan hashé. L'agent les voit. Le reviewer les utilise comme grille d'évaluation. C'est le **contrat sémantique** du workflow.

### 3.2 🆕 Le reviewer comme rôle structurel, pas optionnel

La contrainte `reviewer != executor` a une conséquence business non triviale : **le marketplace doit toujours avoir un pool de reviewers disponibles**. Si on a 100 code agents et 2 review agents, le bottleneck n'est pas le code — c'est le review.

**Implication :** 
- Les tiers Bronze avec 0 peer review sont les seuls qui marchent en cold start
- Le Silver+ nécessite un pool de reviewers → le marketplace doit incentiviser ce rôle dès le début
- **Pricing insight :** les reviewers sont payés moins par mission mais ont un volume plus élevé et un risque plus bas (pas de rework loop pour eux). C'est le modèle "assurance qualité as a service"

### 3.3 🆕 Les tier boundaries ne sont pas des murs — c'est un gradient

La proposition de tiers Bronze/Silver/Gold avec des budget ranges fixes est trop rigide. En réalité :

- Un client avec $180 qui veut Gold quality → frustré par la limite arbitraire
- Un client avec $250 qui veut juste du code rapide sans review → forcé de payer du Silver inutile

**Insight :** Les tiers sont des **presets**, pas des contraintes. Le client peut :
1. Choisir un preset tier (80% des cas — simplicité UX)
2. Customiser le nombre de stages et les QG thresholds (20% — power users)

Le budget minimum par tier est une **recommandation** (warning UX), pas un hard block. Si un client veut un Gold pipeline à $150, il peut — mais le système warn : "Budget below recommended minimum. Agent acceptance rate may be low."

```
UI Flow:
┌──────────────────────────────────────────────┐
│ Budget: $500                                  │
│                                               │
│ ○ Bronze (2 stages, basic QG) — Recommended   │
│ ● Silver (3 stages, peer review) ← selected   │
│ ○ Gold (4-5 stages, security audit)            │
│ ○ Custom...                                   │
│                                               │
│ [Customize stages →]  [Confirm plan →]        │
└──────────────────────────────────────────────┘
```

### 3.4 🆕 Le WorkflowCompiler a besoin de feedback loop

Le compiler V1 est un rule-based engine (pas de ML). Mais même rule-based, il a besoin de s'améliorer. Comment ?

**Feedback signal :** Chaque workflow terminé produit un signal :
```
{
  workflow_id,
  plan_hash,
  tier,
  outcome: COMPLETED | ABORTED | DISPUTED,
  stages_retried: [stage_index],
  client_satisfaction: 1-5 (optionnel),
  total_duration,
  budget_used_vs_planned
}
```

Ce signal est stocké et utilisé pour ajuster :
- Les default budget splits (si le stage "Test" est toujours retried → augmenter son budget %)
- Les QG thresholds (si 90% des stages passent → threshold trop bas, augmenter)
- Les tier recommendations (si Gold workflows sur issues simples ont 0% rework → recommander Silver pour économiser)

**V1 :** Le feedback est collecté mais les ajustements sont manuels (équipe ops).
**V2 :** Le WorkflowCompiler apprend des outcomes pour optimiser les plans.

---

## 4. PRD Changes Required

### 4.1 Nouvelle section : `WorkflowCompiler` (Section 6 de MASTER.md)

**Ajouter une section complète décrivant :**
- Input/Output du compiler
- Les 3 tier presets avec leurs stage templates
- Le flux client : suggestion → review → confirmation → commit on-chain
- Les contraintes de budget split (min 10%, max 60% par stage)
- Le stockage du plan (IPFS + hash on-chain)

### 4.2 Mise à jour : Smart Contract Architecture (Section 4)

**Modifier pour refléter :**
```
Contracts V1:
├── MissionEscrow.sol (inchangé, 323 lignes, 14 tests)
├── WorkflowOrchestrator.sol (NOUVEAU)
│   ├── createWorkflow(planHash, planURI, stages[], budgetSplits[])
│   ├── advanceStage(workflowId, attestation)
│   ├── retryStage(workflowId, retryType)  // RETRY | REASSIGN
│   ├── abortWorkflow(workflowId)
│   └── disputeStage(workflowId, stageIndex)
└── AgentRegistry.sol (EXISTANT, ajouter role field)
```

- Ajouter les contraintes formelles du budget split
- Ajouter l'enum `RetryType { SAME_AGENT, NEW_AGENT }`
- Ajouter le max retry count = 2

### 4.3 Mise à jour : Quality Gate System (Section 5)

**Réécrire pour clarifier :**
- QG = attestation off-chain + commitment on-chain (pas de jugement on-chain)
- Structure `QualityGateAttestation` avec report_hash, score, reviewer, signature
- Contrainte hard : `reviewer != stage_executor`
- Flow : auto-advance si score ≥ threshold, FAILED sinon
- Le client peut challenger une attestation → DISPUTED

### 4.4 Mise à jour : User Flows (Section 3)

**Ajouter le flow complet du client :**
```
1. Client crée une issue GitHub
2. Client arrive sur la plateforme, connecte GitHub, sélectionne l'issue
3. Client entre son budget et choisit un tier (ou custom)
4. WorkflowCompiler génère un plan draft
5. Client review les stages, acceptance criteria, budget splits
6. Client ajuste si nécessaire (dans les bornes)
7. Client confirme → tx on-chain : createWorkflow() + deposit USDC
8. Matching commence pour Stage 1
9. ... exécution ...
10. Workflow COMPLETED → dernière release d'escrow
```

### 4.5 Nouvelle section : Retry & Abort Mechanics (Section 6.2)

**Documenter :**
- Stage FAILED → 3 options (retry same, reassign, abort)
- Max 2 retries par stage, 3ème failure = auto-abort
- En cas d'abort : stages complétés = payés, stage courant = refund au client, stages futurs = refund au client
- En cas de retry : l'escrow du stage reste locked, pas de coût additionnel
- Timeline : client a 48h pour décider retry/reassign/abort, sinon auto-abort

### 4.6 Ajout : Acceptance Criteria comme artefact du plan

**Ajouter dans la spec du WorkflowPlan :**
- Chaque stage a un `acceptance_criteria: string` et un `definition_of_done: string`
- Ces champs sont inclus dans le plan hashé
- Ils sont visibles par l'agent exécutant ET le reviewer
- Ils servent de grille d'évaluation pour le QG

---

## 5. Implementation Priority

### Phase 1 : Smart Contract Layer (Semaines 1-3)

```
Priority 1: WorkflowOrchestrator.sol
├── createWorkflow() avec planHash, stages, budgetSplits
├── advanceStage() avec vérification QG attestation
├── retryStage() avec compteur et types
├── abortWorkflow() avec refund logic
├── Contraintes: budgetSplit bounds, max stages, reviewer ≠ executor
├── Tests Foundry: ~25 tests (create, advance, retry, abort, edge cases)
└── Estimation: 400-500 lignes

Priority 2: Intégration MissionEscrow ↔ WorkflowOrchestrator
├── WorkflowOrchestrator appelle MissionEscrow.createMission() par stage
├── Test d'intégration: workflow de 3 stages bout en bout
├── Test de non-régression: les 14 tests MissionEscrow passent toujours
└── Estimation: 100 lignes + 10 tests
```

### Phase 2 : WorkflowCompiler Off-Chain (Semaines 3-5)

```
Priority 3: WorkflowCompiler service
├── Rule-based engine V1 (pas de ML)
├── Input: (issue_description, budget, tier)
├── Output: WorkflowPlan JSON + planHash
├── Tier preset templates (Bronze, Silver, Gold)
├── Budget split calculator avec bornes
├── Acceptance criteria generator (template-based V1, LLM-assisted V1.5)
├── IPFS upload du plan
└── Estimation: ~800 lignes Python/TypeScript

Priority 4: Plan Review UI
├── Affichage du plan proposé (stages, splits, criteria)
├── Slider pour ajuster budget splits (dans les bornes)
├── Confirmation → tx on-chain
└── Estimation: ~500 lignes frontend
```

### Phase 3 : Quality Gate Infra (Semaines 5-7)

```
Priority 5: QG Attestation Pipeline
├── Agent reviewer exécute QG check
├── Rapport generation + hashing
├── Signature + submission on-chain
├── Auto-advance / fail logic
└── Estimation: ~600 lignes (off-chain + contract interaction)

Priority 6: Retry / Abort Flow
├── UI pour retry/reassign/abort decision
├── 48h timeout auto-abort
├── Refund calculation pour partial workflows
└── Estimation: ~400 lignes total
```

### Phase 4 : Feedback & Iteration (Semaines 7-8)

```
Priority 7: Workflow outcome tracking
├── Event emission sur completion/abort/dispute
├── Outcome storage (off-chain DB)
├── Basic dashboard pour ops
└── Estimation: ~300 lignes
```

---

## 6. Next Cycle Focus

### Question centrale du Cycle zk :

> **Comment le matching engine assigne-t-il les agents aux stages d'un workflow, et comment gère-t-on la dépendance inter-stages ?**

Justification : Le WorkflowCompiler produit un plan avec des *rôles* (`code_agent`, `review_agent`, `security_agent`). Mais le plan ne contient pas des agents spécifiques. Le matching doit résoudre :

1. **Timing :** Est-ce qu'on matche tous les agents upfront (risque de lock-in) ou stage-by-stage (risque de latence inter-stage) ?
2. **Context propagation :** L'agent du stage 2 a besoin du contexte du stage 1. Comment transmet-on le contexte sans exploser les coûts ? Le reviewer doit-il lire tout le code produit ou juste un diff ?
3. **Agent commitment :** Si un agent accepte stage 1, est-il engagé pour les stages suivants ? Peut-il refuser stage 3 après avoir fait stage 1 ?
4. **Reputation impact :** Comment un stage retry affecte la réputation de l'agent ? Un retry devrait-il peser plus qu'un failure outright (l'agent a au moins essayé) ?
5. **Cold start du pool de reviewers :** Comment bootstrap-on un pool de review agents quand le marketplace démarre ?

Ce sont les questions qui, si mal résolues, rendent le tier system inutile — un pipeline parfait sans agents pour le stafffer est un pipeline vide.

---

## 7. Maturity Score

### Score : 6.5 / 10

**Justification détaillée :**

| Dimension | Score | Commentaire |
|-----------|-------|-------------|
| Smart Contract Design | 7/10 | `WorkflowOrchestrator` + `MissionEscrow` composition est claire. Les contraintes (budget bounds, retry, abort) sont spécifiées. Il manque le détail des edge cases (que se passe-t-il si l'agent reviewer disparaît mid-workflow ?). |
| Off-Chain Architecture | 6/10 | Le WorkflowCompiler est conceptuellement solide mais pas encore prototypé. Le rule-based engine V1 est pragmatique mais les règles exactes ne sont pas écrites. L'acceptance criteria generator est flou. |
| Economic Model | 5/10 | Les tiers existent mais les pricing réels manquent. Combien coûte un review agent ? Le 10-60% bound est arbitraire — pourquoi pas 15-50% ? Il faut du market testing. |
| UX Flow | 7/10 | Le flow client est complet (issue → tier → review plan → confirm → execute). Mais le flow agent (comment il voit le plan, comment il accepte/refuse un stage) n'est pas détaillé. |
| Dispute Resolution | 4/10 | L'attestation off-chain + hash on-chain est le bon pattern, mais le flow de dispute réel est vague. "Arbitrage V2 via Kleros" ne suffit pas — que fait-on en V1 quand il y a dispute ? Qui tranche ? |
| Testability | 8/10 | La stratégie de tests est claire : 14 existants comme baseline, ~25 nouveaux pour Orchestrator, intégration tests. Foundry est le bon outil. |
| Risques identifiés | 6/10 | Le "Compilation Gap" est un excellent insight. Le bottleneck reviewer est identifié. Mais d'autres risques ne sont pas adressés : DoS sur le compiler, griefing (client qui retry indéfiniment pour bloquer l'escrow des agents), sybil attacks sur les reviewers. |

**Pourquoi pas 7+ :**
Le système est architecturalement sain mais trois zones restent under-specified :
1. **Dispute resolution V1** — "manual arbitration" n'est pas une spec, c'est un placeholder
2. **Agent-side UX** — on sait comment le client interagit, pas comment l'agent voit/accepte/livre
3. **Le matching engine pour les workflows** — c'est le next cycle mais c'est un dependency bloquant

**Pour atteindre 8/10, il faut :**
- Spécifier le dispute resolution V1 concrètement (qui, quand, comment, SLA)
- Détailler le flow agent pour les workflows multi-stage
- Prototyper le WorkflowCompiler avec 3 issues réelles pour valider les tier templates
- Résoudre le matching inter-stage (cycle zk)