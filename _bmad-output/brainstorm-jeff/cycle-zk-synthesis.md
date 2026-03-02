

# Cycle zk — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Pipeline séquentiel contraint (max 6 stages) — V1 uniquement

**Justification :** Le tableau comparatif est sans appel. Un DAG libre multiplie la surface de dispute de façon combinatoire (2^n chemins de failure vs n), rend le gas imprévisible, et détruit l'UX. Les 6 stages max sont un guard-rail sain — au-delà, la latence cumulée et la complexité de dispute mangent toute la valeur ajoutée d'un stage supplémentaire. Le pipeline séquentiel est aussi le seul modèle dont les 14 tests Foundry existants peuvent servir de base sans réécriture.

**Implication concrète :** Toute demande de "branching conditionnel" ou "parallélisme" est un ticket V2+, pas une discussion V1.

### 1.2 ✅ WorkflowEscrow compose MissionEscrow, ne le remplace pas

**Justification :** Le `MissionEscrow.sol` (323 lignes, 14/14 tests verts) est un actif prouvé. `WorkflowEscrow` agit comme un **meta-client** qui appelle `MissionEscrow.createMission()` pour chaque stage. Ce pattern préserve :
- La non-régression (les 14 tests restent verts sans modification)
- La composabilité (un agent peut toujours accepter une mission unitaire hors workflow)
- La surface d'audit (on audite un contrat wrapper, pas une réécriture)

**Risque identifié à mitiger :** Le pattern meta-client crée une dépendance d'appel inter-contrats. Il faut que `WorkflowEscrow` ait un rôle `WORKFLOW_OPERATOR` autorisé dans `MissionEscrow`, sinon n'importe qui pourrait créer des missions "orphelines" qui bypassent le workflow. Ce rôle doit être ajouté au `AccessControl` existant.

### 1.3 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Justification :** C'est la décision architecturale la plus importante du cycle. Le rejet des QG full on-chain est fondé sur trois arguments irréfutables :
1. **Subjectivité du jugement** — aucun smart contract ne peut évaluer la pertinence d'un code review
2. **Coût gas prohibitif** — stocker des rapports de review on-chain est économiquement absurde
3. **Oracle problem** — l'agent reviewer est juge et partie s'il push lui-même le pass/fail

Le modèle retenu (`hash(rapport) + score + signature → QualityGateAttestation`) est un bon compromis : vérifiabilité cryptographique sans surcoût gas, avec un chemin de dispute explicite.

**Challange que je pose :** Qui définit le **seuil de passage** du quality gate ? Trois options et une seule est viable en V1 :

| Option | Problème | Viable V1 ? |
|--------|----------|-------------|
| Le client définit le seuil au setup | Clients non-techniques ne savent pas calibrer | ❌ |
| Le tier impose le seuil (Bronze=60, Silver=75, Gold=85, Plat=95) | Simple, prévisible, pas de décision client | ✅ |
| L'agent reviewer auto-évalue | Conflit d'intérêt total | ❌ |

**Décision recommandée :** Les seuils sont **hardcodés par tier** dans `WorkflowEscrow.sol` comme constantes. Le client achète un tier, pas un seuil custom. Ça simplifie radicalement l'UX et élimine une surface de configuration abusable.

### 1.4 ✅ Le Budget-Tiered Workflow comme business model (pas comme feature)

**Justification :** L'insight est juste et structurant. Le revenu moyen par mission passant de ~$100 à ~$500-$2000 change fondamentalement l'unit economics de la plateforme. Les fees du protocole sur un workflow Gold à $1500 (disons 5% = $75) sont 7.5x les fees sur une mission unitaire à $100 ($5). Plus important : ça crée un **moat défendable**. Un concurrent qui copie la marketplace d'agents doit aussi copier le pipeline de quality assurance, l'escrow multi-stages, les seuils calibrés par tier, et le système de dispute stage-par-stage. C'est un système intégré, pas une feature additive.

### 1.5 ✅ Architecture 3 couches Client → Workflow → Mission[]

**Justification :** La séparation est propre et chaque couche a une responsabilité claire :
- **Client** : paye, choisit un tier, observe le progrès, dispute si insatisfait
- **Workflow** : orchestre les stages, enforce les quality gates, gère les timeouts inter-stages
- **Mission** : exécute une tâche atomique, livre un output, reçoit un paiement

Le Workflow est une entité **logique** (struct dans `WorkflowEscrow.sol`), pas un contrat séparé. Ça évite les appels cross-contract supplémentaires et simplifie le modèle de gas.

---

## 2. Décisions Rejetées

### 2.1 ❌ DAG arbitraire en V1

**Rejeté définitivement pour V1.** Raisons couvertes en §1.1. Pour V2+, un DAG ne sera envisagé que si le pipeline séquentiel montre des limitations mesurables en production (ex : >30% des workflows Gold nécessitent un parallélisme review+security que le séquentiel ne peut pas servir). Pas de spéculation avant data.

### 2.2 ❌ Quality Gates full on-chain

**Rejeté définitivement** (pas juste pour V1 — le modèle est fondamentalement inadapté). Couvert en §1.3. Le modèle attestation off-chain + commitment on-chain est la bonne architecture long-terme.

### 2.3 ❌ Seuils de quality gate configurables par le client en V1

**Rejeté pour V1.** Les seuils customisables sont un vecteur d'abus (client met seuil à 100% pour ne jamais payer, ou à 0% rendant le QG inutile) et une source de friction UX. Les seuils hardcodés par tier sont la bonne abstraction V1.

### 2.4 ❌ WorkflowEscrow comme contrat séparé de MissionEscrow

**Rejeté.** La tentation de faire un contrat `Workflow.sol` indépendant qui gère son propre escrow est dangereuse : ça duplique la logique de lock/release/dispute, ça double la surface d'audit, et ça casse la composabilité avec les missions unitaires. Le pattern composition (WorkflowEscrow wraps MissionEscrow) est supérieur.

### 2.5 ❌ Agent reviewer comme seul arbitre du quality gate

**Rejeté.** L'agent reviewer peut produire l'attestation, mais ne peut pas être le seul à décider du pass/fail sans recours. Le chemin de dispute doit exister dès V1, même s'il est manuel (admin multisig) avant l'intégration Kleros/UMA en V2.

---

## 3. Nouveaux Insights

### 3.1 🆕 Le `planHash` comme ancre d'immutabilité du workflow

L'introduction du `planHash = keccak256(abi.encode(stages, budgetSplits, qgConfigs))` est **genuinement nouvelle** et critique. C'est l'équivalent d'un "contrat signé" : une fois le workflow créé on-chain avec ce hash, ni la plateforme, ni l'agent, ni le client ne peut modifier les termes (splits, seuils, nombre de stages) sans que le hash ne change. Ça résout le problème de confiance à la racine.

**Implication non couverte par les cycles précédents :** Le `planHash` doit être calculé **off-chain par le WorkflowCompiler** et vérifié **on-chain au createWorkflow()**. Si le hash soumis ne correspond pas au recalcul on-chain des paramètres, le tx revert. Ça empêche un frontend malicieux de soumettre un plan altéré.

### 3.2 🆕 Le rôle `WORKFLOW_OPERATOR` comme primitive d'accès

Les cycles précédents traitaient `MissionEscrow` comme un contrat appelé directement par clients et agents. L'introduction de `WorkflowEscrow` comme meta-client nécessite un **nouveau rôle** dans le modèle d'accès. Ce rôle n'existait pas dans les spécifications antérieures et a des implications de sécurité :
- Seul `WorkflowEscrow` (adresse déployée connue) peut créer des missions multi-stages liées
- Les agents ne peuvent pas "détacher" une mission de son workflow parent
- Les paiements de stage ne sont libérés que si `WorkflowEscrow` confirme le passage du quality gate

### 3.3 🆕 Tension structurelle entre "timeout par stage" et "timeout global du workflow"

Les cycles précédents définissaient des timeouts par mission. Avec les workflows multi-stages, un problème nouveau apparaît :

- **Timeout stage** : l'agent Coder a 120min, le Reviewer a 60min
- **Timeout workflow** : le client veut une livraison en 8h, mais 6 stages × timeout max = 12h

**Insight :** Il faut un **dual-timeout** — chaque stage a un timeout individuel ET le workflow a un timeout global qui est le min(sum(stage_timeouts), client_deadline). Si le timeout global est atteint, les stages restants sont annulés et les fonds non-alloués sont refunded. Aucun cycle précédent n'a adressé cette interaction.

### 3.4 🆕 Le `WorkflowCompiler` comme composant off-chain critique

Le concept d'un service qui prend un tier + une issue GitHub et produit un `WorkflowPlan` optimisé est **le cœur de la valeur ajoutée off-chain**. C'est l'équivalent d'un "deviseur automatique" :
1. Analyse la complexité de l'issue (LOC estimées, langages, dépendances)
2. Sélectionne le template de workflow pour le tier choisi
3. Calibre les budget splits selon la difficulté relative de chaque stage
4. Produit le `planHash` pour ancrage on-chain

**Risque :** Si le WorkflowCompiler est centralisé (un seul service), il devient un SPOF et un vecteur de censure. En V1 c'est acceptable (MVP), mais le path vers la décentralisation de ce composant doit être documenté (V3+: compilation on-chain ou via réseau de nœuds spécialisés).

### 3.5 🆕 La pression déflationnaire AGNT est proportionnelle au tier, pas au volume

Insight économique important : si les fees du protocole alimentent le burn d'AGNT, alors un seul workflow Platinum à $2000 (fee: $100) brûle autant d'AGNT que 20 missions unitaires à $100 (fee: $5 × 20 = $100). Mais le workflow Platinum consomme **beaucoup moins de ressources de matching et de monitoring** que 20 missions indépendantes. La marge opérationnelle de la plateforme est donc **structurellement plus élevée sur les tiers supérieurs**. Ça implique que l'incitation à pousser les clients vers Gold/Platinum n'est pas juste revenue — c'est aussi marge.

---

## 4. PRD Changes Required

### 4.1 `MASTER.md` — Section "Smart Contract Architecture"

**Action :** Ajouter un sous-section "WorkflowEscrow.sol" avec :
- Le pattern de composition avec `MissionEscrow.sol`
- Le struct `WorkflowPlan` on-chain (version allégée : `planHash`, `tier`, `stageCount`, `currentStage`, `status`)
- Les fonctions `createWorkflow()`, `advanceStage()`, `failStage()`, `timeoutWorkflow()`
- Le rôle `WORKFLOW_OPERATOR` dans l'AccessControl

### 4.2 `MASTER.md` — Section "Mission Lifecycle"

**Action :** Étendre le lifecycle pour inclure :
- Le state `WORKFLOW_PENDING` (workflow créé, premier stage pas encore démarré)
- Les transitions `STAGE_N_COMPLETE → QUALITY_GATE_N → STAGE_N+1_START`
- Le state `WORKFLOW_PARTIAL_COMPLETE` (certains stages livrés, workflow timeout atteint)
- Les règles de refund partiel (stages complétés sont payés, stages non-démarrés sont refunded)

### 4.3 `MASTER.md` — Nouvelle section "Budget Tiers Specification"

**Action :** Créer une section dédiée avec :

| Tier | Stages | QG Threshold | Typical Budget | Protocol Fee | Target Use Case |
|------|--------|-------------|----------------|--------------|-----------------|
| Bronze | 2 (Code → Review) | 60/100 | $50-200 | 3% | Bug fixes, small features |
| Silver | 3 (Code → Review → Test) | 75/100 | $200-500 | 4% | Medium features, refactors |
| Gold | 4 (Code → Review → Security → Test) | 85/100 | $500-1500 | 5% | Critical features, API endpoints |
| Platinum | 5-6 (Code → Review → Security → Test → Optimization → Final Review) | 95/100 | $1500-5000 | 6% | Core infrastructure, security-critical |

### 4.4 `MASTER.md` — Section "Quality Assurance"

**Action :** Nouvelle section couvrant :
- Le modèle d'attestation off-chain + commitment on-chain
- Le format de `QualityGateAttestation` (hash du rapport, score, signature agent, timestamp)
- Le mécanisme de dispute : client challenge → freeze escrow → arbitrage (V1: multisig admin, V2: Kleros/UMA)
- Les seuils hardcodés par tier et la justification de ne pas les rendre configurables

### 4.5 `MASTER.md` — Section "Off-chain Components"

**Action :** Ajouter le `WorkflowCompiler` comme composant documenté :
- Input : tier choisi + issue GitHub (titre, body, labels, repo metadata)
- Output : `WorkflowPlan` avec `planHash`
- Contraintes : déterministe (même input → même plan), versioned (`compiledBy` field)
- Path de décentralisation (V1: centralisé, V3+: réseau distribué)

### 4.6 `MASTER.md` — Section "Tokenomics"

**Action :** Mettre à jour pour refléter :
- Protocol fees graduées par tier (3-6% au lieu d'un flat 5%)
- Impact sur le burn rate AGNT : modéliser le scenario où 60% du volume est Bronze/Silver et 40% est Gold/Platinum
- Marge opérationnelle supérieure sur les tiers élevés

### 4.7 `MASTER.md` — Section "Timeout & Failure Handling"

**Action :** Nouvelle section couvrant le dual-timeout :
- Timeout par stage (configurable par rôle dans le WorkflowPlan)
- Timeout global du workflow (dérivé ou explicite)
- Règles de cascade : stage timeout → agent slashé/remplacé → même stage reassigné (max 1 retry) → workflow fail
- Refund partiel : formule exacte pour calculer le refund client quand un workflow fail au stage N sur M

---

## 5. Implementation Priority

### Phase 1 — Fondations (Semaines 1-2)

**Objectif :** `WorkflowEscrow.sol` minimal qui compose `MissionEscrow.sol` pour un pipeline Bronze (2 stages).

```
1.1 Ajouter rôle WORKFLOW_OPERATOR à MissionEscrow AccessControl
    → 2 tests : seul WORKFLOW_OPERATOR peut créer des missions liées
    → Vérifier que les 14 tests existants restent verts

1.2 Struct WorkflowPlan on-chain (version minimale)
    → planHash, tier, stageCount, currentStage, status, totalBudget
    → Mapping workflowId → WorkflowPlan
    → 3 tests : création, immutabilité post-création, planHash verification

1.3 createWorkflow() → crée N MissionEscrow atomiquement
    → Budget split enforcement (sum = 100%)
    → Premier stage passe en OPEN, les autres en WORKFLOW_PENDING
    → 4 tests : happy path, budget mismatch revert, max 6 stages revert, planHash mismatch revert
```

**Deliverable :** WorkflowEscrow crée un pipeline Bronze fonctionnel. ~9 nouveaux tests. 14 anciens tests verts.

### Phase 2 — Quality Gates & Advancement (Semaines 3-4)

**Objectif :** advanceStage() avec quality gate attestation.

```
2.1 QualityGateAttestation struct + verification
    → bytes32 reportHash, uint8 score, bytes signature, uint256 timestamp
    → Verification : signature valide, score >= tier threshold, timestamp < stage timeout
    → 4 tests : valid attestation advances stage, score below threshold reverts,
      invalid signature reverts, expired attestation reverts

2.2 advanceStage(workflowId, attestation)
    → Current stage → COMPLETED, paiement libéré vers agent du stage
    → Next stage → OPEN (available pour matching)
    → Final stage completion → WORKFLOW_COMPLETED
    → 3 tests : mid-pipeline advance, final stage completion, advance on wrong stage reverts

2.3 failStage(workflowId, reason)
    → Stage → FAILED, workflow → FAILED
    → Refund partiel : stages complétés restent payés, stages non-démarrés refunded
    → 3 tests : fail at stage 0 (full refund), fail at stage N (partial refund), 
      refund calculation accuracy
```

**Deliverable :** Pipeline complet avec quality gates. ~10 nouveaux tests. Total : ~33 tests.

### Phase 3 — Tiers complets & Timeouts (Semaines 5-6)

**Objectif :** Support des 4 tiers + dual-timeout.

```
3.1 Tier templates (Silver, Gold, Platinum)
    → Factory functions : createSilverWorkflow(), createGoldWorkflow(), etc.
    → Ou : createWorkflow() avec validation des contraintes par tier
    → Seuils QG hardcodés : BRONZE=60, SILVER=75, GOLD=85, PLATINUM=95
    → 4 tests : un par tier, vérifiant stages count et seuils corrects

3.2 Stage timeout enforcement
    → timeoutStage(workflowId) : callable par anyone après expiration
    → Agent du stage slashé (reputation, pas financièrement en V1)
    → Stage reassigné une fois (retry flag), puis workflow fail
    → 4 tests : timeout triggers reassignment, double timeout triggers fail,
      premature timeout reverts, timeout on completed stage reverts

3.3 Workflow global timeout
    → Calculé comme min(sum(remaining_stage_timeouts), explicit_deadline)
    → timeoutWorkflow(workflowId) : cascade cancel sur tous les stages pending
    → 3 tests : global timeout triggers cascade, partial completion + timeout,
      global timeout before any stage timeout
```

**Deliverable :** Tous les tiers fonctionnels avec timeouts. ~11 nouveaux tests. Total : ~44 tests.

### Phase 4 — WorkflowCompiler off-chain (Semaines 7-8)

**Objectif :** Service off-chain qui produit des WorkflowPlans à partir d'issues GitHub.

```
4.1 Issue analyzer
    → Parse GitHub issue : title, body, labels, repo languages
    → Estimation de complexité : LOC, nombre de fichiers, dépendances
    → Output : ComplexityScore

4.2 Plan generator
    → Input : tier + ComplexityScore
    → Output : WorkflowPlan avec budget splits calibrés
    → Templates par tier avec ajustements selon complexité
    → planHash calculé et inclus

4.3 API endpoint
    → POST /api/workflow/compile { issueUrl, tier } → WorkflowPlan
    → Deterministic : même input → même output (pour vérifiabilité)
    → Versioned : compiledBy = "workflow-compiler-v1.0.0"

4.4 Integration tests
    → Submit plan to WorkflowEscrow.createWorkflow() on testnet
    → Verify planHash matches on-chain recalculation
    → End-to-end : issue → plan → create → advance → complete
```

**Deliverable :** Pipeline complet issue-to-workflow. Prêt pour testnet.

---

## 6. Next Cycle Focus

### Question centrale du prochain cycle :

> **Comment le matching agent ↔ stage fonctionne dans un workflow multi-stages, et comment le système gère le cas où aucun agent qualifié n'est disponible pour un stage intermédiaire ?**

C'est la question la plus dangereuse non résolue. Aujourd'hui le matching est implicitement 1:1 (une mission, un agent). Avec un workflow Gold à 4 stages, il faut matcher **4 agents différents séquentiellement**, et le workflow est bloqué si le stage 3 (Security Auditor) n'a aucun agent disponible — pendant que les fonds des stages 1-2 sont déjà payés et le client attend.

**Sous-questions à explorer :**
1. **Pool de pré-matching :** Au `createWorkflow()`, faut-il vérifier que des agents sont disponibles pour chaque rôle avant d'accepter les fonds ? Ou accepter optimistement et gérer le timeout ?
2. **Agent substitution :** Si l'agent matché pour un stage timeout, le retry assigne un autre agent. Quel est le mécanisme de sélection du remplaçant ? First-come ? Auction ? Reputation-weighted ?
3. **Stage skipping :** Si aucun Security Auditor n'est disponible pour un workflow Gold, peut-on "downgrader" dynamiquement le workflow vers Silver (skip le stage security, refund partiel) plutôt que de timeout entier ? Ou est-ce une violation du contrat avec le client ?
4. **Economic incentives :** Les agents spécialisés rares (Security Auditor) sont le goulot d'étranglement. Comment tarifer leur rareté ? Budget split dynamique basé sur l'offre/demande par rôle ? Premium automatique quand le pool d'un rôle est petit ?

**Livrable attendu du prochain cycle :** Un `MatchingEngine` spec qui couvre le multi-stage matching avec les 4 sous-questions ci-dessus.

---

## 7. Maturity Score

### Score : **6.5 / 10**

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Architecture on-chain** | 7/10 | Le pattern composition WorkflowEscrow → MissionEscrow est sain et validé. Le `planHash` comme ancre d'immutabilité est solide. Manque : le modèle exact de refund partiel n'est pas encore formalisé en Solidity (formule oui, implémentation non). |
| **Quality Gates** | 6/10 | Le modèle attestation off-chain + commitment on-chain est le bon design. Manque : le format exact de l'attestation (quel standard de signature ? EIP-712 ?), le storage on-chain minimal (juste le hash ? ou hash + score ?), et surtout le mécanisme de dispute V1 (multisig admin — mais quel process ? quel SLA de réponse ?). |
| **Modèle économique** | 7/10 | Les fees graduées par tier sont bien pensées. La pression déflationnaire AGNT proportionnelle au tier est un insight solide. Manque : modélisation concrète du break-even (combien de workflows Gold/mois pour couvrir les coûts opérationnels ?), et la répartition exacte entre protocol fee, agent payment, et burn. |
| **Off-chain components** | 5/10 | Le WorkflowCompiler est identifié mais pas spécifié au-delà du concept. Comment estime-t-il la complexité ? Quels sont les templates par tier ? Comment calibre-t-il les budget splits ? C'est le composant le plus "handwavy" actuellement. |
| **Matching multi-stage** | 4/10 | C'est le trou béant identifié en §6. Aucune spécification de comment les agents sont matchés séquentiellement, comment gérer les goulots d'étranglement de rôles rares, et comment le système dégrade gracieusement. |
| **Test coverage** | 7/10 | Les 14 tests existants comme base de non-régression + le plan de ~44 tests pour WorkflowEscrow est crédible. Mais aucun test n'est écrit pour la partie workflow — c'est encore un plan. |
| **Security model** | 6/10 | Le `planHash` empêche la manipulation des termes. Le rôle `WORKFLOW_OPERATOR` empêche la création de missions orphelines. Manque : analyse des vecteurs d'attaque spécifiques au multi-stage (ex : un agent reviewer qui collude avec l'agent coder pour rubber-stamp un QG, un client qui dispute systématiquement au dernier stage pour griéfer les agents). |

### Pourquoi pas 8+ ?

Trois raisons :

1. **Le matching multi-stage est non spécifié.** C'est le composant qui détermine si le workflow engine fonctionne en pratique ou s'effondre au premier goulot d'étranglement de rôle. Sans MatchingEngine spec, on a un beau pipeline qui ne peut pas assigner de travail.

2. **Le mécanisme de dispute V1 est flou.** "Multisig admin" n'est pas une spec, c'est un placeholder. Qui sont les signers ? Quel est le process ? Quel est le SLA ? Que se passe-t-il si les admin signers ne répondent pas dans les 48h ? Ce composant doit être spécifié au même niveau de rigueur que le WorkflowEscrow.

3. **Le WorkflowCompiler est conceptuel.** C'est le composant que les clients touchent en premier (ils soumettent une issue, ils reçoivent un plan). Si le plan est mal calibré (budget splits absurdes, mauvais nombre de stages pour la complexité), toute l'expérience utilisateur s'effondre. Il faut des heuristiques concrètes, pas juste "analyse la complexité".

### Ce qu'il faut pour atteindre 8/10 :

- Spec du MatchingEngine multi-stage (cycle prochain)
- Spec du mécanisme de dispute V1 avec SLA et process explicites
- Au moins les templates du WorkflowCompiler définis (quel plan pour un "bug fix" vs un "new API endpoint" vs un "security patch")
- Premiers tests Foundry du WorkflowEscrow écrits (pas juste planifiés)

### Ce qu'il faut pour atteindre 9/10 :

- Tout le 8/10 + déploiement testnet du WorkflowEscrow
- Au moins un workflow end-to-end (Bronze) complété sur testnet avec de vrais agents
- Analyse de sécurité formelle des vecteurs d'attaque multi-stage
- Modélisation économique avec simulations Monte Carlo du mix de tiers