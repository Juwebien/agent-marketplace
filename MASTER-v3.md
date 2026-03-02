# Agent Marketplace — MASTER-v3.md
## Product Requirements Document (PRD) Définitif

---

## 1. Vision (3 phrases)

**L'Agent Marketplace est une plateforme décentralisée qui permet aux développeurs de déléguer des issues GitHub à des agents IA spécialisés, avec un système de paiement sécurisé en USDC et un pipeline de vérification qualité configurable par niveau de risque.**

Le différenciateur principal : **le budget achète de la densité de vérification, pas du compute**. Le client achète un SLA de qualité traçable, pas une exécution.

---

## 2. Le Problème — Jeff Use Case

**Jeff est un développeur solo** qui maintient un projet open source sur GitHub. Il n'a pas le temps de traiter toutes les issues, mais il veut :

1. **Déléguer** une issue technique à un agent IA fiable
2. **Payer en USDC** de manière sécurisée (escrow)
3. **Obtenir un livrable vérifié** — pas juste du code qui "fonctionne", mais du code qui a passé des quality gates
4. **Avoir un recours** en cas de problème (dispute mechanism)

**Le workflow typique Jeff :**
1. Crée une issue GitHub avec un budget
2. Choisit un niveau de vérification (Bronze → Platinum)
3. Le système génère un workflow (plan de stages)
4. Les agents IA exécutent les stages séquentiellement
5. Chaque stage passe un quality gate
6. À la fin, Jeff reçoit un livrable avec audit trail complet
7. Les fonds sont libérés progressivement ou refundés en cas d'échec

---

## 3. Décisions Architecturales Définitives

### 3.1 Architecture On-Chain

| Décision | Justification |
|----------|----------------|
| **WorkflowEscrow compose MissionEscrow, ne le remplace pas** | Préserve les 14 tests Foundry existants. MissionEscrow est l'unité atomique de paiement. WorkflowEscrow est l'orchestrateur. |
| **Le contrat est une Finite State Machine financière, pas un workflow engine** | Chaque transition a un impact monétaire direct. L'orchestration vit off-chain dans le Coordinator Agent. |
| **Max 6 stages par workflow** | Guard-rail empirique. Au-delà, latence, coût, et surface de dispute explosent. |
| **Budget en BPS (basis points)** | Standard DeFi. `uint16` = granularité 0.01%. |
| **Plan hash comme engagement immutable** | Une fois créé on-chain, ni plateforme ni agent ne peuvent modifier les termes. |

### 3.2 Architecture Off-Chain

| Décision | Justification |
|----------|----------------|
| **WorkflowCompiler comme composant dédié** | Compile (tier + issue) → WorkflowPlan. Génère le planHash soumis on-chain. |
| **Coordinator Agent** | Orchestre les stages, routing d'artefacts, timeout monitoring, agent assignment. Service production-grade, pas un script. |
| **Quality Gates = attestation off-chain + commitment on-chain** | Le smart contract ne peut pas juger la qualité. L'agent reviewer signe une attestation avec hash du rapport et score. |
| **SSOP (Structured Stage Output Protocol)** | Chaque stage produit : artifacts + reasoning + decisions + open_questions + test_hints. Format standardisé pour inter-opérabilité. |

### 3.3 Modèle Économique

| Décision | Justification |
|----------|----------------|
| **Budget → Tier → Workflow** | Le tier est déduit du budget. Le client choisit un budget, le système recommande un workflow template. |
| **70/30 payment split** | 70% release à la complétion du stage, 30% success bonus release seulement si workflow entier réussit. Aligne les incentives. |
| **Fee graduée par tier** | Bronze: 3%, Silver: 4%, Gold: 5%, Platinum: 6%. Marge opérationnelle supérieure sur les tiers élevés. |
| **Coordination multiplier** | 1 stage: 1.0x, 2 stages: 1.15x, 3 stages: 1.25x, 4 stages: 1.35x. Capture le coût de coordination inter-stages. |

### 3.4 Quality Gates

| Décision | Justification |
|----------|----------------|
| **Dual attestation (40% agent / 60% automated)** | La composante automated est objective. La composante agent capture le jugement qualitatif. |
| **Seuils hardcodés par tier** | Bronze: 60, Silver: 75, Gold: 85, Platinum: 95. Évite le gaming par clients. |
| **Reviewer != Executor** | Contrainte on-chain : `require(reviewer != stageAgent)`. Anti-collusion. |
| **Chaîne d'attestations** | Chaque attestation référence `prevAttestationHash`. Traçabilité en cas de dispute. |

### 3.5 Failure Handling

| Décision | Justification |
|----------|----------------|
| **Failure policy tier-dépendante** | Bronze: fail-fast (0 retry), Silver: 1 retry, Gold: 2 retries + escalation, Platinum: 2 retries + backup agent |
| **Max 2 retries par stage** | Hard cap. Au-delà, workflow abort. |
| **Refund proportionnel** | Stages complétés = payés. Stage actif = en cours de résolution. Stages futurs = refund immédiat. |

---

## 4. Périmètre Strict — Ce que le Produit FAIT

### 4.1 Smart Contracts
- `MissionEscrow.sol` — Escrow atomique par mission (inchangé, 323 lignes, 14 tests)
- `WorkflowEscrow.sol` — Orchestration multi-stage, budget lock/release, quality gate verification
- `AgentRegistry.sol` — Identité agents, capabilities, réputation
- `WorkflowRegistry.sol` — Stockage des définitions de workflows
- `GateAttestationStore.sol` — Stockage des attestations (hash, score, signatures)

### 4.2 Off-Chain
- **WorkflowCompiler** — Compile tier + issue → WorkflowPlan avec planHash
- **Coordinator Agent** — Orchestration, timeout monitoring, agent assignment, artifact routing
- **Quality Gate Pipeline** — Exécution des checks automated + agent review, production des attestations
- **Tier Presets** — Bronze (1-2 stages), Silver (2-3 stages), Gold (3-5 stages), Platinum (4-6 stages)

### 4.3 Interactions
- GitHub Bot — Issue → tier suggestion → workflow creation
- Agent SDK — Agents IA interagissent avec le système via API REST + webhooks
- IPFS — Stockage des rapports de review, artefactual, audit trails

---

## 5. Hors Scope Explicite — Ce que le Produit NE FAIT PAS

| Exclus | Raison |
|---------|--------|
| **DAG arbitraire** | Complexité excessive. V1 = pipeline séquentiel. V2+ si données le justifient. |
| **Parallel Fan-out en V1** | Join synchronization non résolue. Reporté à V1.5. |
| **Conditional branching on-chain** | Transforme le contrat en DAG engine. Géré off-chain uniquement. |
| **Arbitrage décentralisé (Kleros/UMA) en V1** | Trop complexe. V1 = admin multisig, V2 = arbitrage décentralisé. |
| **Quality Gates entirely on-chain** | Coût gas prohibitif, oracle problem non résolu. |
| **Budget reallocation dynamique** | Surface d'attaque trop grande. Budget fixe une fois committé. |
| **Tier customizable par client** | Les tiers sont des presets figés. Le client peut ajuster dans les bornes (10%-60% par stage). |
| **Tier comme SLA statistique** | V1 = promesse structurelle (nombre de vérifications). V2 = promesse statistique (taux de rework calibrés sur données réelles). |
| **Matching完全 automatique** | Matching stage-by-stage, mais client peut override. |

---

## 6. Risques Critiques Non Résolus

### 6.1 Orchestrator Design (Critique)
**Problème** : Le Coordinator Agent est identifié comme le composant le plus complexe mais pas encore designé en détail.

**Impact** : Sans orchestrateur, les stages ne communiquent pas, les timeouts ne sont pas gérés, les agents ne sont pas assignés.

**Statut** : Non résolu. Nécessite un cycle de design dédié.

---

### 6.2 Dispute Resolution V1 (Élevé)
**Problème** : "Admin multisig tranche manuellement" est insuffisant comme spec.

**Impact** : Pas de SLA de résolution, pas de processus formalisé, pas de coût de dispute.

**Statut** : Partiellement résolu. V1 = freeze + admin. V2 = Kleros/UMA.

---

### 6.3 Artifact Pipeline (Élevé)
**Problème** : Le format des artefacts inter-stages n'est pas spécifié.

**Impact** : Le reviewer ne peut pas évaluer le travail du coder sans contexte.

**Statut** : SSOP identifié mais format pas finalisé (artefacts + reasoning + decisions + open_questions + test_hints).

---

### 6.4 Matching Engine (Moyen)
**Problème** : Comment assigner les agents aux stages (timing, cold start, anti-monopole).

**Impact** : Si aucun agent disponible pour un stage, workflow bloqué.

**Statut** : Identifié mais pas spécifié. Matching stage-by-stage adopté.

---

### 6.5 Reviewer Economic Incentives (Moyen)
**Problème** : Qui paie les reviewers ? Comment les inciter à être honnêtes ?

**Impact** : Les reviewers peuvent être corrompus ou lazy.

**Statut** : Dual attestation (40/60) help mais pas complètement résolu.

---

## 7. Next Steps Priorisés

### Phase 1 — Fondations On-Chain (Semaines 1-3) — PRIORITÉ HAUTE

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 1.1 | Ajouter rôle WORKFLOW_OPERATOR à MissionEscrow | Aucune | PR + 2 tests |
| 1.2 | Struct WorkflowPlan on-chain (planHash, tier, stageCount) | 1.1 | ~5 tests |
| 1.3 | createWorkflow() — validation, budget lock, stage init | 1.2 | ~8 tests |
| 1.4 | WorkflowEscrow.sol — FSM complète | 1.3 | ~20 tests |
| 1.5 | Non-régression MissionEscrow (14 tests verts) | 1.4 | ✅ |

**Critère de sortie** : Pipeline Bronze fonctionnel (2 stages) avec tests Foundry.

---

### Phase 2 — Quality Gates (Semaines 3-5)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 2.1 | QualityGateAttestation struct + submitAttestation() | Phase 1 | ~8 tests |
| 2.2 | Dual attestation (40% agent / 60% automated) | 2.1 | Design doc |
| 2.3 | Retry/Abort mechanics | 2.1 | ~10 tests |
| 2.4 | Client veto + emergency halt | 2.1 | ~3 tests |

**Critère de sortie** : Silver tier exécutable bout-en-bout.

---

### Phase 3 — WorkflowCompiler + Orchestrator (Semaines 5-7)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 3.1 | WorkflowCompiler (tier → plan) | Phase 2 | Service |
| 3.2 | SSOP format specification | 3.1 | Schema JSON |
| 3.3 | Coordinator Agent MVP | 3.2 | Service |
| 3.4 | Agent matching (basic round-robin) | 3.3 | Service |

**Critère de sortie** : Tier Bronze/Silver fonctionnels end-to-end.

---

### Phase 4 — Intégration + E2E (Semaines 7-8)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 4.1 | GitHub Bot v2 (tier suggestion) | Phase 3 | Bot |
| 4.2 | Dashboard client (workflow progress) | Phase 3 | UI |
| 4.3 | E2E test (Bronze → Silver → Gold) | 4.1-4.2 | Tests |
| 4.4 | Audit interne | 4.3 | Report |

**Critère de sortie** : Beta launch limité (5-10 clients).

---

## Annexe : Définitions des Tiers

| Tier | Stages | QG Threshold | Budget Range | Failure Policy |
|------|--------|--------------|--------------|----------------|
| **Bronze** | 1-2 (Code → Test) | 60/100 | $5-50 | Fail-fast, full refund |
| **Silver** | 2-3 (Code → Review → Test) | 75/100 | $50-500 | 1 retry + substitution |
| **Gold** | 3-5 (Code → Review → Security → Test) | 85/100 | $500-2000 | 2 retries + escalation |
| **Platinum** | 4-6 (Code → Review → Security → Test → Optimization → Final) | 95/100 | $2000+ | 2 retries + backup agent + partial payment |

---

## Annexe : Architecture Détaillée

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT                                        │
│  (Jeff, développeur solo)                                            │
│    │                                                                    │
│    ├── Connecte GitHub                                                 │
│    ├── Crée une issue                                                  │
│    ├── Choisit budget + tier                                           │
│    └── Reçoit livrable + audit trail                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW COMPILER (Off-chain)                        │
│  • Compile (tier + issue) → WorkflowPlan                               │
│  • Génère planHash = keccak256(plan)                                   │
│  • Upload plan sur IPFS                                                 │
│  • Retourne planHash + planURI                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOWESCROW.SOL (On-chain)                       │
│                                                                         │
│  createWorkflow(planHash, planURI, stages[], budgetBps[])              │
│      │                                                                  │
│      ├── Lock totalBudget USDC                                         │
│      ├── Enregistre stages[] avec budgetBps                            │
│      ├── Plan hash immutable                                           │
│      └── Émet WorkflowCreated event                                    │
│                                                                         │
│  activateStage(workflowId, stageIndex)                                 │
│      │                                                                  │
│      ├── Crée MissionEscrow pour le stage                              │
│      ├── Lock budget du stage                                          │
│      └── Émet StageStarted event                                       │
│                                                                         │
│  submitQualityGate(workflowId, stageIndex, attestation)                │
│      │                                                                  │
│      ├── Vérifie signature (agent + orchestrator)                      │
│      ├── Vérifie score >= threshold                                    │
│      ├── Si pass: advanceStage()                                        │
│      ├── Si fail: failStage()                                          │
│      └── Émet QualityGateResult event                                  │
│                                                                         │
│  retryStage(workflowId, stageIndex)                                    │
│      │                                                                  │
│      ├── Vérifie retryCount < maxRetries                                │
│      └── Reset stage state                                             │
│                                                                         │
│  abortWorkflow(workflowId)                                              │
│      │                                                                  │
│      ├── Refund stages non-startés                                      │
│      └── Paiement stages complétés (irréversible)                      │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    MISSIONESCROW.SOL (On-chain)                         │
│  (Inchangé : 323 lignes, 14 tests)                                    │
│                                                                         │
│  createMission(agent, budget, deadline)                                │
│  acceptMission()                                                        │
│  deliverMission()                                                       │
│  approveMission() / disputeMission()                                    │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    COORDINATOR AGENT (Off-chain)                        │
│                                                                         │
│  • Écoute les events on-chain                                          │
│  • Assigne les agents aux stages (matching)                            │
│  • Route les artefacts entre stages (SSOP)                             │
│  • Monitor les timeouts                                                 │
│  • Décide retry / abort / escalation                                   │
│  • Gère les disputes (collecte preuves)                                │
│                                                                         │
│  Trust model:                                                           │
│  • Signe chaque action avec clé enregistrée on-chain                    │
│  • Client garde emergency veto (haltWorkflow)                           │
│  • Attestations co-signées (agent + orchestrator)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Annexe : Budget Split Exemple (Gold, $1000)

```
Budget total: $1000 (après platform fee 5% = $50)

Stage 1 (Code):      4000 bps = $400
Stage 2 (Review):   2500 bps = $250  
Stage 3 (Security):  2000 bps = $200
Stage 4 (Test):     1500 bps = $150

Coordination multiplier (3 stages): 1.25x
Tier margin (Gold): 1.2x

Total after multipliers: $1000 ✅

Payment per stage:
- Immediate (70%): $280 / $175 / $140 / $105
- Success bonus (30%): $120 / $75 / $60 / $45
  (released only on full workflow completion)
```

---

*Document généré à partir de 21 cycles de brainstorm (za→zu). Les décisions marquées ✅ ont survécu à tous les cycles avec consensus fort.*
