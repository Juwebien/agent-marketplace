

# Cycle zo — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le budget achète une réduction structurelle d'incertitude, pas du compute

**Justification :** C'est le framing correct pour le pricing et le go-to-market. Un menu de workflows (Bronze = 1 stage, Silver = 3 stages, Gold = 5 stages) est vendable, explicable, et surtout — ne crée pas d'obligation contractuelle on-chain de résultat. Le client comprend qu'il achète "plus de vérification", pas "moins de bugs garanti". Ce framing évite le piège du SLA probabiliste qu'on n'a pas les données pour supporter et qui créerait un vecteur d'exploitation (agents qui gaming le threshold pour trigger le payout).

**Impact architecture :** Les tiers sont des templates de workflow, pas des paramètres de contrat d'assurance. Pas de `p(defect)` on-chain. Pas de remboursement automatique basé sur un score qualité.

### 1.2 ✅ Sequential-only en V1, max 6 stages

**Justification :** Le triple argument (gas imprévisible, surface de dispute combinatoire, UX catastrophique) contre le DAG arbitraire est définitif. Un pipeline linéaire avec quality gates entre chaque stage est :
- **Déterministe en gas** — O(n) avec n ≤ 6, coût prédictible
- **Arbitrable** — le point de failure est toujours identifiable (quel stage, quel QG)
- **Explicable** — Bronze = `[Code]`, Silver = `[Code → Review → Test]`, Gold = `[Code → Review → Security → Test → Integration]`

Le cap à 6 stages est un guard-rail sain. Au-delà, on entre dans le territory de la cérémonie sans valeur ajoutée — la latence accumulée (chaque stage = temps d'exécution agent + temps de QG) dépasse la valeur marginale de vérification.

### 1.3 ✅ WorkflowEscrow compose MissionEscrow, ne le remplace pas

**Justification :** Les 14 tests Foundry verts sur `MissionEscrow.sol` (323 lignes) sont un actif. Le pattern de composition est le seul viable :

```
WorkflowEscrow.sol (NEW)
  └── calls MissionEscrow.createMission() pour chaque stage
  └── agit comme meta-client vis-à-vis de MissionEscrow
  └── gère l'orchestration inter-stages (avancement, branching conditionnel V2)
```

**Conséquence non-négociable :** `MissionEscrow.sol` ne doit PAS être modifié dans ce cycle. Toute logique workflow est additive. Si `WorkflowEscrow` a besoin d'un hook dans `MissionEscrow`, on passe par un pattern événementiel (écoute d'events `MissionCompleted`, `MissionFailed`) et non par modification du contrat existant.

### 1.4 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Justification :** C'est la seule architecture réaliste. Trois arguments :

| Aspect | Full on-chain QG | Attestation hybride |
|---|---|---|
| **Jugement qualité** | Impossible — un SC ne parse pas du code | Agent reviewer off-chain, résultat signé |
| **Coût storage** | Prohibitif — un rapport de review = 2-10KB | Hash 32 bytes on-chain, rapport sur IPFS/Arweave |
| **Oracle problem** | Non résolu | Résolu par séparation exécutant/reviewer + dispute channel |

Le flow concret :

```
1. Agent exécutant termine le stage → output sur IPFS → hash(output) on-chain
2. Agent reviewer évalue off-chain → rapport IPFS → {hash(rapport), score, sig} on-chain
3. score ≥ threshold → advanceStage() automatique
4. score < threshold → failStage() → budget redistribué ou refund partiel
5. Client peut challenger l'attestation → dispute (V2: arbitrage externe)
```

### 1.5 ✅ Budget split défini à la création du workflow, pas dynamiquement

**Justification implicite du cycle mais à rendre explicite :** Le `createWorkflow(stages[], budgetSplit[], qualityGateConfigs[])` fixe la répartition budgétaire au moment de la création. Pas de réallocation dynamique en V1. Raisons :

- **Prédictibilité pour les agents** — un agent qui accepte un stage sait exactement combien il sera payé
- **Simplification du dispute** — si le stage 3 échoue, les stages 4-5-6 sont annulés et leur budget est refunded. Pas d'ambiguïté
- **Gas** — une réallocation dynamique nécessite un recalcul des allocations, un re-approval du client, potentiellement un nouveau signature cycle

---

## 2. Décisions Rejetées

### 2.1 ❌ SLA chiffré ou garantie probabiliste on-chain

**Rejeté définitivement.** Encoder un `p(defect) < X%` dans le smart contract :
- Nécessite des données actuarielles qu'on n'a pas (combien de cycles d'exécution avant d'avoir une distribution fiable ?)
- Crée un moral hazard : agents qui optimisent pour le metric plutôt que pour la qualité réelle
- Rend le contrat exploitable : un attaquant peut soumettre des issues calibrées pour trigger le seuil de remboursement

**Ce qu'on fait à la place :** Les tiers sont descriptifs ("ce workflow inclut N stages et M quality gates"), pas prescriptifs ("ce workflow garantit X% de qualité"). Le marché établira les prix d'équilibre — si Gold ne délivre pas significativement mieux que Bronze, les clients arrêteront de payer le premium. C'est le mécanisme de feedback correct.

### 2.2 ❌ DAG arbitraire en V1

**Rejeté.** Déjà justifié en §1.2. Réservé à V2 (Pattern 2: Parallel Fan-Out) et V2+ (Pattern 3: Conditional Branch) après validation du sequential sur données réelles.

### 2.3 ❌ WorkflowEscrow comme contrat séparé déployé indépendamment

**Point subtil.** Le workflow ne doit PAS être un contrat standalone qui ne connaît pas `MissionEscrow`. La tentation serait de faire un `WorkflowEscrow` qui gère tout (budget, stages, payout). C'est un rewrite déguisé.

**Rejeté parce que :**
- Double audit nécessaire (deux contrats gérant des USDC)
- Fragmentation de la liquidité escrow
- Perte des 14 tests Foundry comme filet de sécurité

**Retenu à la place :** `WorkflowEscrow` est un **orchestrateur** qui délègue toute la gestion financière à `MissionEscrow`. Il ne touche jamais directement aux USDC. Son rôle est purement logique : séquencement, quality gate evaluation, avancement/échec.

### 2.4 ❌ Agent reviewer = agent exécutant (juge et partie)

**Rejeté.** C'est l'oracle problem appliqué au marketplace. Si l'agent qui code est aussi celui qui review, le QG est un rubber stamp.

**Conséquence structurelle :** Le marketplace doit maintenir un **pool d'agents reviewers distincts des agents exécutants**. En V1, cette séparation peut être soft (même opérateur humain, mais agents distincts avec des addresses différentes). En V2, enforcement on-chain : `require(stageAgent != reviewerAgent)`.

---

## 3. Nouveaux Insights

### 3.1 🆕 Le Workflow comme meta-client — pattern d'agent orchestrateur

Le framing `WorkflowEscrow` agit comme "meta-client" vis-à-vis de `MissionEscrow` est un insight architecturalement puissant qu'on n'avait pas explicité avant. Cela signifie :

- **Du point de vue de `MissionEscrow`**, le workflow est juste un client ordinaire qui crée des missions, les fund, les complète ou les dispute. Zéro modification nécessaire.
- **Du point de vue du client réel**, le workflow est une abstraction transparente : il dépose son budget une fois dans `WorkflowEscrow`, et celui-ci crée les `MissionEscrow` stages au fur et à mesure.
- **Implication pour le fee model** : le workflow prend-il une fee sur chaque stage qu'il crée ? Si oui, c'est un "orchestration fee" qui justifie économiquement l'existence du tier. Si non, le premium du tier vient uniquement du nombre d'agents engagés.

**Question ouverte à trancher :** Est-ce que `WorkflowEscrow` pré-fund toutes les missions au `createWorkflow`, ou est-ce qu'il fund chaque mission au `advanceStage` ? Le pre-funding est plus simple mais lock le capital. Le funding progressif est plus capital-efficient mais nécessite que le workflow détienne le budget résiduel (= le workflow devient un mini-escrow lui-même, ce qu'on voulait éviter).

**Ma recommandation :** Pre-funding de toutes les missions à la création. Raisons :
1. L'agent exécutant du stage 3 veut voir le budget locké avant d'accepter — sinon, rien ne garantit que le workflow aura les fonds quand son tour viendra
2. Simplification radicale du flow — pas de "stage prêt mais pas encore funded"
3. Le capital locké est le signal de sérieux du client. C'est exactement le rôle de l'escrow

### 3.2 🆕 Le delta économique ROI est quantifiable et c'est l'argument commercial

Le calcul `$15/h × 30% rework = $4.50/h gaspillé` vs `Silver à +60% = $4.50/h de premium` qui élimine 65% du rework est le premier calcul ROI concret du tiered model. Même si les chiffres sont estimés, la *structure* du calcul est l'argument de vente :

```
ROI(Silver vs Bronze) = (rework_eliminated × cost_per_rework_hour) - tier_premium
                       = (0.65 × $4.50) - $4.50
                       = $2.925 - $4.50
                       = -$1.575 (négatif ! Silver n'est PAS ROI+ à ces chiffres)
```

**Wait — le calcul du cycle est faux.** Si Silver coûte +60% et élimine 65% du rework, le calcul correct est :

```
Base cost: $15/h agent
Rework cost: 30% × $15/h = $4.50/h
Total Bronze effective cost: $15 + $4.50 = $19.50/h

Silver cost: $15 × 1.60 = $24/h
Silver rework: 30% × (1 - 0.65) × $15 = $1.575/h
Total Silver effective cost: $24 + $1.575 = $25.575/h

Delta: Silver coûte $6.075/h DE PLUS que Bronze
```

**Silver n'est ROI-positif que si le rework rate baseline est beaucoup plus élevé, ou si le coût du rework inclut des externalités (delay, missed deadline, reputational damage).** Ce recalcul est un insight critique : **il faut soit augmenter l'efficacité des QG soit réduire le premium du tier pour que le ROI soit immédiatement évident.**

**Action :** Le pricing des tiers doit être calibré sur des données réelles, pas sur des estimations. En V1, les tiers sont à prix fixe (templates), et on collecte les données pour calibrer en V2.

### 3.3 🆕 L'attestation hybride crée un marché secondaire de reputation

Si chaque quality gate produit un `{hash(rapport), score, signature_reviewer}` on-chain, on accumule un graphe vérifiable de :
- **Reputation agent exécutant** : combien de QG passés/échoués, par quel reviewer, sur quel type de task
- **Reputation agent reviewer** : corrélation entre ses scores et les disputes ultérieures (un reviewer qui donne toujours des pass et dont les outputs sont systématiquement disputés est un mauvais reviewer)
- **Reputation workflow template** : quel tier produit effectivement moins de disputes

C'est une **boucle de feedback vérifiable** qui n'existe pas dans les marketplaces freelance traditionnelles (où les reviews sont des étoiles subjectives non vérifiables). C'est potentiellement le moat le plus puissant de la plateforme.

---

## 4. PRD Changes Required

### 4.1 MASTER.md — Section Architecture

| Section | Changement | Priorité |
|---|---|---|
| **Smart Contract Architecture** | Ajouter `WorkflowEscrow.sol` comme contrat d'orchestration composant `MissionEscrow.sol`. Spécifier le pattern meta-client. Documenter que `MissionEscrow.sol` n'est PAS modifié. | P0 |
| **Tier Definitions** | Remplacer toute mention de "SLA" ou "garantie" par "workflow template". Définir Bronze (1 stage, 0 QG), Silver (3 stages, 2 QG), Gold (5 stages, 4 QG). Cap à 6 stages max. | P0 |
| **Quality Gate Specification** | Nouvelle section. Spécifier le flow attestation hybride : off-chain evaluation → IPFS storage → on-chain commitment `{hash, score, sig}`. Threshold configurable par workflow template. | P0 |
| **Budget Split Model** | Nouvelle section. Spécifier pre-funding de toutes les missions au `createWorkflow`. Documenter le refund flow si un stage échoue (stages non-exécutés = refund intégral au client). | P0 |
| **Fee Model** | Ajouter orchestration fee prélevé par `WorkflowEscrow` (suggestion: 2-5% du budget total, distinct du platform fee). Justifier économiquement. | P1 |

### 4.2 MASTER.md — Section Pricing

| Section | Changement | Priorité |
|---|---|---|
| **ROI Calculations** | Corriger le calcul ROI. Soit recalculer avec des chiffres réalistes, soit supprimer les chiffres absolus et garder uniquement la structure du calcul (le framework, pas les valeurs). | P0 |
| **Pricing Strategy** | Expliciter que V1 = prix fixes par template, data collection active. V2 = dynamic pricing basé sur les données collectées. Pas de promesse ROI avant N=100 workflows complétés. | P1 |

### 4.3 MASTER.md — Section Dispute Resolution

| Section | Changement | Priorité |
|---|---|---|
| **Dispute Flow** | Adapter pour les workflows multi-stage : la dispute porte sur un stage spécifique, pas sur le workflow entier. Le client identifie le stage et le QG contesté. | P1 |
| **Arbitrage V2** | Mentionner Kleros/UMA comme options d'arbitrage externe. Ne pas spécifier le choix — c'est une décision V2. | P2 |

### 4.4 Nouveau document : `WORKFLOW_SPEC.md`

Créer un document dédié avec :
- Schéma des 3 patterns (Sequential V1, Parallel V2, Conditional V2)
- State machine complète d'un workflow (`Created → Stage1_Active → Stage1_QG → Stage2_Active → ... → Completed | Failed`)
- Interface `WorkflowEscrow.sol` (fonctions, events, structs)
- Matrice de compatibility tier × pattern
- Test plan (extension des 14 tests existants)

**Priorité : P0 — ce document est le prerequisite du build.**

---

## 5. Implementation Priority

```
Phase 1 — Foundation (Semaine 1-2)
━━━��━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1.1 WORKFLOW_SPEC.md rédigé et reviewé               ← Bloquant pour tout le reste
  1.2 WorkflowEscrow.sol — struct Workflow + createWorkflow()
      - Workflow { stages[], budgetSplits[], qualityGateConfigs[], status }
      - Pre-fund toutes les MissionEscrow à la création
      - Tests: workflow creation, budget split validation, stage count ≤ 6
  1.3 WorkflowEscrow.sol — advanceStage() + failStage()
      - advanceStage(): vérifie QG attestation, active le stage suivant
      - failStage(): refund les stages non-exécutés, paye les stages complétés
      - Tests: happy path 3 stages, failure at stage 2 (refund stage 3), 
               QG attestation validation

Phase 2 — Quality Gates (Semaine 3)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  2.1 QualityGateAttestation struct on-chain
      - { bytes32 reportHash, uint8 score, address reviewer, bytes signature }
      - require(reviewer != stageAgent)
  2.2 Threshold logic
      - score ≥ threshold → auto-advance
      - score < threshold → pending_dispute state (client decides)
  2.3 Tests: valid attestation, invalid signature, reviewer = agent (revert),
             threshold edge cases

Phase 3 — Tier Templates (Semaine 4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  3.1 TierRegistry.sol ou mapping dans WorkflowEscrow
      - Bronze: { stages: [Code], qgConfigs: [] }
      - Silver: { stages: [Code, Review, Test], qgConfigs: [QG1, QG2] }
      - Gold: { stages: [Code, Review, Security, Test, Integration], qgConfigs: [QG1..QG4] }
  3.2 createWorkflowFromTier(tierId, issueRef, budget) — convenience function
  3.3 Tests: tier creation, tier immutability, workflow from tier matches spec

Phase 4 — Integration & Hardening (Semaine 5)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  4.1 End-to-end test: Gold workflow, 5 stages, 4 QGs, happy path
  4.2 End-to-end test: Silver workflow, failure at stage 2, partial refund
  4.3 End-to-end test: Dispute on QG attestation
  4.4 Gas benchmarking sur Base Sepolia
  4.5 MissionEscrow regression — les 14 tests originaux passent toujours
```

**Dépendance critique :** Phase 1.1 (WORKFLOW_SPEC.md) bloque tout. Ne pas commencer le code avant que le spec soit stabilisé. Le code sans spec, dans un système multi-contrat avec de l'argent réel, est de la dette technique pré-natale.

---

## 6. Next Cycle Focus

### La question la plus importante :

> **Comment le matching agent-to-stage fonctionne-t-il dans un workflow multi-stage ?**

C'est le trou béant de ce cycle. On a défini le workflow, les stages, les quality gates, le budget split. Mais qui **assigne** les agents aux stages ? Les scénarios :

| Scénario | Avantage | Problème |
|---|---|---|
| **A. Le client choisit chaque agent par stage** | Contrôle total | UX catastrophique, le client ne connaît pas les agents |
| **B. Le premier agent choisit les suivants** | Simple | Collusion (l'agent invite ses alts pour capter tout le budget) |
| **C. Le marketplace matche automatiquement** | Meilleure UX | Nécessite un algorithme de matching + reputation scoring |
| **D. Les agents bid sur chaque stage** | Découverte de prix | Latence (chaque stage attend un bid), complexity |

**Ma recommandation préliminaire :** Scénario D pour V1 avec timeout. Chaque stage est un mini-marché : quand le stage N est complété et le QG passé, le stage N+1 est ouvert aux bids pendant T minutes. Premier agent qualifié qui bid au prix du budget split → assigné. Timeout sans bid → le client est remboursé pour les stages restants.

Mais ce scénario a des implications profondes :
- Le temps total du workflow = Σ(temps_exécution + temps_QG + temps_bidding) — potentiellement très long
- Un agent malveillant peut bid puis abandonner (griefing) — nécessite un stake/bond
- Le budget split est fixé à la création mais les agents ne le découvrent qu'au moment du bid — mauvais signal si le split est déséquilibré

**Le prochain cycle doit produire :** Un flow complet de matching agent-stage avec state machine, incentives, et protection anti-griefing. C'est le composant qui transforme le workflow d'un concept architectural en un produit fonctionnel.

---

## 7. Maturity Score

### Score : 6.0 / 10

| Dimension | Score | Justification |
|---|---|---|
| **Concept clarity** | 8/10 | Le framing "budget = réduction d'incertitude" est clair et différenciant. Les tiers comme templates sont bien définis. |
| **Architecture definition** | 7/10 | Le pattern composition WorkflowEscrow → MissionEscrow est sain. Le flow QG hybride est réaliste. Le sequential-only V1 est la bonne décision. |
| **Smart contract design** | 5/10 | Les interfaces sont esquissées mais pas spécifiées (pas d'ABI, pas de state machine formelle, pas de gas estimates). Le pre-funding model a des implications non explorées (que se passe-t-il si MissionEscrow a un bug et les fonds sont lockés dans les sous-missions ?). |
| **Economic model** | 4/10 | Le calcul ROI est faux (corrigé dans ce document). Le pricing des tiers est "à définir". L'orchestration fee n'est pas chiffré. On ne sait pas si le model est economiquement viable. |
| **Agent matching** | 2/10 | Trou béant. Pas de design pour le matching agent-stage. C'est le composant le plus critique pour le produit et il n'existe pas encore. |
| **Implementation readiness** | 6/10 | Le plan en 5 phases est réaliste. Les 14 tests existants sont un bon socle. Mais on ne peut pas commencer Phase 1.2 avant d'avoir résolu le matching (ou au moins décidé de le stub). |
| **Data / Feedback loop** | 7/10 | L'insight sur la reputation vérifiable via attestations QG est fort. Pas encore designé (schema, queries, UI) mais le concept est là. |

**Justification du 6.0 :** On a une architecture saine et un concept clair, mais deux trous critiques empêchent de passer à l'implémentation sereinement : (1) l'economic model non validé et (2) le matching agent-stage non designé. Un score de 7+ nécessite que ces deux points soient résolus. Un score de 8+ nécessite en plus un `WORKFLOW_SPEC.md` complet avec ABI et state machine formelle. Un score de 9+ nécessite un prototype déployé sur testnet avec un happy path fonctionnel.

**On n'est pas prêt à builder le code smart contract, mais on est prêt à écrire le spec (`WORKFLOW_SPEC.md`).** C'est la prochaine action concrète.