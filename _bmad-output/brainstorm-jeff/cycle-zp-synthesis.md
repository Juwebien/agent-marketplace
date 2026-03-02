

# Cycle zp — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le budget achète de la vérification, pas du compute

**Validé — c'est le core narrative de la plateforme.** Chaque dollar supplémentaire finance un adversaire de plus dans la chaîne de confiance. Ce mental model résout trois problèmes simultanément :

- **Pricing discovery** : menu lisible (BRONZE/SILVER/GOLD/PLATINUM) au lieu d'un marché opaque sur la "qualité" d'un agent
- **Différenciation concurrentielle** : aucune plateforme d'agents IA ne vend de la vérification graduée — toutes vendent du compute ou des "meilleurs modèles"
- **Alignement des incentives** : l'agent producteur et l'agent vérificateur sont structurellement adversaires, ce qui crée de la confiance sans tiers centralisé

**Mais un garde-fou s'impose :** le tier BRONZE (1 stage, pas de QG) doit rester fonctionnel et rentable. Si 80% du volume se concentre sur BRONZE parce que les clients ne valorisent pas la vérification, le modèle s'effondre. **Action :** tracker la distribution des tiers dès le launch, et designer les defaults pour que SILVER soit le choix naturel (anchoring UX).

### 1.2 ✅ Pipeline séquentiel strict (V1)

**Validé définitivement.** Pas de DAG, pas de fan-out. Les arguments sont terminaux :

- La complexité d'un DAG engine on-chain est disproportionnée par rapport à la valeur (gas costs, surface d'attaque, debugging)
- Le séquentiel est suffisant pour les 4 tiers identifiés
- Le passage DAG en V2+ est un ajout pur, pas un refactor — le séquentiel est un sous-cas du DAG

**Contrainte technique ajoutée :** max 6 stages hard-codé dans le contrat (`require(stages.length <= 6)`). Pas de paramètre admin modifiable. Si on veut 7+ stages, c'est un nouveau contrat.

### 1.3 ✅ WorkflowEscrow compose MissionEscrow, ne le modifie pas

**Validé — c'est la décision architecturale la plus importante du cycle.** Le pattern est :

```
WorkflowEscrow.sol (nouveau)
  │
  ├── createWorkflow() → crée N missions via MissionEscrow.createMission()
  ├── advanceStage()   → valide QG attestation, puis trigger MissionEscrow.completeMission()
  ├── failStage()      → calcule le refund des stages non-exécutés
  │
  └── MissionEscrow.sol (inchangé, 323 lignes, 14/14 tests verts)
```

**Pourquoi c'est critique :**

- Les 14 tests Foundry existants restent green sans modification → zero regression risk
- MissionEscrow est déjà audité mentalement par l'équipe, toute modification réduit la confiance
- WorkflowEscrow agit comme un "meta-client" qui crée des missions pour le compte du vrai client → separation of concerns propre
- Si WorkflowEscrow a un bug, les missions individuelles restent récupérables via MissionEscrow directement → failure isolation

**Risque identifié :** le `msg.sender` de `createMission()` sera `WorkflowEscrow`, pas le client final. Il faut que `MissionEscrow` supporte un `onBehalfOf` pattern ou que `WorkflowEscrow` soit un proxy transparent. **Décision : utiliser un pattern `createMissionFor(client, ...)` ajouté à MissionEscrow comme seule modification autorisée** — c'est une addition, pas une modification du code existant.

### 1.4 ✅ Quality Gates = attestation off-chain + commitment on-chain

**Validé — c'est le bon compromis pour V1.** Les QG entièrement on-chain sont rejetées (voir §2.1), mais le modèle hybride est solide :

```
┌─────────────────────────────────────────────────────┐
│                   Off-chain                          │
│  1. Stage[n] agent produit output + artifacts        │
│  2. QG agent (reviewer) pull les artifacts           │
│  3. Reviewer produit: { report, score, pass/fail }   │
│  4. Reviewer signe: sign(hash(report) || score       │
│     || workflowId || stageIndex)                     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                   On-chain                           │
│  5. advanceStage(workflowId, attestation{            │
│       reportHash, score, pass, signature             │
│     })                                               │
│  6. Contrat vérifie: signature valide + signer       │
│     est un reviewer enregistré + score >= threshold  │
│  7. Si pass → release escrow stage[n], init stage    │
│     [n+1]                                            │
│  8. Si fail → branch vers FAILED + refund logic      │
└─────────────────────────────────────────────────────┘
```

**Threshold par tier :**

| Tier | Score minimum | Reviewers requis | Consensus |
|------|--------------|------------------|-----------|
| BRONZE | N/A (pas de QG) | 0 | N/A |
| SILVER | 70/100 | 1 | Single attestation |
| GOLD | 80/100 | 2 | Both must pass |
| PLATINUM | 85/100 | 2 + 1 adversarial | 2/3 majority |

### 1.5 ✅ Tier Structure (4 tiers)

**Validé avec budget ranges précisés :**

| Tier | Stages | QG entre stages | Budget indicatif | Use case type |
|------|--------|-----------------|-------------------|---------------|
| BRONZE | 1 | 0 | < $50 | Bug fix simple, typo, small feature |
| SILVER | 2 | 1 | $50–200 | Feature standard, refactor |
| GOLD | 3 | 2 | $200–1000 | Feature complexe, API integration |
| PLATINUM | 5 | 4 (dont 1 adversarial) | $1000+ | Architecture change, security-critical |

**Budget split par défaut (overridable par le client) :**

| Tier | Execution % | Verification % | Platform fee % |
|------|-------------|-----------------|----------------|
| BRONZE | 90% | 0% | 10% |
| SILVER | 70% | 20% | 10% |
| GOLD | 55% | 35% | 10% |
| PLATINUM | 45% | 45% | 10% |

Le ratio vérification/exécution qui augmente avec le tier est le **mécanisme économique central** : il rend explicite que la vérification a un coût et une valeur.

---

## 2. Décisions Rejetées

### 2.1 ❌ Quality Gates entièrement on-chain

**Rejeté définitivement.** Trois raisons terminales :

1. **Subjectivité irréductible.** Un smart contract ne peut pas juger si un code review est pertinent, si une architecture est saine, ou si un test couvre les edge cases. Prétendre le contraire est du théâtre de sécurité.

2. **Coût gas prohibitif.** Stocker un rapport de review (même résumé) on-chain coûte ~$5-50 en gas sur Base L2. Pour un workflow SILVER à $100, ça représente 5-50% du budget en overhead. Absurde.

3. **Oracle problem non-résolu.** Si l'agent reviewer pousse son propre pass/fail on-chain, il est juge et partie. On n'a pas éliminé la confiance, on l'a déplacée. L'attestation off-chain + dispute mechanism est strictement supérieure car elle rend le reviewer *accountable* (sa réputation est stakée) sans prétendre que le jugement est mécanique.

### 2.2 ❌ Tiers dynamiques / budget continu

**Rejeté.** L'idée de laisser le client choisir librement le nombre de stages et le budget split a été considérée et écartée :

- **Complexité UX** : un slider "combien de vérification voulez-vous ?" est moins lisible qu'un menu à 4 options
- **Complexité contractuelle** : chaque configuration custom est une surface d'attaque (edge cases dans le refund logic, budget splits qui ne somment pas à 100%, etc.)
- **Pricing opaque** : on retombe dans le problème que le tier system est censé résoudre

**Compromis retenu :** 4 tiers fixes avec possibilité d'override du budget split (mais pas du nombre de stages) en V1. Custom tiers en V2 si la demande le justifie.

### 2.3 ❌ WorkflowEscrow comme contrat séparé sans lien avec MissionEscrow

**Rejeté.** L'option "tout réécrire dans WorkflowEscrow sans réutiliser MissionEscrow" a été considérée et écartée :

- On perdrait les 14 tests existants comme filet de sécurité
- On dupliquerait la logique escrow (lock/release/refund) → double surface d'attaque
- On créerait deux chemins de paiement incompatibles → fragmentation de la liquidité USDC

### 2.4 ❌ Dispute resolution on-chain en V1

**Rejeté pour V1.** Le mécanisme de dispute (Kleros, UMA, ou custom) est explicitement reporté à V2. En V1 :

- Si le client conteste une QG attestation → dispute manuelle via support (centralisé, assumé)
- Le client peut toujours refuser d'initier un workflow si le reviewer assigné ne lui convient pas
- La réputation du reviewer (off-chain, mais trackée) est le seul mécanisme de confiance

**Pourquoi c'est acceptable :** en V1, le volume sera faible et les montants modestes. Le coût d'un arbitrage manuel est absorbable. En V2, quand le volume justifie l'investissement, on intègre un système d'arbitrage décentralisé.

---

## 3. Nouveaux Insights

### 3.1 🆕 `createMissionFor(client, ...)` — le seul changement autorisé sur MissionEscrow

C'est genuinement nouveau. Les cycles précédents parlaient de "composer" sans spécifier le mécanisme. Le problème concret est :

```
// Aujourd'hui
MissionEscrow.createMission() → msg.sender = client ✓

// Avec WorkflowEscrow
WorkflowEscrow.createWorkflow() → calls MissionEscrow.createMission()
                                → msg.sender = WorkflowEscrow ✗ (pas le client!)
```

**Solution identifiée :** ajouter une seule fonction à MissionEscrow :

```solidity
// Addition (pas modification) à MissionEscrow.sol
function createMissionFor(
    address client,
    bytes32 missionId,
    // ... params
) external onlyAuthorizedWorkflowEngine {
    // même logique que createMission() mais client = paramètre
}

modifier onlyAuthorizedWorkflowEngine() {
    require(authorizedEngines[msg.sender], "NOT_AUTHORIZED");
    _;
}
```

C'est un pattern standard (meta-transaction / forwarder) qui préserve les 14 tests existants puisque `createMission()` n'est pas modifiée.

**Risque :** le modifier `onlyAuthorizedWorkflowEngine` introduit un point de centralisation (qui autorise les engines ?). **Mitigation :** governance multisig pour `authorizeEngine()`, et le mapping est public pour transparence.

### 3.2 🆕 Le PLATINUM tier inclut un stage "adversarial" explicite

Nouveau par rapport aux cycles précédents. Le PLATINUM ne se contente pas d'ajouter des stages de review — il inclut un stage dont le *mandat explicite* est de trouver des failles :

```
PLATINUM Pipeline:
  Stage[0]: Execution (agent A)
  QG[0]:    Review (agent B) — "est-ce que ça marche ?"
  Stage[1]: Hardening (agent C)
  QG[1]:    Review (agent D) — "est-ce que c'est robuste ?"
  Stage[2]: Adversarial (agent E) — "comment je casse ça ?"
  QG[2]:    Final review (agent F + agent G) — 2/3 consensus
```

L'agent adversarial est **payé pour trouver des problèmes**, pas pour les résoudre. S'il ne trouve rien, c'est un signal positif. S'il trouve quelque chose, le workflow revient à Stage[1] pour hardening (unique exception au pipeline strictement linéaire : le **rollback d'un cran** en cas de fail adversarial, pas un rollback arbitraire).

**Impact contractuel :** le `failStage()` doit supporter deux modes :
- `FAIL_TERMINAL` → refund et arrêt
- `FAIL_ROLLBACK` → retour au stage précédent (une seule fois, pour éviter les boucles infinies)

```solidity
enum FailMode { TERMINAL, ROLLBACK }

function failStage(
    bytes32 workflowId,
    uint8 stageIndex,
    FailMode mode
) external {
    if (mode == FailMode.ROLLBACK) {
        require(workflow.rollbackCount < MAX_ROLLBACKS, "MAX_ROLLBACKS_REACHED");
        workflow.currentStage = stageIndex - 1;
        workflow.rollbackCount++;
    } else {
        workflow.state = WorkflowState.FAILED;
        _refundUnexecutedStages(workflowId, stageIndex);
    }
}
```

`MAX_ROLLBACKS = 1` en V1. Pas de boucle possible.

### 3.3 🆕 Budget split comme primitive on-chain, pas juste un display

Les cycles précédents traitaient le budget split comme une info UX. En réalité, c'est une **primitive on-chain** car elle détermine les montants lockés à chaque stage :

```solidity
struct WorkflowConfig {
    uint8 numStages;
    uint16[] budgetBps; // basis points, doit sommer à 10000
    uint16 platformFeeBps; // ex: 1000 = 10%
    uint8 qualityGateThreshold; // score minimum 0-100
    uint8 requiredReviewers; // nombre de reviewers pour QG
}

// À la création du workflow:
function createWorkflow(
    bytes32 workflowId,
    Tier tier,
    WorkflowConfig calldata config,
    uint256 totalBudget
) external {
    // Validation: sum(budgetBps) + platformFeeBps == 10000
    uint256 platformFee = (totalBudget * config.platformFeeBps) / 10000;
    uint256 executionBudget = totalBudget - platformFee;

    for (uint8 i = 0; i < config.numStages; i++) {
        uint256 stageBudget = (executionBudget * config.budgetBps[i]) / 10000;
        // Lock stageBudget dans MissionEscrow via createMissionFor
    }
}
```

**Insight clé :** l'intégralité du budget est lockée upfront dans l'escrow, mais distribuée stage par stage. Ça signifie que le client engage 100% du budget au moment de la création du workflow, mais les agents ne touchent leur part que stage par stage. **C'est le mécanisme de confiance fondamental** : le client ne peut pas disparaître mid-workflow, et les agents non-assignés voient le budget locké (preuve de solvabilité).

### 3.4 🆕 Le refund partiel est calculable déterministiquement

Si le workflow fail au stage N, le refund est :

```
refund = Σ(stageBudget[i]) pour i = N+1 à numStages
       + stageBudget[N] si l'agent du stage N n'a rien livré
```

C'est déterministe, pas subjectif. Pas besoin d'arbitrage pour le refund. L'arbitrage ne concerne que la qualité de l'output (pass/fail de la QG), pas le calcul du montant.

---

## 4. PRD Changes Required

### 4.1 MASTER.md — Section "Smart Contract Architecture"

**Ajouter :**
```markdown
### WorkflowEscrow.sol
- Compose MissionEscrow (ne le modifie pas sauf ajout de createMissionFor)
- Gère le pipeline séquentiel: création, avancement, échec, refund partiel
- 4 tiers hard-codés: BRONZE (1 stage), SILVER (2), GOLD (3), PLATINUM (5)
- Max 6 stages, max 1 rollback
- Budget split en basis points, vérifié on-chain (sum = 10000)
```

### 4.2 MASTER.md — Section "Quality Gates"

**Réécrire entièrement :**
```markdown
### Quality Gates (V1)
- Off-chain: reviewer agent produit report + score + pass/fail
- On-chain: attestation = hash(report) + score + signature
- Threshold par tier (voir table)
- Dispute: manuelle via support en V1, Kleros/UMA en V2
- Pas de jugement de qualité on-chain — le contrat vérifie
  uniquement la validité de l'attestation et le score vs threshold
```

### 4.3 MASTER.md — Section "Payment Flow"

**Modifier :**
```markdown
### Payment Flow — Tiered Workflows
1. Client crée workflow → 100% budget locké dans WorkflowEscrow
2. WorkflowEscrow crée mission[0] via MissionEscrow.createMissionFor()
3. Agent[0] exécute → soumet output
4. QG reviewer atteste (off-chain report, on-chain hash+sig)
5. Si pass: MissionEscrow release → agent[0] payé, stage[1] initialisé
6. Si fail: TERMINAL → refund stages non-exécutés, ou ROLLBACK → retry
7. Repeat jusqu'à completion ou échec terminal
8. Platform fee prélevé à la création (pas à la fin)
```

### 4.4 MASTER.md — Nouvelle section "Tier Economics"

**Ajouter section complète :**
```markdown
### Tier Economics
| Tier | Exec % | Verif % | Fee % | Min Budget | Max Stages |
|------|--------|---------|-------|------------|------------|
| BRONZE | 90 | 0 | 10 | $5 | 1 |
| SILVER | 70 | 20 | 10 | $50 | 2 |
| GOLD | 55 | 35 | 10 | $200 | 3 |
| PLATINUM | 45 | 45 | 10 | $1000 | 5 |

Le client peut override le budget split (dans les limites du tier)
mais pas le nombre de stages.
```

### 4.5 MissionEscrow.sol — Changement minimal documenté

**Ajouter dans la section "Contract Changes" :**
```markdown
### MissionEscrow.sol — V1.1 (seul changement autorisé)
- Ajout: createMissionFor(address client, ...) + modifier onlyAuthorizedWorkflowEngine
- Ajout: mapping(address => bool) public authorizedEngines
- Ajout: authorizeEngine(address) / revokeEngine(address) — onlyOwner
- Aucune modification des 14 fonctions/tests existants
- Tests requis: 14 existants green + 4 nouveaux (createMissionFor happy path,
  unauthorized caller, engine authorization, engine revocation)
```

---

## 5. Implementation Priority

### Phase 1 — Semaine 1-2 : MissionEscrow V1.1

```
Priorité: CRITIQUE (bloque tout le reste)
Effort: ~1 jour de code, ~1 jour de tests

Tasks:
□ Ajouter createMissionFor() à MissionEscrow.sol
□ Ajouter authorizedEngines mapping + authorize/revoke
□ Écrire 4 tests Foundry supplémentaires
□ Vérifier: 14 tests existants toujours green (non-régression)
□ Total: 18/18 tests green

Definition of Done:
- forge test → 18/18 pass
- Aucune ligne modifiée dans les fonctions existantes (diff review)
- Gas report: createMissionFor ≤ 110% gas de createMission
```

### Phase 2 — Semaine 2-3 : WorkflowEscrow.sol (core)

```
Priorité: HAUTE
Effort: ~3-4 jours de code, ~2 jours de tests

Tasks:
□ Structs: Workflow, Stage, WorkflowConfig, Tier enum
□ createWorkflow() — validation budget split, lock USDC, create mission[0]
□ advanceStage() — vérifier QG attestation, release stage[n], init stage[n+1]
□ failStage(TERMINAL) — refund stages non-exécutés
□ getWorkflow() / getStage() — view functions
□ Events: WorkflowCreated, StageAdvanced, StageFailed, WorkflowCompleted

Tests Foundry (minimum 12):
□ createWorkflow happy path (chaque tier)
□ createWorkflow revert: invalid budget split
□ createWorkflow revert: budget below tier minimum
□ advanceStage happy path
□ advanceStage revert: invalid attestation signature
□ advanceStage revert: score below threshold
□ failStage TERMINAL + correct refund calculation
□ Full workflow: create → advance → advance → complete (GOLD tier)
□ Partial failure: create → advance → fail → refund (SILVER tier)
□ Deadline expiry → auto-refund
□ Double-advance prevention (reentrancy)
□ Platform fee correctly deducted at creation

Definition of Done:
- forge test → 30/30 pass (18 MissionEscrow + 12 WorkflowEscrow)
- 100% des paths couverts (happy, revert, edge)
- Gas report: createWorkflow PLATINUM ≤ 500k gas
```

### Phase 3 — Semaine 3-4 : QualityGate Attestation

```
Priorité: HAUTE
Effort: ~2 jours de code, ~1 jour de tests

Tasks:
□ QualityGateAttestation struct (reportHash, score, pass, signature, reviewer)
□ Signature verification (EIP-712 typed data)
□ Reviewer registry (mapping address => bool isRegisteredReviewer)
□ Multi-reviewer consensus pour GOLD/PLATINUM
□ Integration avec advanceStage()

Tests Foundry (minimum 6):
□ Valid single attestation (SILVER)
□ Valid dual attestation + consensus (GOLD)
□ Revert: invalid signature
□ Revert: non-registered reviewer
□ Revert: score below tier threshold
□ Edge: exactly-at-threshold score

Definition of Done:
- forge test → 36/36 pass
- EIP-712 domain separator correctly configured pour Base L2
```

### Phase 4 — Semaine 4-5 : Rollback + Adversarial (PLATINUM only)

```
Priorité: MOYENNE (PLATINUM est le dernier tier à implémenter)
Effort: ~2 jours

Tasks:
□ failStage(ROLLBACK) — retour au stage précédent
□ rollbackCount tracking + MAX_ROLLBACKS enforcement
□ Adversarial stage type dans WorkflowConfig
□ Tests: rollback happy path, max rollback reached, rollback + re-advance

Definition of Done:
- forge test → 42/42 pass
- Rollback ne crée pas de nouvelle mission (réutilise le stage existant)
```

### Phase 5 — Semaine 5-6 : Backend Integration + API

```
Priorité: HAUTE (bloque le frontend)
Effort: ~5 jours

Tasks:
□ API: POST /workflows — create workflow
□ API: POST /workflows/:id/advance — submit QG attestation + advance
□ API: GET /workflows/:id — status, stages, current stage
□ Event indexer: écoute WorkflowCreated, StageAdvanced, etc.
□ Agent assignment logic: match agent → stage par compétence + tier
□ QG attestation relay: agent signe off-chain, backend submit on-chain

Note: Pas de frontend dans cette phase. API-first.
```

---

## 6. Next Cycle Focus

### Question centrale du cycle zq :

> **Comment le matching agent → stage fonctionne-t-il concrètement, et comment évite-t-on que le même agent (ou des agents collusifs) occupent à la fois un stage d'exécution et le QG suivant ?**

C'est la question la plus dangereuse non-résolue. Le modèle de vérification adversariale **s'effondre** si :

1. **L'agent A exécute le Stage[0] et l'agent A (ou un sybil de A) review le QG[0]** → auto-validation
2. **Deux agents forment un cartel** : "je valide ton travail si tu valides le mien" → quality gate theater
3. **Le pool de reviewers est trop petit** → les clients n'ont pas le choix, un mauvais reviewer devient incontournable

**Sous-questions à traiter :**

- Quel mécanisme de staking/slashing rend la collusion économiquement irrationnelle ?
- Comment constituer le pool initial de reviewers (cold start problem) ?
- L'agent-assignment est-il on-chain (transparent mais gameable) ou off-chain (opaque mais flexible) ?
- Faut-il un "separation of concerns" hard-codé dans le contrat (`require(stageAgent != qgReviewer)`) ou est-ce un soft check backend ?
- Comment gérer les spécialités ? Un reviewer de smart contracts n'est pas qualifié pour reviewer du frontend React.

**Livrable attendu du cycle zq :** un **Agent Matching & Anti-Collusion Protocol** complet avec les règles d'assignation, le modèle de staking, et les contraintes on-chain vs off-chain.

---

## 7. Maturity Score

### Score : 6.5 / 10

**Justification détaillée :**

| Dimension | Score | Commentaire |
|-----------|-------|-------------|
| Core Concept | 9/10 | "Budget achète de la vérification" est clair, différenciant, et marketable |
| Smart Contract Architecture | 7/10 | WorkflowEscrow ← compose → MissionEscrow est sain. createMissionFor identifié. Manque l'implémentation réelle |
| Quality Gate Design | 6/10 | Attestation off-chain + commitment on-chain est le bon pattern. Mais le reviewer matching et l'anti-collusion sont des trous béants |
| Tier Economics | 7/10 | Les 4 tiers sont concrets avec des budget splits. Manque validation par des vrais pricing scenarios |
| Dispute Resolution | 3/10 | "Support manuel en V1" est honnête mais fragile. Pas de spécification du process |
| Agent Matching | 2/10 | Quasiment rien. C'est le risque #1 de la plateforme et on n'a pas de design |
| Implementation Readiness | 7/10 | Les phases sont ordonnées, les tests sont spécifiés. On peut commencer Phase 1 demain |
| Anti-Gaming | 3/10 | Sybil resistance, collusion prevention, reviewer quality — tout est ouvert |

**Synthèse :** On a un design solide pour le "happy path" (client crée workflow → agents exécutent → QG valide → paiement). Mais les **adversarial paths** (collusion, sybil, disputes, reviewers incompétents) sont largement non-spécifiés. On est prêt à builder les contrats core (Phases 1-3), mais **pas prêt à lancer en production** sans résoudre le matching et l'anti-collusion.

**Pour atteindre 8/10 :** résoudre le cycle zq (matching + anti-collusion) + spécifier le dispute process V1.

**Pour atteindre 9/10 :** audit externe des contrats + test avec de vrais agents sur testnet + validation pricing avec 5+ clients pilotes.