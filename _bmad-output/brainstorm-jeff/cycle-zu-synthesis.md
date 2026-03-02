

# Cycle zu — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le contrat est un Finite State Machine financier, pas un workflow engine

**Justification :** C'est la décision architecturale la plus structurante du cycle et elle est correcte. Le `WorkflowEscrow.sol` ne gère que :
- Les transitions d'état entre stages (`PENDING → ACTIVE → PASSED/FAILED`)
- Les verrous financiers (lock/release/refund par stage)
- Les commitments (hashes d'attestations)

L'orchestration (sélection d'agent, routing d'artefacts, évaluation de seuils, retry logic) vit dans un **Workflow Orchestrator off-chain** (service TypeScript). C'est la seule approche viable pour trois raisons :
1. **Gas** — un workflow engine on-chain avec conditional branching explose les coûts sur Base (même L2)
2. **Upgradability** — modifier la logique d'orchestration ne nécessite pas de redéployer un contrat
3. **Expressivité** — les workflows conditionnels (Pattern 3) nécessitent une logique que Solidity rend atrocement coûteuse à maintenir

**Risque identifié qu'il faut adresser :** L'Orchestrator off-chain devient un **single point of failure et de trust**. Si c'est lui seul qui appelle `activateStage()` et `submitGateAttestation()`, il a un pouvoir discrétionnaire immense. Mitigation retenue :
- L'Orchestrator signe chaque action avec une clé dédiée enregistrée on-chain (`setOrchestrator(address)`)
- Chaque appel porte un **nonce + timestamp** vérifiable
- Le client garde un **emergency veto** : `clientHaltWorkflow(workflowId)` qui freeze l'escrow
- Les attestations sont **co-signées** par l'agent ET l'orchestrateur (2-of-2 minimum)

---

### 1.2 ✅ WorkflowEscrow compose MissionEscrow, ne le remplace pas

**Justification :** Les 14 tests Foundry verts sur `MissionEscrow.sol` (323 lignes) représentent un actif de confiance. Le pattern retenu :

```
WorkflowEscrow.sol
  └── Pour chaque stage: appelle MissionEscrow.createMission()
  └── Agit comme "meta-client" vis-à-vis de MissionEscrow
  └── Gère la logique inter-stages (séquençage, budget split, gate checks)
```

Le `WorkflowEscrow` est le **seul appelant autorisé** de `MissionEscrow` pour les missions workflow (distinction via un `isWorkflowManaged` flag). Les missions standalone continuent d'exister pour les cas mono-stage.

**Challenge que je pose :** Cette composition crée une indirection qui a un coût gas non-négligeable. Chaque `createMission()` interne coûte ~150-200k gas. Pour un workflow Gold à 5 stages, on est à ~1M gas juste pour le setup. Sur Base à ~0.01 gwei L2 fee, c'est négligeable (~$0.01). Mais si on migre vers mainnet un jour, c'est un problème. **Décision : acceptable pour V1 sur Base. Marquer comme dette technique pour V2.**

---

### 1.3 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Justification :** C'est la seule architecture réaliste. Le jugement de qualité de code est fondamentalement subjectif et non-déterministe. Mettre un score on-chain sans pouvoir vérifier ce qu'il représente crée un faux sentiment de sécurité.

Modèle retenu :

```
┌─────────────────────────────────────────────┐
│                 OFF-CHAIN                    │
│  Agent Reviewer → rapport.md + score (0-100)│
│  Orchestrator vérifie threshold              │
│  Si pass: package {rapport, score, metadata} │
│  Hash = keccak256(package)                   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│                  ON-CHAIN                    │
│  submitGateAttestation(                      │
│    workflowId,                               │
│    stageIndex,                               │
│    attestationHash,                          │
│    score,          // uint8, visible on-chain│
│    agentSignature, // agent reviewer signe   │
│    orchestratorSig // co-signature           │
│  )                                           │
└──────────────────────────────────────────────┘
```

**Le score est en clair on-chain** (pas juste le hash) pour permettre :
- L'analyse de réputation sans query off-chain
- La vérification par le client sans dépendre du stockage off-chain
- L'agrégation statistique pour le reputation system

**Le rapport complet est off-chain** (IPFS ou S3 avec hash commitment) car le stocker on-chain est absurde (coût, taille).

---

### 1.4 ✅ Max 6 stages par workflow

**Justification :** Guard-rail empiriquement sain. Au-delà de 6 :
- La latence end-to-end dépasse les attentes raisonnables d'un client
- Le coût cumulé des quality gates dépasse la valeur marginale
- La surface de dispute explose combinatoirement
- Le gas de setup dépasse le seuil psychologique

**Implémentation :** Hardcodé dans le contrat : `require(stages.length <= 6, "MAX_STAGES_EXCEEDED")`. Pas configurable. C'est un invariant de protocole, pas un paramètre.

---

### 1.5 ✅ Le modèle SSPW (Sequential Spine with Parallel Wings)

**Justification :** Les 3 patterns couvrent 95%+ des cas d'usage réels :
- **Sequential** : la majorité des issues (code → review → done)
- **Fan-out parallel** : review croisée, test en parallèle de l'audit sécu
- **Conditional branch** : retry/escalation sur failure

**Raffinement que j'ajoute :** Le `parallelGroup` dans le struct Stage est élégant mais insuffisant. Il faut aussi un `gatePolicy` au niveau du groupe, pas seulement du stage :

```solidity
enum GatePolicy { ALL_PASS, MAJORITY_PASS, ANY_PASS }
// ALL_PASS: tous les stages du parallelGroup doivent passer
// MAJORITY_PASS: >50% des stages parallèles passent
// ANY_PASS: un seul suffit (race mode — premier qui pass déclenche l'avancée)
```

`ANY_PASS` est intéressant pour le modèle "best-of-N" : lancer 3 coders en parallèle, prendre le premier qui passe la quality gate, refund les autres. C'est un power feature pour Gold.

---

### 1.6 ✅ Budget en basis points (BPS) par stage

**Justification :** Les BPS (1/100 de %) sont le standard DeFi pour la répartition. `uint16` donne une granularité de 0.01%, largement suffisante.

**Contrainte critique ajoutée :**

```solidity
uint16 totalBps = 0;
for (uint i = 0; i < stages.length; i++) {
    totalBps += stages[i].budgetBps;
}
require(totalBps == 10000, "BUDGET_MUST_TOTAL_100_PERCENT");
```

**Aucun reste.** Pas de "platform fee prélevé avant split". Les fees plateforme sont prélevées *avant* la création du workflow. Le budget qui entre dans le `WorkflowEscrow` est 100% distribué aux agents. Ceci simplifie radicalement la comptabilité on-chain et élimine une classe entière de bugs d'arrondi.

---

## 2. Décisions Rejetées

### 2.1 ❌ Conditional branching on-chain (Pattern 3 dans le contrat)

**Rejeté.** Le Pattern 3 (conditional branch sur failure) est présenté comme un pattern de workflow, mais l'implémenter on-chain est une erreur :

- Ça transforme le contrat en un **DAG engine** avec des edges conditionnels
- Le gas de gestion d'un DAG dépasse celui d'une simple liste linéaire d'un facteur 3-5x
- La complexité d'audit de sécurité du contrat explose

**Décision retenue :** Le contrat ne connaît que des **listes linéaires de stages**. Le conditional branching est géré **entièrement par l'Orchestrator off-chain** qui :
1. Détecte un stage FAILED
2. Décide de la branche (retry, skip, escalation, abort)
3. Appelle `createWorkflow()` avec un nouveau workflow si nécessaire (fork)
4. Ou appelle `retryStage()` si le retry count n'est pas épuisé

Le contrat expose `retryStage(workflowId, stageIndex)` qui :
- Vérifie `retryCount < maxRetries`
- Reset le stage state à `ACTIVE`
- Ne release pas de budget supplémentaire (même budget, nouvel agent éventuellement)

Ceci maintient le contrat comme une **FSM linéaire simple** tout en permettant des workflows complexes via l'orchestration off-chain. Le trade-off est que la logique de branching n'est pas vérifiable on-chain — mais elle n'a pas besoin de l'être car elle est protégée par le `clientHaltWorkflow()` veto.

---

### 2.2 ❌ Un contrat WorkflowEscrow monolithique avec toute la logique

**Rejeté.** Le cycle propose implicitement un seul contrat. En réalité, il faut une séparation :

```
WorkflowEscrow.sol        — Logique financière (escrow, release, refund par stage)
WorkflowRegistry.sol      — Stockage des définitions de workflows (stages, configs)
GateAttestationStore.sol  — Stockage des attestations (hash, score, signatures)
```

**Pourquoi :** Le `WorkflowEscrow` doit rester auditable et simple. Si on mélange le stockage des attestations et la logique financière, on crée un contrat de 800+ lignes impossible à auditer proprement.

**Contre-argument anticipé :** "3 contrats = 3x les appels cross-contract = plus de gas". Vrai, mais :
- Sur Base L2, le gas overhead est négligeable
- L'auditabilité > l'optimisation gas en V1
- On peut consolider en V2 si le gas devient un problème mesurable

---

### 2.3 ❌ Timeout on-chain avec block.timestamp

**Rejeté comme mécanisme primaire.** Le `timeout: uint32` dans le Stage struct est tentant mais dangereux :

- `block.timestamp` est manipulable par les validateurs (±15 secondes sur L2, plus sur L1)
- Un timeout qui release automatiquement des fonds on-chain crée un vecteur d'attaque : un agent peut délibérément timeout un stage pour trigger un refund partiel
- La granularité nécessaire (heures/jours) rend la manipulation de timestamp non-pertinente, MAIS le problème est que **personne ne monitor on-chain**. Un timeout passé ne s'exécute pas tout seul — il faut un appel.

**Décision retenue :**
- Le timeout est **monitoré off-chain** par l'Orchestrator
- L'Orchestrator appelle `timeoutStage(workflowId, stageIndex)` quand le deadline est dépassé
- Le contrat vérifie `block.timestamp >= stageDeadline` comme guard, mais ne l'auto-exécute jamais
- Le client a aussi le droit d'appeler `timeoutStage()` directement (pas dépendant de l'Orchestrator)

---

### 2.4 ❌ Retry avec nouvel agent automatiquement assigné on-chain

**Rejeté.** L'assignment d'agents est une opération de matching qui n'a rien à faire on-chain. Le contrat sait qu'un retry a lieu. Qui l'exécute est décidé off-chain par l'Orchestrator basé sur le reputation score, la disponibilité, le prix.

---

## 3. Nouveaux Insights

### 3.1 🆕 Le budget achète de la densité de vérification, pas du compute

C'est l'insight le plus important du cycle, et il doit être propagé dans tout le système. Concrètement :

| Tier | Budget Range | Densité de vérification | Pattern |
|------|-------------|------------------------|---------|
| Bronze | $5-50 | 1 stage (coder seul, auto-test) | Sequential minimal |
| Silver | $50-500 | 2-3 stages (coder + reviewer) | Sequential standard |
| Gold | $500-5000 | 4-6 stages (coder + reviewer×2 + tester + auditor) | SSPW full |

**Ce que ça implique pour le pricing :** Le client ne choisit pas un tier, il choisit un budget. Le tier est **déduit** du budget. Le système recommande un workflow template correspondant au tier, mais le client peut override (ex: mettre $500 sur un workflow Bronze = un seul coder très bien payé, aucune review).

**Ceci invalide une hypothèse implicite des cycles précédents** : le tier n'est pas un produit distinct, c'est un **preset de workflow**. Le vrai primitive est le workflow + le budget. Le tier est du UX sugar.

### 3.2 🆕 La chaîne de preuve composable

Chaque stage produit un **artefact** et une **attestation**. L'attestation du stage N référence l'artefact du stage N-1. Ceci crée une chaîne :

```
Stage 0 (Coder):
  artifact_hash_0 = keccak256(code_diff)
  attestation_0 = {artifact_hash_0, score: N/A, sig_coder}

Stage 1 (Reviewer):
  artifact_hash_1 = keccak256(review_report)
  attestation_1 = {artifact_hash_1, score: 82, prev: attestation_0.hash, sig_reviewer}

Stage 2 (Tester):
  artifact_hash_2 = keccak256(test_report)
  attestation_2 = {artifact_hash_2, score: 95, prev: attestation_1.hash, sig_tester}
```

**Pourquoi c'est important :** En cas de dispute, on peut vérifier la chaîne complète. Si le reviewer a donné 82/100 mais que le code ne compile pas, c'est la faute du reviewer — sa réputation est impactée, pas celle du coder. La chaîne rend la **responsabilité traçable par stage**.

**Implémentation on-chain :** Chaque attestation stocke un `bytes32 prevAttestationHash`. Le contrat vérifie que ce hash correspond à la dernière attestation enregistrée pour le stage précédent. C'est un linked list de hashes — ultra cheap en gas, ultra puissant en traçabilité.

### 3.3 🆕 Le parallelGroup avec ANY_PASS comme mécanisme de compétition

C'est un insight qui n'existait pas dans les cycles précédents. Le mode `ANY_PASS` sur un groupe parallèle crée un **marché compétitif intra-workflow** :

```
Stage 1: parallelGroup=1, gatePolicy=ANY_PASS
  ├── CODER_A (agent alpha, bid $80)
  ├── CODER_B (agent beta, bid $75)
  └── CODER_C (agent gamma, bid $90)

Premier qui soumet un artefact passant le quality gate → gagne le budget
Les autres sont annulés, pas de paiement
```

**Problème :** Les agents perdants ont dépensé du compute pour rien. C'est acceptable pour des agents IA (le coût marginal est du GPU time), mais ça peut décourager la participation.

**Mitigation :** Un `consolationBps` optionnel dans le Stage — par exemple 5% du budget du stage réparti entre les perdants. Le client paie un premium de ~15% mais obtient une compétition qui maximise la qualité.

**Décision : Feature Gold-only, V1.5.** Trop complexe pour le launch mais trop puissant pour être ignoré.

### 3.4 🆕 L'Orchestrator comme composant critique nécessitant un design à part entière

Les cycles précédents ont traité l'orchestration comme un "détail d'implémentation". Ce cycle révèle que l'Orchestrator est en réalité **le composant le plus complexe du système** :

Il doit :
1. Écouter les events on-chain (stage créé, attestation soumise)
2. Router les artefacts entre stages (passer le code du Coder au Reviewer)
3. Évaluer les quality gates (vérifier le score vs threshold)
4. Gérer les timeouts (monitor + appeler timeoutStage)
5. Assigner les agents (matching basé sur skills, réputation, prix)
6. Gérer les retries (décider de retry, skip, ou abort)
7. Gérer les disputes (collecter les preuves, initier l'arbitrage)

**C'est un service stateful critique.** Il a besoin de :
- Une base de données pour l'état des workflows (pas seulement on-chain)
- Une queue de messages pour les transitions asynchrones
- Un système de monitoring/alerting
- Une stratégie de recovery en cas de crash

**Ce n'est PAS un simple script.** C'est un **microservice production-grade** qui mérite son propre cycle de design.

---

## 4. PRD Changes Required

### 4.1 `MASTER.md` — Section "Architecture"

**Ajouter :**
- Diagramme 3-couches : Client → WorkflowEscrow → MissionEscrow[]
- Description du Workflow Orchestrator comme composant first-class
- La séparation on-chain/off-chain comme principe architecturel (#1 : "Le contrat est une FSM financière, l'orchestration est off-chain")

**Modifier :**
- Supprimer toute mention de "quality gates on-chain" comme logique de décision
- Remplacer par "attestation commitments on-chain, évaluation off-chain"

### 4.2 `MASTER.md` — Section "Smart Contracts"

**Ajouter :**
```
Contrats V1:
├── MissionEscrow.sol (existant, 323 lignes, 14 tests) — missions standalone
├── WorkflowEscrow.sol (nouveau) — orchestration financière multi-stage
├── WorkflowRegistry.sol (nouveau) — définition et stockage des workflows
├── GateAttestationStore.sol (nouveau) — attestations de quality gates
└── AgentRegistry.sol (existant) — identité et réputation des agents
```

**Modifier :**
- Spécifier que `WorkflowEscrow` compose `MissionEscrow` via appels internes
- Documenter les structs Stage, GateAttestation, WorkflowConfig

### 4.3 `MASTER.md` — Section "Pricing/Tiers"

**Modifier :**
- Les tiers ne sont pas des produits, ce sont des **presets de workflow**
- Le primitive est : `(workflow_definition, total_budget)`
- Les tiers sont du UX sugar qui mappe budget → workflow recommandé

### 4.4 `MASTER.md` — Nouvelle section "Workflow Orchestrator"

**Ajouter :**
- Description du service TypeScript
- Responsabilités (les 7 points listés en 3.4)
- API surface (endpoints internes)
- Trust model : l'Orchestrator est trusted mais auditable (logs signés)
- Recovery strategy

### 4.5 `MASTER.md` — Section "Dispute Resolution"

**Modifier :**
- Disputes en V1 : client veto + arbitrage manuel par l'équipe
- Disputes en V2 : Kleros/UMA integration
- La chaîne d'attestations comme preuve primaire en cas de dispute
- Responsabilité traçable par stage via `prevAttestationHash`

---

## 5. Implementation Priority

### Phase 1 — Foundation (Semaines 1-3)

```
1. WorkflowRegistry.sol
   - createWorkflowTemplate(stages[])
   - Validation: max 6 stages, budgetBps == 10000
   - Tests Foundry: 8-10 tests
   Complexité: Moyenne
   Risque: Faible

2. GateAttestationStore.sol
   - submitAttestation(workflowId, stageIndex, hash, score, sigs)
   - Vérification co-signature (agent + orchestrator)
   - Chaînage: prevAttestationHash verification
   - Tests Foundry: 6-8 tests
   Complexité: Moyenne
   Risque: Moyen (signature verification edge cases)

3. WorkflowEscrow.sol
   - createWorkflow() — lock total budget, split par stage via BPS
   - activateStage() — unlock stage budget, create MissionEscrow
   - completeStage() — verify attestation, release funds
   - retryStage() — reset state, increment retry counter
   - timeoutStage() — verify deadline, refund stage budget
   - clientHaltWorkflow() — emergency freeze
   - Tests Foundry: 15-20 tests
   Complexité: Haute
   Risque: Élevé (interactions avec MissionEscrow, edge cases financiers)
```

**Gate de phase 1 :** Tous les tests Foundry verts + audit informel par un pair.

### Phase 2 — Orchestrator MVP (Semaines 3-5)

```
4. Workflow Orchestrator (TypeScript service)
   - Event listener pour WorkflowEscrow events
   - Sequential workflow execution (Pattern 1 uniquement)
   - Timeout monitoring
   - Agent assignment (basic round-robin en V1)
   - Artifact routing (S3 + hash commitment)
   Complexité: Haute
   Risque: Élevé (c'est le composant le plus nouveau)

5. Integration tests
   - End-to-end: client crée workflow → coder exécute → reviewer valide → paiement
   - Failure path: stage fails → retry → succeed
   - Timeout path: stage timeout → refund
   Complexité: Moyenne
   Risque: Moyen
```

### Phase 3 — Parallel Wings (Semaines 5-7)

```
6. Support parallelGroup dans WorkflowEscrow
   - activateStageGroup() — active tous les stages d'un parallelGroup
   - GatePolicy enforcement (ALL_PASS, MAJORITY_PASS)
   - Tests Foundry: 8-10 tests additionnels
   Complexité: Haute
   Risque: Moyen

7. Orchestrator parallel support
   - Fan-out: créer N missions parallèles
   - Fan-in: attendre selon gatePolicy
   - Artifact merging strategy
   Complexité: Haute
   Risque: Élevé
```

### Phase 4 — Polish (Semaines 7-8)

```
8. ANY_PASS competitive mode (Gold feature)
9. consolationBps pour perdants
10. Dashboard client: visualisation du workflow progress
11. Agent notification: "vous avez été assigné au stage 3"
```

---

## 6. Next Cycle Focus

### La question la plus importante : **Comment l'Orchestrator gère-t-il les artefacts inter-stages ?**

C'est le trou béant de l'architecture actuelle. On a défini :
- On-chain : la FSM financière ✅
- Off-chain : l'Orchestrator comme concept ✅
- Les attestations : hash + score ✅

Mais on n'a **jamais spécifié** :

1. **Format des artefacts** — Un code diff ? Un patch git ? Un lien vers un commit ? Un tarball ?
2. **Stockage** — S3 ? IPFS ? Arweave ? Git repo direct ?
3. **Passage inter-stages** — Comment le Reviewer reçoit-il le code du Coder ? Via l'Orchestrator qui proxie ? Via un shared storage avec ACL ?
4. **Intégrité** — Comment vérifier que l'artefact que le Reviewer a reviewé est bien celui que le Coder a produit ? Le hash commitment résout la preuve, mais pas l'accès.
5. **Taille** — Un diff de 50 lignes vs un refactor de 5000 lignes ont des implications différentes pour le stockage et le routing.

**Proposition de focus pour le cycle suivant :**

```
Cycle zv — Artifact Pipeline Architecture
├── Artifact format specification (par type de stage)
├── Storage strategy (IPFS vs S3 vs Git-native)
├── Inter-stage routing protocol
├── Integrity verification flow
├── Size limits et chunking strategy
└── Impact sur le Orchestrator design
```

**Question secondaire mais critique :** Le **reputation impact** des attestations. Si un Reviewer donne 90/100 à du code bugué, comment ça affecte sa réputation ? Il faut un modèle de feedback loop entre les stages terminaux (le code fonctionne-t-il en production ?) et les scores donnés aux stages intermédiaires. C'est le problème du "delayed ground truth" et il est fondamental pour la viabilité long-terme du marketplace.

---

## 7. Maturity Score

### Score : 6.5 / 10

**Justification détaillée :**

| Dimension | Score | Commentaire |
|-----------|-------|-------------|
| Architecture on-chain | 8/10 | FSM financière + composition MissionEscrow = solide. Il reste à implémenter et tester. |
| Architecture off-chain | 5/10 | L'Orchestrator est identifié comme critique mais pas designé. C'est une boîte noire pour l'instant. |
| Data model | 7/10 | Stage struct est propre, attestation chain est élégante. Le format des artefacts est non-spécifié. |
| Trust model | 6/10 | Le duo Orchestrator + client veto est raisonnable en V1. Le cas de l'Orchestrator malveillant/défaillant n'est pas assez couvert. |
| Economic model | 7/10 | BPS split, fee before workflow, consolationBps — cohérent. Le pricing des quality gates (qui paie le reviewer ?) manque de clarté sur les incitations. |
| Implémentabilité | 6/10 | Le plan de phases est réaliste. Le risque principal est la Phase 2 (Orchestrator) qui est sous-estimée en complexité. |
| Couverture de test | 7/10 | Le socle MissionEscrow (14 tests) est solide. Les ~40 tests supplémentaires nécessaires sont identifiés. |
| Readiness to build | 6/10 | On peut commencer Phase 1 (contrats) immédiatement. On ne peut PAS commencer Phase 2 sans un cycle de design dédié à l'Orchestrator. |

**Ce qui manque pour passer à 8/10 :**
1. Design détaillé de l'Orchestrator (architecture interne, state management, failure modes)
2. Spécification du pipeline d'artefacts (format, stockage, routing)
3. Modèle économique des reviewers (comment garantir qu'un reviewer de qualité est incité à participer)
4. Threat model complet (Orchestrator compromis, collusion agent-reviewer, gaming des scores)

**Verdict :** On est prêt à builder les **smart contracts** (Phase 1). On n'est **pas** prêt à builder le **système complet**. Le prochain cycle doit fermer le gap sur l'Orchestrator et le pipeline d'artefacts avant d'attaquer Phase 2.