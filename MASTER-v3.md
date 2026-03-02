# Agent Marketplace — MASTER-v3.md
## Product Requirements Document (PRD) Définitif

---

## 1. Vision (3 phrases)

**L'Agent Marketplace est une plateforme décentralisée qui permet aux développeurs de déléguer des issues GitHub à des agents IA spécialisés, avec un système de paiement sécurisé en USDC et un pipeline de vérification qualité configurable par niveau de risque.**

Le différenciateur principal : **le budget achète de la densité de vérification, pas du compute**. Le client achète un SLA de qualité traçable, pas une exécution.

**Why Now :** L'émergence des agents IA autonomes (2024-2025) crée une asymétrie de confiance : les clients ne peuvent pas vérifier le code généré à grande échelle, tandis que les agents IA ont besoin d'un cadre économique crédible (escrow programmable) pour interagir sans réputation préalable. L'USDC permet des micro-paiements transfrontaliers instantanés, impossibles avec les systèmes T&M (Time & Material) traditionnels d'Upwork qui imposent des délais de paiement de 5-10 jours et des frais de change de 3-5%.

---

## 2. Le Problème — Jeff Use Case

**Jeff est un développeur solo** qui maintient un projet open source sur GitHub. Il n'a pas le temps de traiter toutes les issues, mais il veut :

1. **Déléguer** une issue technique à un agent IA fiable
2. **Payer en USDC** de manière sécurisée (escrow) sans friction bancaire ni délai de validation RH
3. **Obtenir un livrable vérifié** — pas juste du code qui "fonctionne", mais du code qui a passé des quality gates
4. **Avoir un recours** en cas de problème (dispute mechanism) avec une résolution sous 72h, contre plusieurs semaines sur les plateformes traditionnelles

**Pourquoi pas Upwork/Fiverr ?** Les plateformes traditionnelles facturent 20% de commission, imposent des virements bancaires lents, et ne fournissent aucune garantie technique automatisée sur la qualité du livrable. Jeff préfère l'USDC pour la vitesse de paiement (instantanée vs 5-10 jours), la réduction des coûts (gas < 1% vs 20% commission), et la programmabilité (paiement conditionnel à la validation d'un test automatisé, pas à la "satisfaction subjective").

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

#### 3.1.1 Layer 2 Strategy & Gas Optimization

**Choix de la chaîne : Arbitrum One**
- **Justification :** Latence ~250ms (vs 12s Ethereum), coût de calldata 8x inférieur à L1, écosystème mature d'agents IA (Bittensor, Autonolas), et disponibilité des données complète (pas de validium).
- **Modélisation coût Bronze ($5-50) :** Déploiement d'un WorkflowEscrow minimaliste (clone proxy) = ~85k gas → $0.12 à 0.2 gwei. MissionEscrow par stage = ~120k gas → $0.17. Total gas < $0.50, soit <10% d'un budget $5.
- **Factory Pattern Minimaliste :** Utilisation d'EIP-1167 proxy clones pour WorkflowEscrow et MissionEscrow. Adresse prédéterminée via CREATE2 (salt = hash(issueId + block.timestamp)) permettant au Coordinator de prédire l'adresse avant déploiement.
- **Aggregation par Batch (Future-proofing) :** Pour les micro-transactions Bronze < $10, documentation d'une voie d'évolution vers des workflows agrégés (multi-issue escrow) où 10 issues partagent le même contrat escrow avec mapping interne, réduisant le coût fixe par issue de 85k à 15k gas. Non implémenté en V1 mais architecture préparée (interface `IBatchEscrow`).

### 3.2 Architecture Off-Chain

| Décision | Justification |
|----------|----------------|
| **WorkflowCompiler comme composant dédié** | Compile (tier + issue) → WorkflowPlan. Génère le planHash soumis on-chain. |
| **Coordinator Agent** | Orchestre les stages, routing d'artefacts, timeout monitoring, agent assignment. Service production-grade, pas un script. |
| **Quality Gates = attestation off-chain + commitment on-chain** | Le smart contract ne peut pas juger la qualité. L'agent reviewer signe une attestation avec hash du rapport et score. |
| **SSOP (Structured Stage Output Protocol)** | Chaque stage produit : artifacts + reasoning + decisions + open_questions + test_hints. Format standardisé pour inter-opérabilité. |

#### 3.2.1 Coordinator Agent Architecture (RFC Technique)

**Modèle d'États Finis (Stateful)**
Le Coordinator maintient une state machine en mémoire (Redis/Raft) synchronisée avec les events on-chain :
- `IDLE` → `STAGE_ASSIGNED` → `ARTIFACTS_ROUTED` → `QG_PENDING` → `STAGE_COMPLETE` → `NEXT_STAGE` / `FAILED` / `DISPUTE`
- Chaque transition est persistée dans un WAL (Write-Ahead Log) avec checkpointing toutes les 30 secondes.

**Gestion de la Concurrence**
- **Isolation par Workflow :** Chaque workflowId est assigné à un partition logique (consistent hashing). Un seul processus Coordinator actif par workflow à un instant t (lock distribué avec TTL 5 minutes).
- **Pool d'Agents :** Le Coordinator gère une connexion WebSocket persistante avec les agents (heartbeat 30s). Capacité : 500 workflows concurrents par instance Coordinator.

**Stratégie de Failover**
- **Hot Standby :** Configuration active-passive avec replication du WAL en temps réel (PostgreSQL streaming replication). Bascullement automatique < 10s en cas de panne.
- **Timeout Management :** 
  - Heartbeat agent : 120s sans réponse → marqué offline, reassignment du stage.
  - Stage timeout : configurable par tier (Bronze: 2h, Silver: 6h, Gold: 24h). À expiration, état on-chain forcé à `DISPUTE` via fonction `timeoutStage()`.
  - Coordinator global timeout : Si aucune attestation reçue dans 2x le stage timeout, déclenchement du `emergencyHalt()` on-chain.

**Modèle de Confiance**
- **TEE (Trusted Execution Environment) :** Le Coordinator s'exécute dans un enclave Intel SGX (ou AWS Nitro Enclaves). Attestation cryptographique prouvant l'intégrité du code exécuté (pas de manipulation des scores).
- **Multi-sig Coordinator :** Chaque action critique (assignment, validation finale) est signée par 2 clés : la clé TEE du Coordinator + une clé HSM (Hardware Security Module) de secours. La clé on-chain du Coordinator est un Gnosis Safe 2/2.
- **Slashing Condition :** Si le Coordinator signe une attestation invalide (score falsifié détecté par audit ultérieur), 5% du stake est brûlé (voir 3.3.1).

**Diagramme de Séquence (Simplifié)**
```
Client -> Compiler: submitIssue(tier)
Compiler -> Coordinator: planHash + requirements
Coordinator -> OnChain: createWorkflow()
OnChain -> Coordinator: event WorkflowCreated
Coordinator -> AgentPool: requestBid(stageRequirements)
AgentPool -> Coordinator: bids[]
Coordinator -> OnChain: activateStage(agentAddress)
Agent -> Coordinator: deliverArtifacts(SSOP)
Coordinator -> ReviewerPool: requestReview(artifacts)
ReviewerPool -> Coordinator: attestationSigned(score, hash)
Coordinator -> OnChain: submitQualityGate(attestation)
OnChain -> Coordinator: event StageComplete / StageFailed
```

### 3.3 Modèle Économique

| Décision | Justification |
|----------|----------------|
| **Budget → Tier → Workflow** | Le tier est déduit du budget. Le client choisit un budget, le système recommande un workflow template. |
| **70/30 payment split** | 70% release à la complétion du stage, 30% success bonus release seulement si workflow entier réussit. Aligne les incentives. |
| **Fee graduée par tier** | Bronze: 3%, Silver: 4%, Gold: 5%, Platinum: 6%. Marge opérationnelle supérieure sur les tiers élevés. |
| **Coordination multiplier** | 1 stage: 1.0x, 2 stages: 1.15x, 3 stages: 1.25x, 4 stages: 1.35x. Capture le coût de coordination inter-stages. |

#### 3.3.1 Reviewer Incentive & Slashing

**Staking Requirement**
- Pour être eligible en tant que Reviewer, l'agent doit staker **500 USDC** minimum sur le contrat `ReviewerRegistry`.
- Période de lock : 7 jours après la dernière attestation (challenge window).

**Source de Rémunération**
- Prélèvement de 20% du platform fee (ex: sur Gold 5%, 1% va au reviewer, 4% à la plateforme).
- Paiement conditionnel : 50% à la soumission de l'attestation, 50% après 7 jours si non contesté.

**Mécanisme de Slashing (Anti-Collusion)**
- **Écart de Score :** Si l'écart entre le score reviewer et le score automated (vérité objective mesurable par les métriques de test) dépasse 20%, le reviewer est flagged.
- **Pénalité :** 
  - 1ère offense : 10% du stake locked (non récupérable).
  - 2ème offense : 50% du stake brûlé, bannissement temporaire 30 jours.
  - 3ème offense : 100% du stake brûlé, bannissement définitif (hash d'identité TEE blacklisté).
- **Rotation Cryptographique :** Pour éviter la collusion executor-reviewer, l'assignation du reviewer est déterminée par VRF (Verifiable Random Function) on-chain 2 heures avant la fin du stage. Le reviewer n'est connu que du Coordinator (TEE) jusqu'à la révélation.

**Dual Attestation Raffinée**
- Le score final est une moyenne pondérée : 60% Automated (objectif) + 40% Reviewer (subjectif).
- Si le reviewer tente de manipuler le score à la hausse pour favoriser l'executor (collusion), l'écart avec les métriques automated déclenche le slashing automatique via contrat `AttestationVerifier`.

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
- `ReviewerRegistry.sol` — Staking et slashing des reviewers (nouveau contrat minimaliste pour la gestion économique, mais dans le périmètre strict car nécessaire à la sécurité économique)

### 4.2 Off-Chain
- **WorkflowCompiler** — Compile tier + issue → WorkflowPlan avec planHash
- **Coordinator Agent** — Orchestration, timeout monitoring, agent assignment, artifact routing (architecture détaillée 3.2.1)
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

## 6. Risques Critiques et Mitigations

### 6.1 Orchestrator Design (Résolu)
**Problème :** Le Coordinator Agent est identifié comme le composant le plus complexe avec risque de SPOF.

**Mitigation :** 
- Architecture stateful avec failover hot standby (section 3.2.1).
- Checkpointing toutes les 30s (WAL).
- TEE + Multi-sig 2/2 pour les signatures critiques.
- RFC technique à livrer en Phase 2.1 (avant implémentation).

---

### 6.2 Dispute Resolution V1 (Mitigé)
**Problème :** "Admin multisig tranche manuellement" est insuffisant comme spec.

**Mitigation :**
- SLA de résolution : 72h maximum (hardcoded dans le contrat via `disputeDeadline`).
- Processus formalisé : Phase de preuve (24h), Phase de jugement (48h).
- Coût de dispute : 50 USDC (pour éviter le spam), remboursé au plaignant gagnant.
- Extension V2 : Intégration Kleros Court pour arbitrage décentralisé (interface préparée).

---

### 6.3 Artifact Pipeline (Résolu)
**Problème :** Le format des artefacts inter-stages n'est pas spécifié.

**Mitigation :**
- SSOP v1.0 spécifié en annexe (JSON Schema strict).
- IPFS pinning obligatoire pour tous les artefacts > 1KB.
- Hash des artefacts inclus dans l'attestation on-chain (section 3.2).

---

### 6.4 Matching Engine (Mitigé)
**Problème :** Comment assigner les agents aux stages (timing, cold start, anti-monopole).

**Mitigation :**
- Round-robin pondéré par réputation pour éviter la concentration.
- Cold start : nouveaux agents limités à Bronze pendant 10 missions.
- Timeout de 2h avant reassignment automatique.

---

### 6.5 Reviewer Economic Incentives (Résolu)
**Problème :** Qui paie les reviewers ? Comment les inciter à être honnêtes ?

**Mitigation :**
- Staking 500 USDC requis (section 3.3.1).
- Slashing automatique sur écart >20% avec automated scoring.
- Rémunération prélevée sur platform fee (20% du fee).
- Rotation aléatoire (VRF) pour prévenir la collusion pré-établie.

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

### Phase 2 — Quality Gates & RFC Coordinator (Semaines 3-6)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 2.1 | QualityGateAttestation struct + submitAttestation() | Phase 1 | ~8 tests |
| 2.2 | Dual attestation (40% agent / 60% automated) | 2.1 | Design doc |
| 2.3 | Retry/Abort mechanics | 2.1 | ~10 tests |
| 2.4 | Client veto + emergency halt | 2.1 | ~3 tests |
| **2.5** | **RFC Coordinator Agent (Architecture Détaillée)** | **2.1** | **Document technique avec diagrammes de séquence, états finis, stratégie failover, modèle TEE/multi-sig** |
| 2.6 | ReviewerRegistry (Staking & Slashing) | 2.2 | Contrat + tests |

**Critère de sortie** : Silver tier exécutable bout-en-bout + RFC Coordinator validé par l'équipe technique.

---

### Phase 3 — WorkflowCompiler + Orchestrator (Semaines 6-10)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 3.1 | WorkflowCompiler (tier → plan) | Phase 2 | Service |
| 3.2 | SSOP format specification | 3.1 | Schema JSON |
| 3.3 | Coordinator Agent MVP | **2.5** | Service (implémentation du RFC) |
| 3.4 | Agent matching (basic round-robin) | 3.3 | Service |
| 3.5 | TEE Setup (Intel SGX ou AWS Nitro) | 3.3 | Infrastructure |

**Critère de sortie** : Tier Bronze/Silver fonctionnels end-to-end.

---

### Phase 4 — Intégration + E2E (Semaines 10-12)

| # | Tâche | Dépendance | Livrable |
|---|-------|------------|----------|
| 4.1 | GitHub Bot v2 (tier suggestion) | Phase 3 | Bot |
| 4.2 | Dashboard client (workflow progress) | Phase 3 | UI |
| 4.3 | E2E test (Bronze → Silver → Gold) | 4.1-4.2 | Tests |
| 4.4 | Audit interne | 4.3 | Report |

**Critère de sortie** : Beta launch limité (5-10 clients).

---

## Annexe : Définitions des Tiers

| Tier | Stages | QG Threshold | Budget Range | Failure Policy | Gas Strategy |
|------|--------|--------------|--------------|----------------|--------------|
| **Bronze** | 1-2 (Code → Test) | 60/100 | $5-50 | Fail-fast, full refund | Clone proxy minimaliste (85k gas) |
| **Silver** | 2-3 (Code → Review → Test) | 75/100 | $50-500 | 1 retry + substitution | Standard deployment |
| **Gold** | 3-5 (Code → Review → Security → Test) | 85/100 | $500-2000 | 2 retries + escalation | Standard deployment |
| **Platinum** | 4-6 (Code → Review → Security → Test → Optimization → Final) | 95/100 | $2000+ | 2 retries + backup agent + partial payment | Standard deployment + Optimistic rollup batching optionnel |

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
│      ├── Vérifie signature (agent + orchestrator TEE)                  │
│      ├── Vérifie score >= threshold                                    │
│      ├── Vérifie reviewerStake > 0 (pas slashed)                       │
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
│  Architecture : Stateful (Raft/Redis) + TEE (SGX/Nitro)                │
│                                                                         │
│  • Écoute les events on-chain (Event Listener)                         │
│  • Maintient state machine par workflow (State Manager)                │
│  • Assigne les agents (Matching Engine - Round Robin)                  │
│  • Route les artefacts SSOP entre stages (Artifact Router)             │
│  • Monitor les timeouts (Timeout Watcher - 2h/6h/24h)                  │
│  • Signe avec clé TEE + HSM (Dual Signature)                           │
│  • Failover : Hot standby avec WAL replication                         │
│                                                                         │
│  Trust model:                                                           │
│  • Enclave TEE prouve l'intégrité du calcul                            │
│  • Multi-sig 2/2 (TEE + HSM) pour chaque attestation                   │
│  • Checkpointing toutes les 30s (recovery < 10s)                       │
│  • Client garde emergency veto (haltWorkflow)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    REVIEWER REGISTRY (On-chain)                         │
│  • Staking : 500 USDC minimum                                          │
│  • Lock period : 7 jours                                               │
│  • Slashing : 10%/50%/100% sur écart >20%                              │
│  • VRF rotation : assignation aléatoire des reviewers                  │
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

Reviewer Incentive (20% of 5% fee = $10 total):
- Reviewer Stage 2: $4 (40%)
- Reviewer Stage 3: $6 (60%)
- Lock 7 days, release si pas de challenge
```

---

*Document généré à partir de 21 cycles de brainstorm (za→zu) + Audit VC/CTO. Les décisions marquées ✅ ont survécu à tous les cycles avec consensus fort. Architecture Coordinator et Économie Reviewers spécifiées conformément aux exigences critiques.*