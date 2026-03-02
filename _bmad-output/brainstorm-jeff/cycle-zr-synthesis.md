

# Cycle zr — Synthesis & Decisions

---

## 1. Décisions Retenues

### 1.1 ✅ Le budget achète des couches de vérification, pas une probabilité garantie (V1)

**Justification :** Le Critic a raison — l'analogie "insurance product" est prématurée sans données actuarielles. Mais l'insight sous-jacent reste puissant : le marketplace ne vend pas du temps-agent, il vend de la **réduction de risque structurelle**. La formulation V1 correcte est :

> *"Le tier achète un nombre de couches de vérification indépendantes. Chaque couche élimine une classe de défauts. Plus il y a de couches, plus la probabilité de défaut résiduel diminue — mais on ne contractualise pas le taux tant qu'on n'a pas les données."*

**Concrètement :**
- BRONZE : 1 stage (coder seul). Aucune garantie de review. Prix le plus bas.
- SILVER : 2-3 stages (coder + reviewer, optionnel tester). Garantie de review indépendant.
- GOLD : 4-5 stages (coder + reviewer + security + tester). Garantie de review multi-dimensionnel.

Le marketing V1 dit "X couches de vérification", pas "<Y% de rework". Quand on atteint 10k missions complétées avec tracking du taux de dispute par tier, on migre vers des SLA probabilistes. C'est un **unlock data-driven**, pas un feature flag.

---

### 1.2 ✅ Pipeline séquentiel avec parallélisation partielle contrôlée

**Justification :** Le séquentiel strict est validé comme modèle mental mais le Critic a identifié un vrai killer : le temps de bout-en-bout est inacceptable pour un client enterprise. La solution n'est pas le DAG arbitraire (trop de complexité V1), mais un **séquentiel avec fan-out explicite sur certaines paires de stages**.

**Modèle retenu : "Sequential Spine with Parallel Wings"**

```
                    ┌──────────┐
                    │ Stage 0  │
                    │  CODER   │
                    └────┬─────┘
                         │
                    ┌────┴─────┐
                    │  Gate 0  │ (auto-pass ou lint/build)
                    └────┬─────┘
                         │
               ┌─────────┼─────────┐
               │                     │
         ┌─────┴──────┐      ┌──────┴───────┐
         │  Stage 1   │      │   Stage 2    │    ← PARALLEL WING
         │  REVIEWER  │      │  SECURITY    │
         └─────┬──────┘      └──────┬───────┘
               │                     │
               └─────────┬──────────┘
                         │
                    ┌────┴─────┐
                    │ Gate 1+2 │ (merge gate: BOTH must pass)
                    └────┬─────┘
                         │
                    ┌────┴─────┐
                    │ Stage 3  │
                    │  TESTER  │
                    └──────────┘
```

**Règles de parallélisation V1 :**
- Seuls les stages de **review/audit** (consommateurs read-only d'un artifact) peuvent être parallélisés entre eux
- Les stages de **production** (coder, optimizer) restent séquentiels — ils mutent l'artifact
- Le merge gate exige que **tous** les stages parallèles passent
- Si un stage parallèle fail, l'autre est **annulé** (pas de travail gaspillé)
- Max 3 stages en parallèle (au-delà, le merge gate devient ingérable)

**Impact temps :** Un workflow Gold passe de ~12-20h séquentiel pur à ~6-10h avec fan-out reviewer/security. C'est encore lent vs un dev humain pour des tâches simples, mais c'est le bon tradeoff V1 : on vend de la rigueur, pas de la vitesse.

---

### 1.3 ✅ SLA temporels par stage avec fallback automatique

**Justification :** Le Critic a identifié correctement que sans SLA temporels, un seul agent lent ou AWOL bloque tout le pipeline. C'est un risque opérationnel critique.

**Spec retenue :**

| Stage Role | SLA Default | Max Retry | Fallback |
|---|---|---|---|
| CODER | 4h | 1 | Re-assign depuis le pool |
| REVIEWER | 1h | 1 | Re-assign depuis le pool |
| SECURITY_AUDITOR | 2h | 1 | Re-assign depuis le pool |
| TESTER | 2h | 1 | Re-assign depuis le pool |
| OPTIMIZER | 3h | 0 | Stage skipped, deliver sans |

**Mécanique on-chain :**
```solidity
struct StageExecution {
    address agent;
    uint64 deadline;       // block.timestamp + SLA
    uint8 retryCount;
    StageStatus status;    // PENDING | ACTIVE | COMPLETED | TIMEOUT | FAILED
}

// Callable par anyone après deadline (bot keeper ou client)
function escalateTimeout(uint256 workflowId, uint8 stageIndex) external {
    require(block.timestamp > stages[stageIndex].deadline, "NOT_TIMED_OUT");
    // Slash small bond from timed-out agent
    // Emit event for re-assignment
    // Reset stage to PENDING with new agent
}
```

L'agent qui timeout perd un **petit bond** (pas son paiement entier — il n'a rien livré) et prend un hit de réputation. Le re-assignment est off-chain (le matcher sélectionne un nouvel agent), le stage est réinitialisé on-chain.

---

### 1.4 ✅ Quality Gates = attestation off-chain avec commitment on-chain

**Justification :** Consensus complet entre la proposition et la critique. Les gates ne peuvent pas vivre entièrement on-chain (coût gas, subjectivité du jugement). Mais le score et le hash du rapport doivent être committé on-chain pour disputabilité.

**Architecture retenue :**

```
┌──────────────────────────────────────────────────────┐
│                    OFF-CHAIN                          │
│                                                      │
│  Agent Reviewer produit :                            │
│  ├── reviewReport.json (findings, suggestions)       │
│  ├── score: uint8 (0-100)                           │
│  └── signature: sign(hash(report) || score || wfId) │
│                                                      │
│  Stocké sur : IPFS / Arweave / S3 (V1: S3 + hash)  │
└───────────────────────┬──────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────┐
│                    ON-CHAIN                           │
│                                                      │
│  submitGateResult(                                   │
│      workflowId,                                     │
│      stageIndex,                                     │
│      reportHash,    // keccak256(report)             │
│      score,         // uint8                         │
│      signature      // agent's sig                   │
│  )                                                   │
│                                                      │
│  → if score >= threshold : advanceStage()            │
│  → if score < threshold  : failStage() → retry/halt │
│  → Client can dispute within DISPUTE_WINDOW          │
└──────────────────────────────────────────────────────┘
```

---

### 1.5 ✅ WorkflowEscrow compose MissionEscrow, ne le remplace pas

**Justification :** Les 14 tests Foundry verts sur `MissionEscrow.sol` sont le socle. `WorkflowEscrow` est un **orchestrateur** qui crée/gère des missions via le contrat existant.

```
WorkflowEscrow.sol
│
├── createWorkflow(tierConfig, stages[])
│   └── Pour chaque stage : MissionEscrow.createMission(...)
│
├── advanceStage(workflowId, gateResult)
│   └── MissionEscrow.completeMission(currentStageId)
│   └── MissionEscrow.createMission(nextStageId)  // lazy creation
│
├── failStage(workflowId, reason)
│   └── MissionEscrow.cancelMission(currentStageId)
│   └── Retry logic ou halt
│
└── finalizeWorkflow(workflowId)
    └── Release remaining funds to client (if any)
```

**Pattern : lazy stage creation.** On ne crée pas toutes les missions à l'avance. Chaque mission est créée quand le stage précédent passe sa gate. Ça évite de lock du budget dans des missions qui n'existeront peut-être jamais (si le workflow échoue tôt).

---

### 1.6 ✅ Max 6 stages, hard cap on-chain

Confirmé par les deux parties. Au-delà de 6, la latence et la complexité de dispute croissent plus vite que la valeur de vérification ajoutée.

```solidity
uint8 constant MAX_STAGES = 6;
```

---

## 2. Décisions Rejetées

### 2.1 ❌ Contractualiser des SLA probabilistes au lancement

**Rejeté.** Le Critic a raison de manière définitive. Promettre "<5% de rework" sans données historiques est du vaporware actuariel. On accumule les métriques, on ne les promet pas. Le passage aux SLA probabilistes est un milestone business, pas un feature V1.

**Critère de déverrouillage :** 10k missions complétées avec tracking par tier × outcome (accepted / disputed / reworked). À ce stade, on peut calculer des intervalles de confiance réels et commencer à offrir des garanties opt-in (potentiellement avec un mécanisme de "refund partiel si SLA non atteint").

---

### 2.2 ❌ Pipeline séquentiel strict sans aucune parallélisation

**Rejeté.** Le modèle mental est séquentiel, mais l'implémentation doit supporter le fan-out partiel (§1.2). Le séquentiel pur crée un time-to-delivery inacceptable pour les tiers Gold/Silver, ce qui détruit la value proposition pour le segment qui paye le plus.

---

### 2.3 ❌ Gate scoring par l'agent du stage suivant sans garde-fous

**Rejeté.** Le Critic a identifié le conflit d'intérêt : le reviewer qui score a un incentive pervers (trouver des problèmes = justifier son existence, trigger retry = double paiement potentiel). 

**Solution retenue : découplage scoring/bénéfice**

Le reviewer est payé **forfaitairement** pour son review, qu'il passe PASS ou FAIL. Son paiement ne dépend PAS du résultat de la gate. Cela élimine l'incentive à sur-rejeter.

Concrètement :
```
Reviewer payment = fixe (sa part du budget alloué au stage)
Reviewer payment si FAIL = identique
Reviewer payment si PASS = identique
```

L'incentive du reviewer est aligné sur sa **réputation** : un reviewer qui FAIL à tort (le client dispute et gagne) prend un hit de réputation. Un reviewer qui PASS à tort (le client reçoit du code buggy) prend aussi un hit. Le reviewer est incentivé à être **calibré**, pas à sur-rejeter ou sous-rejeter.

De plus, en V1, le client a un **veto power** : il peut override une gate PASS (s'il estime que le review était complaisiant) ou challenger un gate FAIL (s'il estime que le rejet était injustifié). Ce veto est la soupape de sécurité avant que le système de réputation ne soit mature.

---

### 2.4 ❌ Quality Gates entièrement on-chain (scoring + rapport)

**Rejeté.** Confirmé définitivement. Le rapport vit off-chain, seuls le hash + score + signature sont on-chain. Le rapport complet est nécessaire uniquement en cas de dispute.

---

### 2.5 ❌ Tier pricing basé sur le coût marginal de compute

**Rejeté.** Le pricing ne reflète pas le coût des tokens LLM consommés (quasi-nul et en chute libre). Il reflète la **valeur de la structure de vérification**. Un tier Gold coûte plus cher non pas parce que les agents consomment plus de GPU, mais parce que le client obtient une structure de vérification plus profonde. Le pricing est value-based, pas cost-plus.

---

## 3. Nouveaux Insights

### 3.1 🆕 Le "Parallel Wings" pattern comme primitive d'orchestration

Les cycles précédents proposaient soit DAG arbitraire (trop complexe) soit séquentiel strict (trop lent). Le pattern "Sequential Spine with Parallel Wings" est un compromis architecturalement propre :

- Le **spine** (séquence de stages de production) reste séquentiel — garantit que chaque mutation d'artifact est atomique
- Les **wings** (stages de review/audit en parallèle) sont en fan-out — réduit la latence sans compromettre l'intégrité
- Le **merge gate** est le point de synchronisation — exige consensus de tous les reviewers parallèles

Ce pattern est implémentable on-chain sans DAG engine : c'est juste un `stageGroup` avec un `requiredPassCount == groupSize`.

```solidity
struct StageGroup {
    uint8[] stageIndices;        // [1, 2] pour reviewer + security en parallèle
    uint8 requiredPassCount;     // must equal stageIndices.length (all must pass)
    bool allCompleted;
}
```

---

### 3.2 🆕 Lazy stage creation comme pattern de capital efficiency

Ne pas créer toutes les missions on-chain au moment du workflow creation. Créer chaque mission uniquement quand la gate précédente passe. Avantages :

1. **Moins de gas** au setup (1 tx au lieu de N)
2. **Moins de capital locké** — le budget total est dans le WorkflowEscrow, pas split prématurément en N missions
3. **Flexibilité** — si le workflow fail au stage 1, les stages 2-5 n'ont jamais existé on-chain, pas de cleanup
4. **Agent assignment tardif** — l'agent du stage 3 est sélectionné quand le stage 3 est atteint, pas 6h avant. L'agent le plus pertinent/disponible à ce moment est sélectionné.

---

### 3.3 🆕 Le "calibrated reviewer" comme rôle économique distinct

Le reviewer n'est pas un agent "meilleur" que le coder. C'est un rôle économique distinct avec un profil d'incentives différent :

| Dimension | Coder | Reviewer |
|---|---|---|
| Paiement lié à | Acceptation par la gate | Forfait (indépendant du verdict) |
| Incentive primaire | Produire un artifact qui passe | Produire un jugement calibré |
| Risque principal | Rejet (perte de temps, hit réputation) | Mauvaise calibration (hit réputation) |
| Métrique de réputation | % de pass au premier essai | Corrélation verdict ↔ outcome final |

Ce découplage est critique. Les cycles précédents traitaient tous les agents comme fungibles. En réalité, un bon coder et un bon reviewer sont des profils d'agent radicalement différents, potentiellement avec des architectures de prompt, des modèles, et des spécialisations distinctes.

---

### 3.4 🆕 Le veto client comme mécanisme de bootstrap de confiance

En l'absence de données de réputation, le client est le ground truth de la qualité. Son veto (override PASS ou challenge FAIL) est le signal de training pour le futur système de réputation. Chaque veto est un datapoint. Quand le système de réputation est mature, le veto peut être progressivement restreint (coût en stake, délai, etc.) mais en V1, c'est la soupape de sécurité indispensable.

---

### 3.5 🆕 Template de tiers comme smart default, pas comme contrainte rigide

Les tiers BRONZE/SILVER/GOLD ne sont pas des configurations figées. Ce sont des **templates par défaut** que le client peut customiser :

```typescript
// Templates par défaut
const TIER_TEMPLATES = {
  BRONZE: { stages: [CODER], gates: [AUTO_PASS] },
  SILVER: { stages: [CODER, REVIEWER], gates: [AUTO_PASS, SCORE_70] },
  GOLD:   { stages: [CODER, [REVIEWER, SECURITY], TESTER], gates: [LINT, MERGE_80, SCORE_80] }
};

// Le client peut fork et ajuster
const customWorkflow = {
  base: TIER_TEMPLATES.SILVER,
  overrides: {
    gates: [AUTO_PASS, SCORE_85],  // seuil plus élevé
    addStage: TESTER               // ajouter un tester au Silver
  }
};
```

En V1, on ship les 3 templates. La customisation arrive en V1.5 quand on a du feedback sur les configurations qui marchent.

---

## 4. PRD Changes Required

### 4.1 `MASTER.md` — Section "Workflow Engine"

**Action : CRÉER** (nouvelle section)

Contenu requis :
- Définition du modèle "Sequential Spine with Parallel Wings"
- Spec des 3 tier templates (BRONZE, SILVER, GOLD) avec stages et gates
- Lazy stage creation pattern
- SLA temporels par rôle d'agent (table §1.3)
- Mécanisme d'escalation timeout (callable par anyone)

---

### 4.2 `MASTER.md` — Section "Smart Contracts Architecture"

**Action : MODIFIER**

Changements :
- Ajouter `WorkflowEscrow.sol` comme nouveau contrat composant `MissionEscrow.sol`
- Documenter le pattern de composition (WorkflowEscrow crée des missions via MissionEscrow)
- Ajouter le `StageGroup` struct pour les parallel wings
- Ajouter le mécanisme de gate attestation (hash + score + signature on-chain)
- Ajouter le `MAX_STAGES = 6` comme constante protocolaire
- Ajouter le bond + slash pour les agents qui timeout

---

### 4.3 `MASTER.md` — Section "Quality Assurance / Gates"

**Action : CRÉER** (nouvelle section)

Contenu requis :
- Architecture d'attestation (off-chain rapport + on-chain commitment)
- Découplage paiement reviewer / verdict de gate (forfait, pas conditionnel)
- Dispute window et mécanisme de veto client
- Métriques de calibration reviewer pour le futur système de réputation

---

### 4.4 `MASTER.md` — Section "Pricing / Tiers"

**Action : MODIFIER**

Changements :
- Retirer toute mention de "probabilité de rework garantie" 
- Reformuler en "couches de vérification" 
- Ajouter le milestone de transition vers SLA probabilistes (10k missions)
- Documenter que le pricing est value-based (structure de vérification), pas cost-plus (compute)

---

### 4.5 `MASTER.md` — Section "Agent Roles & Reputation"

**Action : MODIFIER**

Changements :
- Distinguer les rôles (CODER, REVIEWER, SECURITY_AUDITOR, TESTER, OPTIMIZER) comme profils économiques distincts
- Documenter les incentives différenciés par rôle
- Ajouter la métrique de calibration pour les reviewers (corrélation verdict ↔ outcome final)
- Documenter le mécanisme de re-assignment en cas de timeout

---

## 5. Implementation Priority

### Phase 1 — Fondations (Semaines 1-3)

```
Priority 1: WorkflowEscrow.sol (séquentiel pur, pas encore de parallel wings)
├── createWorkflow(stages[], budgetSplits[])
├── advanceStage(workflowId, gateAttestation)
├── failStage(workflowId)
├── finalizeWorkflow(workflowId)
├── escalateTimeout(workflowId, stageIndex)
└── Compose MissionEscrow.sol via lazy stage creation

Priority 2: Gate Attestation on-chain
├── submitGateResult(workflowId, stageIndex, reportHash, score, signature)
├── Threshold check (score >= config)
└── Dispute window placeholder (V1: client veto only)

Priority 3: Tests Foundry pour WorkflowEscrow
├── Test: workflow complet BRONZE (1 stage, happy path)
├── Test: workflow complet SILVER (2 stages, happy path)
├── Test: gate FAIL → retry
├── Test: gate FAIL → halt (max retries)
├── Test: timeout escalation + re-assignment
├── Test: client veto override
├── Test: budget split correctness
└── Test: lazy stage creation (mission N+1 n'existe pas tant que gate N n'est pas passée)
```

### Phase 2 — Parallel Wings (Semaines 4-5)

```
Priority 4: StageGroup support dans WorkflowEscrow
├── Parallel stage execution
├── Merge gate (all must pass)
├── Cancellation cascade (si un stage parallèle fail, cancel les autres)
└── Tests: workflow GOLD avec reviewer + security en parallèle

Priority 5: Tier Template Engine (off-chain)
├── 3 templates BRONZE/SILVER/GOLD
├── Template → WorkflowEscrow.createWorkflow() mapping
└── API endpoint: POST /workflows { tier: "GOLD", issueUrl: "..." }
```

### Phase 3 — Hardening (Semaines 6-8)

```
Priority 6: Agent matcher pour multi-stage
├── Sélection d'agents par rôle (CODER vs REVIEWER vs SECURITY)
├── SLA temporel par rôle
├── Re-assignment automatique en cas de timeout

Priority 7: Métriques & Observabilité
├── Tracking time-per-stage
├── Tracking taux de pass/fail par gate
├── Tracking taux de dispute par tier
├── Dashboard pour accumulation de données actuarielles

Priority 8: Client veto UX
├── Interface de veto (override PASS / challenge FAIL)
├── Dispute resolution V1 (admin arbitrage, pas Kleros)
└── Feedback loop: chaque veto alimente les métriques de calibration reviewer
```

---

## 6. Next Cycle Focus

### Question critique pour le cycle suivant :

> **Comment concevoir le système de matching multi-rôle qui assigne le bon agent au bon stage, avec quels critères de sélection, quel mécanisme de fallback, et quel modèle de bond/stake par rôle ?**

Justification : L'architecture workflow est maintenant claire. Le gap critique est l'**assignment engine** — le composant qui, pour chaque stage d'un workflow, sélectionne l'agent le plus approprié parmi le pool. C'est là que le marketplace crée ou détruit de la valeur :

- Un mauvais coder au stage 0 → tout le pipeline est corrompu, les reviewers trouvent trop de défauts, le workflow timeout ou coûte 2x en retries
- Un mauvais reviewer au stage 1 → soit faux positifs (retries inutiles, coût +), soit faux négatifs (bugs passent, client insatisfait, dispute)
- Un agent AWOL → timeout, re-assignment, latence additionnelle

Le matching engine doit prendre en compte : rôle requis, historique de l'agent sur des tâches similaires, disponibilité actuelle (pas déjà sur 5 workflows), stake/bond posté, et potentiellement compatibilité technologique (un agent spécialisé Rust ne doit pas reviewer du Solidity).

**Sous-questions :**
1. Le matching est-il un **enchère** (agents bid sur les stages) ou une **assignation** (le système sélectionne) ?
2. Comment bootstrapper le matching quand il n'y a pas de données de réputation ?
3. Le bond agent doit-il varier par rôle ? (Un coder risque plus qu'un reviewer — il produit l'artifact primaire)
4. Comment gérer la **spécialisation technologique** sans créer des marchés trop fins (fragmentation de la liquidité) ?

---

## 7. Maturity Score

### Score : 6.5 / 10

**Justification par dimension :**

| Dimension | Score | Commentaire |
|---|---|---|
| Clarté de l'architecture | 8/10 | Le modèle Spine+Wings est clair, le pattern de composition WorkflowEscrow→MissionEscrow est sain, les gates sont bien spécifiées |
| Faisabilité technique | 7/10 | Rien d'architecturalement impossible. La parallel wing ajoute de la complexité mais reste dans les capacités de Solidity. Le lazy creation est élégant |
| Viabilité économique | 5/10 | On a retiré la promesse probabiliste (bien) mais on n'a pas encore de modèle de pricing concret. Combien coûte un workflow GOLD ? Comment split-on le budget entre stages ? Le modèle de bond agent est flou |
| Robustesse adversariale | 6/10 | Le découplage paiement/verdict pour les reviewers est bon. Le veto client est une bonne soupape V1. Mais le cas "coalition coder+reviewer qui se passent des gates complaisantes" n'est pas encore traité. Le système de réputation est renvoyé au futur |
| Readiness to build | 7/10 | On peut commencer à coder le WorkflowEscrow séquentiel (Phase 1) dès maintenant. Les specs sont suffisamment précises pour écrire les tests Foundry |
| Gaps critiques restants | 5/10 | Le matching engine est un trou béant. Le pricing concret manque. Le dispute resolution V1 est "admin arbitrage" ce qui ne scale pas. La question de la spécialisation technologique des agents est non-adressée |

**Pourquoi pas 7+ :** Parce que le matching engine (comment on assigne le bon agent au bon stage) est le cœur du marketplace et il est encore un placeholder. Sans matching intelligent, les workflows vont échouer par mauvaise assignation plus souvent que par mauvaise architecture. L'architecture est prête ; l'opérationnel ne l'est pas.

**Ce qu'il faut pour atteindre 8/10 :**
1. Spec complète du matching engine (cycle suivant)
2. Modèle de pricing concret avec simulation sur 3 scénarios (small fix, medium feature, large refactor)
3. Mécanisme anti-collusion coder-reviewer (au minimum : ne pas assigner deux agents du même opérateur sur le même workflow)