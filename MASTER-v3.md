#XZ|# Agent Marketplace — MASTER-v3.md
#MY|## Product Requirements Document (PRD) Définitif
#HW|
#ZM|---
#JS|## 1. Vision (3 phrases)
#SY|
#RV|**L'Agent Marketplace est une plateforme décentralisée qui permet aux développeurs de déléguer des issues GitHub à des agents IA spécialisés, avec un système de paiement sécurisé en USDC et un pipeline de vérification qualité configurable par niveau de risque.**
#XW|
#YJ|Le différenciateur principal : **le budget achète de la densité de vérification, pas du compute**. Le client achète un SLA de qualité traçable, pas une exécution.
#SK|
#NR|**Why Now :** L'émergence des agents IA autonomes (2024-2025) crée une asymétrie de confiance : les clients ne peuvent pas vérifier le code généré à grande échelle, tandis que les agents IA ont besoin d'un cadre économique crédible (escrow programmable) pour interagir sans réputation préalable. L'USDC permet des micro-paiements transfrontaliers instantanés, impossibles avec les systèmes T&M (Time & Material) traditionnels d'Upwork qui imposent des délais de paiement de 5-10 jours et des frais de change de 3-5%.
#TX|
#SV|---
#TZ|## 2. Le Problème — Jeff Use Case
#RJ|
#RN|**Jeff est un développeur solo** qui maintient un projet open source sur GitHub. Il n'a pas le temps de traiter toutes les issues, mais il veut :
#HX|
#VH|1. **Déléguer** une issue technique à un agent IA fiable
#QM|2. **Payer en USDC** de manière sécurisée (escrow) sans friction bancaire ni délai de validation RH
#BQ|3. **Obtenir un livrable vérifié** — pas juste du code qui "fonctionne", mais du code qui a passé des quality gates
#JZ|4. **Avoir un recours** en cas de problème (dispute mechanism) avec une résolution sous 72h, contre plusieurs semaines sur les plateformes traditionnelles
#ZP|
#SP|**Pourquoi pas Upwork/Fiverr ?** Les plateformes traditionnelles facturent 20% de commission, imposent des virements bancaires lents, et ne fournissent aucune garantie technique automatisée sur la qualité du livrable. Jeff préfère l'USDC pour la vitesse de paiement (instantanée vs 5-10 jours), la réduction des coûts (gas < 1% vs 20% commission), et la programmabilité (paiement conditionnel à la validation d'un test automatisé, pas à la "satisfaction subjective").
#KW|
#KY|**Le workflow typique Jeff :**
#TQ|1. Crée une issue GitHub avec un budget
#NJ|2. Choisit un niveau de vérification (Bronze → Platinum)
#MJ|3. Le système génère un workflow (plan de stages)
#HN|4. Les agents IA exécutent les stages séquentiellement
#YR|5. Chaque stage passe un quality gate
#SY|6. À la fin, Jeff reçoit un livrable avec audit trail complet
#TY|7. Les fonds sont libérés progressivement ou refundés en cas d'échec
#QY|
#HX|**Le cas d'échec total :** Si tous les agents sont HS (infrastructure down, bug critique, ou AI blackout), le workflow passe automatiquement en état `EMERGENCY_ABORT` après 2x le stage timeout maximum (48h pour Platinum). Le refund est immédiat et complet — le client ne perd jamais plus que le budget engagé.
#TX|
#XM|---
#YX|## 3. Décisions Architecturales Définitives
#BN|
#NH|### 3.1 Architecture On-Chain
#ZK|
#MX|| Décision | Justification |
#XB||----------|----------------|
#KV|| **WorkflowEscrow compose MissionEscrow, ne le remplace pas** | Préserve les 14 tests Foundry existants. MissionEscrow est l'unité atomique de paiement. WorkflowEscrow est l'orchestrateur. |
#YP|| **Le contrat est une Finite State Machine financière, pas un workflow engine** | Chaque transition a un impact monétaire direct. L'orchestration vit off-chain dans les services d'orchestration. |
#HS|| **Max 6 stages par workflow** | Guard-rail empirique. Au-delà, latence, coût, et surface de dispute explosent. |
#QY|| **Budget en BPS (basis points)** | Standard DeFi. `uint16` = granularité 0.01%. |
#SH|| **Plan hash comme engagement immutable** | Une fois créé on-chain, ni plateforme ni agent ne peuvent modifier les termes. |
#BY|
#SX|#### 3.1.1 Layer 2 Strategy & Gas Optimization
#QW|
#YN|**Choix de la chaîne : Arbitrum One**
#MZ|- **Justification :** Latence ~250ms (vs 12s Ethereum), coût de calldata 8x inférieur à L1, écosystème mature d'agents IA (Bittensor, Autonolas), et disponibilité des données complète (pas de validium).
#HT|- **Modélisation coût Bronze ($5-50) :** Déploiement d'un WorkflowEscrow minimaliste (clone proxy) = ~85k gas → $0.12 à 0.2 gwei. MissionEscrow par stage = ~120k gas → $0.17. Total gas < $0.50, soit <10% d'un budget $5.
#YH|- **Factory Pattern Minimaliste :** Utilisation d'EIP-1167 proxy clones pour WorkflowEscrow et MissionEscrow. Adresse prédéterminée via CREATE2 (salt = hash(issueId + block.timestamp)) permettant au Coordinator de prédire l'adresse avant déploiement.
#JK|- **Aggregation par Batch (Future-proofing) :** Pour les micro-transactions Bronze < $10, documentation d'une voie d'évolution vers des workflows agrégés (multi-issue escrow) où 10 issues partagent le même contrat escrow avec mapping interne, réduisant le coût fixe par issue de 85k à 15k gas. Non implémenté en V1 mais architecture préparée (interface `IBatchEscrow`).
#XN|
#VP|### 3.2 Architecture Off-Chain
#KR|
#MX|| Décision | Justification |
#RV||----------|----------------|
#JT|| **WorkflowCompiler comme composant dédié** | Compile (tier + issue) → WorkflowPlan. Génère le planHash soumis on-chain. |
#JH|| **StageOrchestrator** | Orchestration des stages, timeout monitoring, transitions d'état. |
#TW|| **MatchingEngine** | Assignation des agents aux stages, gestion du pool, cold start. |
#YT|| **AttestationSigner** | Signature des attestations, validation qualité, interaction TEE. |
#WW|| **Quality Gates = attestation off-chain + commitment on-chain** | Le smart contract ne peut pas juger la qualité. L'agent reviewer signe une attestation avec hash du rapport et score. |
#WW|| **SSOP (Structured Stage Output Protocol)** | Chaque stage produit : artifacts + reasoning + decisions + open_questions + test_hints. Format standardisé pour inter-opérabilité. |
#TH|
#ZV|#### 3.2.1 Services d'Orchestration — Architecture Découpée
#KB|
#VJ|Le Coordinator original (6 responsabilités) est découpé en **3 services distincts** pour **éliminer le Single Point of Failure (SPOF)** et permettre une scalabilité indépendante :
#PR|
#XT|---
#HV|
#SJ|**3.2.1.1 StageOrchestrator**
#SZ|
#JV|**Responsabilités :**
#KJ|- Maintien de la state machine par workflow (coordination des transitions)
#RQ|- Gestion des timeouts (stage timeout, workflow timeout, emergency halt)
#KW|- Routing des événements on-chain vers les autres services
#KR|- Coordination inter-services (publish/subscribe)
#JQ|
#TV|**SPOF Mitigation :**
#ZV|- Chaque workflow est assigné à un partition unique via consistent hashing
#QS|- Lock distribué avec TTL 5 minutes — si un orchestrator crash, le lock expire et un autre peut reprendre
#QK|- **Hot standby** avec WAL replication — basculement < 10 secondes
#TV|
#TV|**Modèle d'États Finis (Stateful)**
#JW|Le StageOrchestrator maintient une state machine en mémoire (Redis/Raft) synchronisée avec les events on-chain :
#YK|- `IDLE` → `STAGE_ASSIGNED` → `ARTIFACTS_ROUTED` → `QG_PENDING` → `STAGE_COMPLETE` → `NEXT_STAGE` / `FAILED` / `DISPUTE`
#ZM|- Chaque transition est persistée dans un WAL (Write-Ahead Log) avec checkpointing toutes les 30 secondes.
#KR|
#NQ|**Gestion de la Concurrence**
#JZ|- **Isolation par Workflow :** Chaque workflowId est assigné à un partition logique (consistent hashing). Un seul processus StageOrchestrator actif par workflow à un instant t (lock distribué avec TTL 5 minutes).
#QS|- **Capacité :** 500 workflows concurrents par instance StageOrchestrator.
#QT|
#BK|**Stratégie de Failover**
#QZ|- **Hot Standby :** Configuration active-passive avec replication du WAL en temps réel (PostgreSQL streaming replication). Basculement automatique < 10s en cas de panne.
#VT|- **Timeout Management :**
#VS|  - Heartbeat agent : 120s sans réponse → marqué offline, reassignment.
#MH|  - Stage timeout : configurable par tier (Bronze: 2h, Silver: 6h, Gold: 24h). À expiration, état on-chain forcé à `DISPUTE` via fonction `timeoutStage()`.
#HT|  - Global timeout : Si aucune attestation reçue dans 2x le stage timeout, déclenchement du `emergencyHalt()` on-chain.
#ZT|
#RS|**Interface :**
#ZZ|```solidity
#WM|interface IStageOrchestrator {
#YZ|    function requestStageTransition(uint256 workflowId, uint8 targetStage, bytes calldata context) external;
#PR|    function handleStageTimeout(uint256 workflowId, uint8 stageIndex) external;
#XS|    function handleEmergencyHalt(uint256 workflowId) external;
#VV|}
#ZP|```
#HT|
#NR|---
#YQ|
#XM|**3.2.1.2 MatchingEngine**
#BQ|
#JV|**Responsabilités :**
#XN|- Gestion du pool d'agents (inscription, capacités, réputation)
#PX|- Assignment des agents aux stages (round-robin, cold start logic)
#PN|- Gestion des rebids et reassignments
#NM|- Anti-concentration (éviter monopole)
#WY|
#WJ|**SPOF Mitigation :**
#QT|- Pool d'agents répliqué en lecture — si le MatchingEngine principal crash, les assignations peuvent être reconstruites depuis l'event log on-chain
#QZ|- **Isolation du matching** : Chaque stage peut utiliser une stratégie de matching différente sans coupler avec l'orchestration
#BK|
#WJ|**Stratégie de Matching**
#VJ|- **Round-robin pondéré :** Les agents sont sélectionnés en rotation pondérée par score de réputation (0-100).
#BY|- **Cold Start :** Les nouveaux agents sont limités à Bronze pendant 10 missions.
#XX|- **Anti-Monopole :** Un agent ne peut pas avoir plus de 30% des missions sur une période de 7 jours.
#TR|- **Timeout :** 2h avant reassignment automatique si pas de réponse.
#HP|
#RS|**Interface :**
#ZZ|```solidity
#HQ|interface IMatchingEngine {
#TY|    function requestBid(uint256 workflowId, uint8 stageIndex, StageRequirements calldata req) external returns (bytes32 bidId);
#YN|    function assignAgent(uint256 workflowId, uint8 stageIndex, address agent) external returns (bool);
#QT|    function reassignAgent(uint256 workflowId, uint8 stageIndex) external returns (address newAgent);
#SM|    function getAgentReputation(address agent) external view returns (uint8);
#QP|}
#RY|```
#QR|
#NS|---
#WX|
#XX|**3.2.1.3 AttestationSigner**
#PY|
#JV|**Responsabilités :**
#HJ|- Validation des quality gates
#VK|- Signature des attestations (score, hash rapport)
#SN|- Interaction avec le TEE pour intégrité
#YX|- Signature duale (TEE + HSM)
#JT|
#JT|**SPOF Mitigation :**
#YW|- **Dual signature (TEE + HSM)** : Si le TEE est compromis, la clé HSM de secours peut encore signer
#ZR|- **Gnosis Safe 2/2** : Requiert 2 signatures pour toute attestation — compromission d'une clé insuffisante
#ZS|- **Slashing condition** : 5% du stake brûlé si falsification détectée — incitation économique à l'honnêteté
#JR|
#JR|**Modèle de Confiance**
#HT|- **TEE (Trusted Execution Environment) :** Le AttestationSigner s'exécute dans un enclave Intel SGX (ou AWS Nitro Enclaves). Attestation cryptographique prouvant l'intégrité du code exécuté (pas de manipulation des scores).
#HZ|- **Multi-sig :** Chaque attestation est signée par 2 clés : la clé TEE + une clé HSM (Hardware Security Module) de secours. La clé on-chain est un Gnosis Safe 2/2.
#KB|- **Slashing Condition :** Si le AttestationSigner signe une attestation invalide (score falsifié détecté par audit ultérieur), 5% du stake est brûlé (voir 3.3.1).
#JB|
#YW|**Dual Attestation Raffinée**
#BM|- Le score final est une moyenne pondérée : 60% Automated (objectif) + 40% Reviewer (subjectif).
#XM|- Si le reviewer tente de manipulator le score à la hausse pour favoriser l'executor (collusion), l'écart avec les métriques automated déclenche le slashing automatique via contrat `AttestationVerifier`.
#NX|
#RS|**Interface :**
#ZZ|```solidity
#RB|interface IAttestationSigner {
#YJ|    function submitAttestation(uint256 workflowId, uint8 stageIndex, Attestation calldata attestation) external returns (bool);
#YV|    function verifyDualAttestation(uint256 workflowId, uint8 stageIndex, bytes calldata automatedMetrics) external view returns (bool);
#KR|    function slashReviewer(address reviewer, uint8 offenseCount) external;
#SW|}
#MR|```
#RT|
#MM|---
#QN|
#SX|**Communication Inter-Services**
#HN|
#RV|Les 3 services communiquent via **message queue** (RabbitMQ ou Kafka) pour **découplage maximal** :
#XH|
#XH|```
#JK|StageOrchestrator ──(stage.transition)──► MatchingEngine
#NK|StageOrchestrator ──(attestation.request)──► AttestationSigner
#VK|MatchingEngine ──(agent.assigned)──► StageOrchestrator
#YB|AttestationSigner ──(attestation.signed)──► StageOrchestrator
#XN|```
#JZ|
#BM|**Découplage des pannes :**
#NM|- Si un service crash, les autres services timeout après 30s et passent le workflow en `DISPUTE`
#NV|- Chaque service a son propre hot standby — défaillance isolée
#BN|- **Circuit breaker** : Si un service dépasse 50% d'échecs, il est isolé automatiquement
#VS|---
#PZ|
#PV|### 3.3 Modèle Économique
#QQ|
#MX|| Décision | Justification |
#WX||----------|----------------|
#TY|| **Budget → Tier → Workflow** | Le tier est déduit du budget. Le client choisit un budget, le système recommande un workflow template. |
#VY|| **70/30 payment split** | 70% release à la complétion du stage, 30% success bonus release seulement si workflow entier réussit. Aligne les incentives. |
#PK|| **Fee graduée par tier** | Bronze: 3%, Silver: 4%, Gold: 5%, Platinum: 6%. Marge opérationnelle supérieure sur les tiers élevés. |
#JH|| **Coordination multiplier** | 1 stage: 1.0x, 2 stages: 1.15x, 3 stages: 1.25x, 4 stages: 1.35x. Capture le coût de coordination inter-stages. |
#XH|
#VT|#### 3.3.1 Reviewer Incentive & Slashing
#JM|
#TS|**Staking Requirement**
#QB|- Pour être eligible en tant que Reviewer, l'agent doit staker **500 USDC** minimum sur le contrat `ReviewerRegistry`.
#RY|- Période de lock : 7 jours après la dernière attestation (challenge window).
#QX|
#YP|**Source de Rémunération**
#YZ|- Prélèvement de 20% du platform fee (ex: sur Gold 5%, 1% va au reviewer, 4% à la plateforme).
#BY|- Paiement conditionnel : 50% à la soumission de l'attestation, 50% après 7 jours si non contesté.
#JR|
#VV|**Mécanisme de Slashing (Anti-Collusion)**
#WJ|- **Écart de Score :** Si l'écart entre le score reviewer et le score automated (vérité objective mesurable par les métriques de test) dépasse 20%, le reviewer est flagged.
#NQ|- **Pénalité :**
#PM|  - 1ère offense : 10% du stake locked (non récupérable).
#RX|  - 2ème offense : 50% du stake brûlé, bannissement temporaire 30 jours.
#PY|  - 3ème offense : 100% du stake brûlé, bannissement définitif (hash d'identité TEE blacklisté).
#KX|- **Rotation Cryptographique :** Pour éviter la collusion executor-reviewer, l'assignation du reviewer est déterminée par VRF (Verifiable Random Function) on-chain 2 heures avant la fin du stage. Le reviewer n'est connu que du Coordinator (TEE) jusqu'à la révélation.
#VY|
#BV|#### 3.3.2 Economics V1 — Coûts et Infrastructure
#PT|
#NB|Cette section détaille les coûts opérationnels réels pour le running de la V1.
#HB|
#TV|**A. Infrastructure Coûts (Monthly)**
#MT|
#NY|| Composant | Coût Mensuel | Justification |
#MW||-----------|--------------|----------------|
#QN|| **AWS Nitro Enclaves (TEE)** | $5,000 | 3 instances t3.large avec Nitro (pour haute disponibilité). Inclut le coût SGX provisioning. |
#PX|| **PostgreSQL (RDS)** | $800 | Multi-AZ pour failover state. 500GB storage. |
#RH|| **Redis (ElastiCache)** | $400 | State machine + cache. 3 nodes cluster. |
#PK|| **Message Queue (RabbitMQ)** | $300 | 3 nodes cluster pour inter-service comm. |
#XM|| **GitHub Actions / CI** | $400 | 50,000 minutes/month. |
#XR|| **Monitoring (Datadog)** | $600 | Logs, metrics, APM pour 3 services. |
#VS|| **Domain + DNS** | $50 | Route53 + Cloudflare. |
#JM|| **Arbitrum RPC (Infura/Alchemy)** | $200 | Tier Business pour fiabilité. |
#XW|| **IPFS Pinning (Pinata)** | $250 | 100GB storage + bandwidth. |
#TP|| **TOTAL** | **$8,000/mo** | — |
#WJ|
#YR|**B. USDC Liquidity Requirement (Escrow)**
#SV|
#XB|| Scénario | Requirement | Calcul |
#XX||----------|-------------|--------|
#BR|| **Escrow Minimum (Bronze)** | $50 | 1 workflow × max $50 budget. |
#VW|| **Escrow Peak (10 concurrent workflows)** | $5,000 | 10 × max budget $500 (Silver). |
#JX|| **Escrow Max (50 concurrent workflows)** | $25,000 | 50 × max budget $500. |
#QB|| **Liquidité Opérationnelle Recommandée** | **$50,000** | Marge de 2× pour handle les pics + refunds. |
#NM|
#KZ|*Note : Ces fonds sont en custody, pas des coûts. Ils doivent être en USDC sur le contrat escrow.*
#WZ|
#ZW|**C. Reviewer Stake Capital**
#MH|
#YW|| Métrique | Valeur | Calcul |
#KQ||----------|--------|--------|
#KY|| **Stake Minimum par Reviewer** | 500 USDC | Requirement on-chain. |
#KP|| **Nombre Minimum de Reviewers (V1)** | 10 | Pour avoir enough diversity. |
#HY|| **Total Capital Staked (Minimum V1)** | **5,000 USDC** | 10 reviewers × 500 USDC. |
#TQ|| **Capital Staked Target (Scalable)** | 50,000 USDC | 100 reviewers × 500 USDC. |
#RS|
#XT|**D. Fee Revenue (Break-even Analysis)**
#BX|
#BY|*Basé sur un mix réaliste de tiers : 60% Bronze, 25% Silver, 10% Gold, 5% Platinum*
#HB|
#QS|| Tier | Volume Mensuel | Budget Moyen | Platform Fee (moyenne) | Revenue Mensuel |
#VP||------|----------------|--------------|------------------------|-----------------|
#ZJ|| Bronze | 60 | $25 | 3% | $45 |
#YP|| Silver | 25 | $250 | 4% | $250 |
#KH|| Gold | 10 | $1,000 | 5% | $500 |
#VH|| Platinum | 5 | $3,000 | 6% | $900 |
#JM|| **TOTAL** | **100 workflows** | — | — | **$1,695/mo** |
#NP|
#TS|**Break-even :** À $8,000/mois de coût infrastructure, il faut **~470 workflows/mois** pour atteindre le break-even.
#QN|
#RY|| Métrique | Valeur |
#TM||----------|--------|
#WN|| **Break-even (workflows/mois)** | 470 |
#VW|| **Break-even (revenus/mois)** | $8,000 |
#KV|| **Temps jusqu'au break-even (V1 conservative)** | 6-12 mois |
#NK|
#MK|**E. Gas Costs (à la charge du client)**
#NN|
#VJ|| Tier | Gas Estimate | Cost (~$0.15/gas unit) |
#JV||------|--------------|------------------------|
#WJ|| Bronze (2 stages) | 170k gas | $0.25 |
#ZN|| Silver (3 stages) | 340k gas | $0.50 |
#BJ|| Gold (5 stages) | 680k gas | $1.00 |
#TX|| Platinum (6 stages) | 850k gas | $1.25 |
#NW|
#BY|*Le gas est payé par le client via le budget, pas par la plateforme.*
#RN|
#YZ|**F. Runway & Capital Requirements**
#QX|*Analyse de la runway basée sur le capital nécessaire pour opérer V1*:
#VR|| Métrique | Valeur | Notes |
#WM||----------|--------|-------|
#VT|| **Infrastructure (mensuel)** | $8,000 | Coûts fixes |
#VT|| **USDC Liquidity (minimum)** | $50,000 | En custody, pas un coût |
#VT|| **Reviewer Stake (minimum)** | 5,000 USDC | Capital tiers, pas un coût平台 |
#VT|| **Cash needed for 6 months** | $48,000 | 6 × $8,000 |
#VT|| **Cash needed for 12 months** | $96,000 | 12 × $8,000 |
#VT|| **Cash needed for 18 months** | $144,000 | 18 × $8,000 |
#VZ|
#VT|**Scénarios de Runway :**
#QT|| Scénario | Revenus/mois | Mois jusqu'au Break-even | Runway (avec $144k cash) |
#RV||----------|----------------|---------------------------|---------------------------|
#QT|| Conservative (100 workflows) | $1,695 | 85 mois | 18+ mois (croissance lente) |
#QT|| Realistic (250 workflows) | $4,238 | 23 mois | 18+ mois |
#QT|| Optimistic (470 workflows) | $8,000 | 18 mois | 18 mois pile |
#QT|| Growth (750 workflows) | $12,750 | 11 mois | 18+ mois avec profit |
#VT|
#VT|**Capital Requirement Summary :**
#VR|- **Minimum pour lancer V1** : $48,000 (6 mois infrastructure) + $50,000 (liquidity) = **$98,000**
#VR,- **Recommandé pour sécurité** : $144,000 (18 mois) + $50,000 (liquidity) = **$194,000**
#VR,- **Break-even target** : ~470 workflows/mois à $8,000 revenue
#YY|---
#JS|
#RY|### 3.4 Quality Gates
#BV|
#MX|| Décision | Justification |
#TK||----------|----------------|
#NS|| **Dual attestation (40% agent / 60% automated)** | La composante automated est objective. La composante agent capture le jugement qualitatif. |
#BX|| **Seuils hardcodés par tier** | Bronze: 60, Silver: 75, Gold: 85, Platinum: 95. Évite le gaming par clients. |
#QW|| **Reviewer != Executor** | Contrainte on-chain : `require(reviewer != stageAgent)`. Anti-collusion. |
#WJ|| **Chaîne d'attestations** | Chaque attestation référence `prevAttestationHash`. Traçabilité en cas de dispute. |
#HB|
#SW|### 3.5 Failure Handling
#XR|
#MX|| Décision | Justification |
#NM||----------|----------------|
#NZ|| **Failure policy tier-dépendante** | Bronze: fail-fast (0 retry), Silver: 1 retry, Gold: 2 retries + escalation, Platinum: 2 retries + backup agent |
#PW|| **Max 2 retries par stage** | Hard cap. Au-delà, workflow abort. |
#VP|| **Refund proportionnel** | Stages complétés = payés. Stage actif = en cours de résolution. Stages futurs = refund immédiat. |
#NP|
#QN|---
#VR|## 4. Périmètre Strict — Ce que le Produit FAIT
#XN|
#SS|### 4.1 Smart Contracts
#YY|- `MissionEscrow.sol` — Escrow atomique par mission (inchangé, 323 lignes, 14 tests)
#RQ|- `WorkflowEscrow.sol` — Orchestration multi-stage, budget lock/release, quality gate verification
#MB|- `AgentRegistry.sol` — Identité agents, capabilities, réputation
#XV|- `WorkflowRegistry.sol` — Stockage des définitions de workflows
#KJ|- `GateAttestationStore.sol` — Stockage des attestations (hash, score, signatures)
#ZX|- `ReviewerRegistry.sol` — Staking et slashing des reviewers
#RB|
#WP|### 4.2 Off-Chain
#VX|- **WorkflowCompiler** — Compile tier + issue → WorkflowPlan avec planHash
#PS|- **StageOrchestrator** — Orchestration, timeout monitoring, transitions d'état
#ZJ|- **MatchingEngine** — Assignment des agents, pool management, cold start
#XS|- **AttestationSigner** — Signature des attestations, validation qualité, TEE
#BS|- **Quality Gate Pipeline** — Exécution des checks automated + agent review, production des attestations
#TN|- **Tier Presets** — Bronze (1-2 stages), Silver (2-3 stages), Gold (3-5 stages), Platinum (4-6 stages)
#TH|
#BR|### 4.3 Interactions
#ZZ|- GitHub Bot — Issue → tier suggestion → workflow creation
#TP|- Agent SDK — Agents IA interagissent avec le système via API REST + webhooks
#ZW|- IPFS — Stockage des rapports de review, artefactual, audit trails
#TW|
#JV|---
#PS|
#SR|## 5. Hors Scope Explicite — Ce que le Produit NE FAIT PAS
#NW|
#QV|| Exclus | Raison |
#YK||--------|--------|
#SN|| **DAG arbitraire** | Complexité excessive. V1 = pipeline séquentiel. V2+ si données le justifient. |
#HJ|| **Parallel Fan-out en V1** | Join synchronization non résolue. Reporté à V1.5. |
#PN|| **Conditional branching on-chain** | Transforme le contrat en DAG engine. Géré off-chain uniquement. |
#BS|| **Arbitrage décentralisé (Kleros/UMA) en V1** | Trop complexe. V1 = admin multisig, V2 = arbitrage décentralisé. |
#HM|| **Quality Gates entirely on-chain** | Coût gas prohibitif, oracle problem non résolu. |
#BX|| **Budget reallocation dynamique** | Surface d'attaque trop grande. Budget fixe une fois committé. |
#JB|| **Tier customizable par client** | Les tiers sont des presets figés. Le client peut ajuster dans les bornes (10%-60% par stage). |
#BK|| **Tier comme SLA statistique** | V1 = promesse structurelle (nombre de vérifications). V2 = promesse statistique (taux de rework calibrés sur données réelles). |
#HQ|| **Matching完全 automatique** | Matching stage-by-stage, mais client peut override. |
#NN|
#MY|---
#XN|
#KM|## 6. Risques Critiques et Mitigations
#TP|
#PQ|### 6.1 Orchestrator Design (Résolu)
#ZH|
#SK|**Problème :** Le Coordinator Agent original faisait 6 choses (state machine, matching, artifact routing, timeout, signatures, failover) → risque de tight coupling.
#TY|
#KM|**Mitigation :**
#PY|- Découpage en 3 services distincts : StageOrchestrator, MatchingEngine, AttestationSigner (section 3.2.1).
#ZT|- Chaque service a son propre failover hot standby.
#XQ|- Communication par message queue pour isolation.
#QW|- Checkpointing toutes les 30s (WAL).
#NQ|- RFC technique à livrer en Phase 2.1.
#HN|
#VZ|---
#JR|
#WX|### 6.2 Dispute Resolution V1 (Mitigé)
#PR|
#KW|**Problème :** "Admin multisig tranche manuellement" est insuffisant comme spec.
#SW|
#KM|**Mitigation :**
#RP|- SLA de résolution : 72h maximum (hardcoded dans le contrat via `disputeDeadline`).
#YX|- Processus formalisé : Phase de preuve (24h), Phase de jugement (48h).
#QP|- Coût de dispute : 50 USDC (pour éviter le spam), remboursé au plaignant gagneur.
#KZ|- Extension V2 : Intégration Kleros Court pour arbitrage décentralisé (interface préparée).
#SV|
#PN|---
#RJ|
#VB|### 6.3 Artifact Pipeline (Résolu)
#JB|
#BX|**Problème :** Le format des artefacts inter-stages n'est pas spécifié.
#YB|
#KM|**Mitigation :**
#VZ|- SSOP v1.0 spécifié en annexe (JSON Schema strict).
#BH|- IPFS pinning obligatoire pour tous les artefacts > 1KB.
#NH|- Hash des artefacts inclus dans l'attestation on-chain (section 3.2).
#HM|
#JH|---
#RR|
#PH|### 6.4 Matching Engine (Mitigé)
#ZS|
#YZ|**Problème :** Comment assigner les agents aux stages (timing, cold start, anti-monopole).
#ZK|
#KM|**Mitigation :**
#JN|- Round-robin pondéré par réputation pour éviter la concentration.
#VQ|- Cold start : nouveaux agents limités à Bronze pendant 10 missions.
#BP|- Timeout de 2h avant reassignment automatique.
#VQ|- Anti-monopole : max 30% des missions sur 7 jours.
#MZ|
#ZX|---
#NN|
#BY|### 6.5 Reviewer Economic Incentives (Résolu)
#HR|
#ST|**Problème :** Qui paie les reviewers ? Comment les inciter à être honnêtes ?
#TN|
#KM|**Mitigation :**
#BB|- Staking 500 USDC requis (section 3.3.1).
#TV|- Slashing automatique sur écart >20% avec automated scoring.
#JP|- Rémunération prélevée sur platform fee (20% du fee).
#PH|- Rotation aléatoire (VRF) pour prévenir la collusion pré-établie.
#ZT|
#JV|---
#RN|
#KR|### 6.6 GitHub Adversarial Risk + Identity Layer
#QR|
#YW|**Problème :** Le système actuel ne vérifie pas que :
#VB|- L'issue provient d'un repo légitime (vs fake repo créé pour arnaquer des agents)
#JB|- Le payer possède réellement le repo (vs usurpation d'identité)
#MS|- Le budget n'est pas du money laundering (vs fonds volés ou wash trading)
#SM|- Le repo n'est pas modifié post-facto pour faire échouer le quality gate
#XM|
#KM|**Mitigation — Couche Identité GitHub :**
#QY|
#QY|**GitHubIdentityBinding (OAuth → Contract Address)**
#BR|Le client doit connecter son compte GitHub via **OAuth 2.0** au moment de la création du workflow. Cette liaison est persistante et vérifiable on-chain.
#ZN|Le système stocke un `GitHubIdentityBinding` :
#ZZ|```solidity
#JW|struct GitHubIdentityBinding {
#RS|    address wallet;           // Adresse Ethereum du client
#QP|    uint64 githubUserId;      // GitHub user ID
#RN|    string username;          // GitHub username
#JK|    bytes32 identityHash;     // keccak256(wallet + githubUserId + salt)
#VK|    uint256 boundAt;          // Timestamp du binding
#ZV|    uint8 verificationLevel;  // 0=none, 1=basic, 2=full KYC
YY|}
#```
#QP|- Ce binding est vérifié on-chain lors de `createWorkflow()` : le msg.sender doit avoir un binding valide avec `verificationLevel >= 1`.
#HM|
#JW|**Vérifications de Légitimité (KYC GitHub) :**
#ZP|1. **Repo Ownership (Required)**
#XP|   - Le client doit être **owner ou admin** du repo via GitHub API
#ZN|   - Token OAuth doit avoir le scope `repo` pour vérifier les permissions
#ZS|   - Vérification on-chain via merkle proof du repo ownership
#ZP|2. **Issue Authenticity (Required)**
#XP|   - L'issue doit être créée par le **owner/collaborator** du repo
#ZV|   - L'issue ne doit pas être modifiée après création du workflow
#ZS|   - Hash de l'issue stocké on-chain au moment de la création
#ZP|3. **Anti-Wash Trading (Required)**
#XP|   - Le même wallet ne peut pas créer **>5 workflows/jour** avec des budgets différents
#ZV|   - Rate limiting on-chain : `maxWorkflowsPerDayPerWallet = 5`
#ZS|   - Flag automatique si pattern suspect (même budget, même timestamp)
#ZP|4. **Repo Age & Activity (Required)**
#XP|   - Le repo doit avoir **≥1 mois d'existence** OU **≥10 commits**
#ZV|   - Anti-fake repo : empêche la création de repo jetables pour arnaquer
#ZS|   - Vérification via GitHub API `created_at` et `commits_count`
#ZP|5. **KYC Layer (V1.5 — Optional)**
#XP|   - Pour les workflows >$1000, vérification identity additionnelle
#ZV|   - Intégration future : Persona/KYC.io pour identité réelle
#ZS|   - Stockage off-chain avec proof on-chain (zero-knowledge)
#XK|**Limite V1 :** Les vérifications 1-4 sont **off-chain** via GitHub API. V2 : Intégration on-chain GitHub proof (RSS signature ou optimistic verification).
#SY|---
#RW|
#KB|### 6.7 Oracle Failure (Nouveau)
#TK|
#TR|**Problème :** Dépendance aux services externes (IPFS, GitHub API, RPC).
#HQ|
#KM|**Mitigation :**
#PV|- **IPFS Failure :** Cache local avec fallback à 24h. Si IPFS down >24h, les nouveaux workflow sont pausés.
#TS|- **GitHub API Failure :** Rate limiting avec queue. Retry exponential backoff.
#MV|- **RPC Failure :** Multi-provider (Infura + Alchemy + QuickNode). Auto-failover.
#QK|- **Circuit Breaker :** Si >50% des appels échouent, le service se met en mode degradé.
#WB|---
#XM|
#KK|## 7. Next Steps Priorisés
#XX|
#TR|### Phase 1 — Fondations On-Chain (Semaines 1-3) — PRIORITÉ HAUTE
#ZT|
#TM|| # | Tâche | Dépendance | Livrable |
#SZ||---|-------|------------|----------|
#NR|| 1.1 | Ajouter rôle WORKFLOW_OPERATOR à MissionEscrow | Aucune | PR + 2 tests |
#SJ|| 1.2 | Struct WorkflowPlan on-chain (planHash, tier, stageCount) | 1.1 | ~5 tests |
#KN|| 1.3 | createWorkflow() — validation, budget lock, stage init | 1.2 | ~8 tests |
#ZQ|| 1.4 | WorkflowEscrow.sol — FSM complète | 1.3 | ~20 tests |
#TK|| 1.5 | Non-régression MissionEscrow (14 tests verts) | 1.4 | ✅ |
#HW|
#MH|**Critère de sortie** : Pipeline Bronze fonctionnel (2 stages) avec tests Foundry.
#XX|
#VR|---
#HM|
#NR|### Phase 2 — Quality Gates & RFC Coordinator (Semaines 3-6)
#QS|
#TM|| # | Tâche | Dépendance | Livrable |
#YT||---|-------|------------|----------|
#QH|| 2.1 | QualityGateAttestation struct + submitAttestation() | Phase 1 | ~8 tests |
#ZW|| 2.2 | Dual attestation (40% agent / 60% automated) | 2.1 | Design doc |
#ZB|| 2.3 | Retry/Abort mechanics | 2.1 | ~10 tests |
#XM|| 2.4 | Client veto + emergency halt | 2.1 | ~3 tests |
#RQ|| **2.5** | **RFC Services d'Orchestration (StageOrchestrator, MatchingEngine, AttestationSigner)** | **2.1** | **Document technique avec diagrammes, états finis, stratégie failover, modèle TEE/multi-sig** |
#HX|| 2.6 | ReviewerRegistry (Staking & Slashing) | 2.2 | Contrat + tests |
#JM|
#SK|**Critère de sortie** : Silver tier exécutable bout-en-bout + RFC Services validé par l'équipe technique.
#NX|
#BQ|---
#VB|
#HT|### Phase 3 — WorkflowCompiler + Services d'Orchestration (Semaines 6-10)
#XY|
#TM|| # | Tâche | Dépendance | Livrable |
#TV||---|-------|------------|----------|
#JP|| 3.1 | WorkflowCompiler (tier → plan) | Phase 2 | Service |
#QV|| 3.2 | SSOP format specification | 3.1 | Schema JSON |
#VK|| 3.3 | StageOrchestrator MVP | **2.5** | Service (implémentation du RFC) |
#WX|| 3.4 | MatchingEngine MVP | 3.3 | Service |
#WQ|| 3.5 | AttestationSigner MVP | 3.3 | Service |
#SK|| 3.6 | TEE Setup (Intel SGX ou AWS Nitro) | 3.5 | Infrastructure |
#HS|
#QK|**Critère de sortie** : Tier Bronze/Silver fonctionnels end-to-end.
#WH|
#ZW|---
#HK|
#RK|### Phase 4 — Intégration + E2E (Semaines 10-12)
#SM|
#TM|| # | Tâche | Dépendance | Livrable |
#SX||---|-------|------------|----------|
#MM|| 4.1 | GitHub Bot v2 (tier suggestion + Identity Binding) | Phase 3 | Bot |
#QB|| 4.2 | Dashboard client (workflow progress) | Phase 3 | UI |
#VK|| 4.3 | E2E test (Bronze → Silver → Gold) | 4.1-4.2 | Tests |
#JN|| 4.4 | Audit interne | 4.3 | Report |
#QB|
#TP|**Critère de sortie** : Beta launch limité (5-10 clients).
#JK|
#WY|---
#BP|
#RS|## Annexe : Définitions des Tiers
#VN|
#NB|| Tier | Stages | QG Threshold | Budget Range | Failure Policy | Gas Strategy |
#XZ||------|--------|--------------|--------------|----------------|--------------|
#JM|| **Bronze** | 1-2 (Code → Test) | 60/100 | $5-50 | Fail-fast, full refund | Clone proxy minimaliste (85k gas) |
#BY|| **Silver** | 2-3 (Code → Review → Test) | 75/100 | $50-500 | 1 retry + substitution | Standard deployment |
#QR|| **Gold** | 3-5 (Code → Review → Security → Test) | 85/100 | $500-2000 | 2 retries + escalation | Standard deployment |
#KR|| **Platinum** | 4-6 (Code → Review → Security → Test → Optimization → Final) | 95/100 | $2000+ | 2 retries + backup agent + partial payment | Standard deployment + Optimistic rollup batching optionnel |
#MM|
#KB|---
#MK|
#KH|## Annexe : Architecture Détaillée
#VT|
#VW|```
#NZ|┌─────────────────────────────────────────────────────────────────────────┐
#YS|│                           CLIENT                                        │
#TJ|│  (Jeff, développeur solo)                                            │
#VW|│    │                                                                    │
#JH|│    ├── Connecte GitHub + OAuth                                         │
#WS|│    ├── Crée une issue                                                  │
#PQ|│    ├── GitHubIdentityBinding (wallet → GitHub)                        │
#XY|│    ├── Choisit budget + tier                                           │
#SN|│    └── Reçoit livrable + audit trail                                   │
#QB|└─────────────────────────────────────────────────────────────────────────┘
#PV|                                  │
#BN|                                  ▼
#VT|┌─────────────────────────────────────────────────────────────────────────┐
#TW|│                    WORKFLOW COMPILER (Off-chain)                        │
#TW|│  • Compile (tier + issue) → WorkflowPlan                               │
#SY|│  • Génère planHash = keccak256(plan)                                   │
#RW|│  • Upload plan sur IPFS                                                │
#VH|│  • Retourne planHash + planURI                                         │
#ZB|└─────────────────────────────────────────────────────────────────────────┘
#RB|                                  │
#TH|                                  ▼
#NW|┌─────────────────────────────────────────────────────────────────────────┐
#WY|│                    WORKFLOWESCROW.SOL (On-chain)                       │
#XQ|│                                                                         │
#SM|│  createWorkflow(planHash, planURI, stages[], budgetBps[])              │
#RT|│      │                                                                  │
#VQ|│      ├── Lock totalBudget USDC                                         │
#JV|│      ├── Vérifie GitHubIdentityBinding                                 │
#JZ|│      ├── Enregistre stages[] avec budgetBps                            │
#KJ|│      ├── Plan hash immutable                                           │
#YN|│      └── Émet WorkflowCreated event                                    │
#MY|│                                                                         │
#WJ|│  activateStage(workflowId, stageIndex)                                 │
#TS|│      │                                                                  │
#RW|│      ├── Crée MissionEscrow pour le stage                             │
#WS|│      ├── Lock budget du stage                                          │
#KJ|│      └── Émet StageStarted event                                       │
#TT|│                                                                         │
#YW|│  submitQualityGate(workflowId, stageIndex, attestation)                │
#VT|│      │                                                                  │
#XJ|│      ├── Vérifie signature (agent + AttestationSigner TEE)            │
#TT|│      ├── Vérifie score >= threshold                                    │
#RN|│      ├── Vérifie reviewerStake > 0 (pas slashed)                       │
#KZ|│      ├── Si pass: advanceStage()                                        │
#BW|│      ├── Si fail: failStage()                                          │
#RS|│      └── Émet QualityGateResult event                                 │
#QT|│                                                                         │
#WW|│  retryStage(workflowId, stageIndex)                                     │
#BQ|│      │                                                                  │
#SX|│      ├── Vérifie retryCount < maxRetries                               │
#JW|│      └── Reset stage state                                             │
#QX|│                                                                         │
#JR|│  abortWorkflow(workflowId)                                              │
#PP|│      │                                                                  │
#QK|│      ├── Refund stages non-startés                                     │
#QW|│      └── Paiement stages complétés (irréversible)                      │
#QN|└─────────────────────────────────────────────────────────────────────────┘
#WS|                                  │
#KY|                                  ▼
#PM|┌─────────────────────────────────────────────────────────────────────────┐
#PT|│                    MISSIONESCROW.SOL (On-chain)                         │
#JB|│  (Inchangé : 323 lignes, 14 tests)                                     │
#JH|│                                                                         │
#KP|│  createMission(agent, budget, deadline)                                │
#BK|│  acceptMission()                                                        │
#MH|│  deliverMission()                                                        │
#HP|│  approveMission() / disputeMission()                                  │
#RK|└─────────────────────────────────────────────────────────────────────────┘
#HB|                                  │
#XT|              ┌───────────────┬───────────────┬───────────────┐
#HX|              ▼               ▼               ▼               ▼
#SX|┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────────┐
#TZ|│STAGEORCHESTRATOR│ │ MATCHING ENGINE │ │ ATTESTATION SIGNER      │
#HH|│                 │ │                 │ │                         │
#BY|│ • State machine │ │ • Pool agents   │ │ • TEE (Nitro/SGX)       │
#HX|│ • Timeout mgmt  │ │ • Assignment    │ │ • Dual signature        │
#NP|│ • Transitions   │ │ • Cold start    │ │ • Quality validation    │
#WM|│ • Event routing │ │ • Anti-monopole │ │ • VRF integration       │
#RX|│                 │ │                 │ │                         │
#XK|│ WAL + Checkpoint│ │ Round-robin     │ │ Gnosis Safe 2/2         │
#YZ|│ Hot standby     │ │ Weighted        │ │ 5% slashing on fraud   │
#MH|└─────────────────┘ └─────────────────┘ └─────────────────────────┘
#QB|                                  │
#KS|                                  ▼
#JM|┌─────────────────────────────────────────────────────────────────────────┐
#KT|│                    REVIEWER REGISTRY (On-chain)                         │
#XN|│  • Staking : 500 USDC minimum                                          │
#RN|│  • Lock period : 7 jours                                               │
#PT|│  • Slashing : 10%/50%/100% sur écart >20%                             │
#QK|│  • VRF rotation : assignation aléatoire des reviewers                  │
#HQ|└─────────────────────────────────────────────────────────────────────────┘
#PY|```
#ZH|
#RP|---
#JH|
#VH|## Annexe : Budget Split Exemple (Gold, $1000)
#RP|
#JZ|```
#RV|Budget total: $1000 (après platform fee 5% = $50)
#XV|
#ZW|Stage 1 (Code):      4000 bps = $400
#YN|Stage 2 (Review):   2500 bps = $250  
#KZ|Stage 3 (Security):  2000 bps = $200
#XW|Stage 4 (Test):     1500 bps = $150
#RH|
#MK|Coordination multiplier (3 stages): 1.25x
#ZP|Tier margin (Gold): 1.2x
#ZV|
#NR|Total after multipliers: $1000 ✅
#SK|
#ZM|Payment per stage:
#QJ|- Immediate (70%): $280 / $175 / $140 / $105
#TV|- Success bonus (30%): $120 / $75 / $60 / $45
#WW|  (released only on full workflow completion)
#WW|
#HX|Reviewer Incentive (20% of 5% fee = $10 total):
#JT|- Reviewer Stage 2: $4 (40%)
#HB|- Reviewer Stage 3: $6 (60%)
#ZQ|- Lock 7 jours, release si pas de challenge
#YM|```
#WM|
#BP|---
#XZ|
#ZB|## Annexe : Economics V1 Summary
#RN|
#RY|| Catégorie | Métrique | Valeur |
#WM||----------|---------|--------|
#KV|| **Infrastructure** | Coût mensuel | $8,000 |
#PP|| **USDC Liquidity** | Requirement minimum | $50,000 |
#BY|| **Reviewer Stake** | Total (10 reviewers) | 5,000 USDC |
#WN|| **Break-even** | Workflows/mois | 470 |
#SP|| **Break-even** | Timeline | 6-12 mois |
#VT|| **Capital V1** | Pour 6 mois | $98,000 |
#VT|| **Capital V1** | Recommandé (18 mois) | $194,000 |
#TK|
#QM|*Document généré à partir de 21 cycles de brainstorm (za→zu) + Audit VC/CTO. Les décisions marquées ✅ ont survécu à tous les cycles avec consensus fort. Améliorations implémentées: (1) Coordinator Agent découplé en 3 services avec mitigation SPOF, (2) Couche identité GitHub avec KYC/vérifications légitimité, (3) Économie V1 clarifiée avec runway et capital requirements.*
