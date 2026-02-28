# Grok 4 — Audit Complet Agent Marketplace

**Date:** 2026-02-28  
**Modèle:** grok-4-0709  
**Tokens:** 28490 in / 3146 out

---

# Audit Complet et Critique : Agent Marketplace

**Auditeur : Grok (basé sur xAI, version 2026-02-28)**  
**Date de l'audit : 2026-02-28**  
**Portée : Analyse exhaustive de DECISIONS.md, PRD v1.3, ARCHITECTURE v2, MASTER-v2, et toutes les sous-sections fournies.**  
**Méthodologie : Cross-validation entre docs, identification de risques techniques/économiques/compliance, focus sur viabilité prod. Pas de fluff — direct aux faits.**

Ce rapport est structuré comme demandé. Le projet est ambitieux mais truffé d'incohérences, de risques non adressés, et d'un scope V1 surchargé. C'est viable avec des fixes majeurs, mais pas prêt pour le coding sans rework. Allons-y.

## 1. Cohérence Globale

Le projet est globalement cohérent grâce à DECISIONS.md qui override explicitement les conflits, mais il reste des incohérences persistantes qui indiquent un manque de consolidation post-décision. ARCHITECTURE v2 et MASTER-v2 intègrent bien les updates, mais PRD v1.3 a des reliques non corrigées.

### Contradictions entre les Documents
- **Token Supply** : DECISIONS.md fixe 100M (canonical), mais smart-contracts-spec dans PRD mentionne encore 1B comme option (non résolue). MASTER-v2 confirme 100M — OK, mais PRD doit être patché pour éviter confusion dev.
- **Protocol Fee** : DECISIONS.md : 10% total (3% burn + 5% insurance + 2% treasury). PRD F7.2 dit "3% AGNT burn + 5% held in escrow reserve + 2% treasury" — cohérent, mais architecture-decisions mentionne 2% insurance (overridé). Pas critique, mais documentez un "fee history" pour audits futurs.
- **Mission States** : DECISIONS.md : ACCEPTED (canonical, pas ASSIGNED). PRD F3.6 utilise ACCEPTED, mais MASTER-v2 liste "ASSIGNED" dans un diagramme obsolète. Risque : devs implémentent le mauvais enum en Solidity/DB.
- **Insurance Pool** : DECISIONS.md : 5% fee, max payout 2x. PRD F13 dit "contribute to collective insurance pool" sans cap — cohérent post-decision, mais PRD n'est pas mis à jour.
- **V1 Scope vs V1.5** : PRD note explicitement que F6-F12 sont V1.5 (post-8 weeks), mais MASTER-v2 les liste comme "Must-Have" sans distinction claire. Exemple : pgvector in V1.5, mais ARCHITECTURE v2 dit "do not create in V1" — bon, mais sprint plan mélange.

### Décisions Incompatibles
- **Staking Yield** : MASTER-v2 dit "5% APY from treasury" pour V1.5, mais DECISIONS.md et PRD n'en parlent pas. Incompatible avec "no staking yield in V1" (MASTER-v2) — clarifiez si c'est governance-locked.
- **Burn Mechanism** : PRD dit "dynamic EIP-1559 style", DECISIONS.md fixe 3% statique. Incompatible — dynamic rend le 3% meaningless si congestion varie. Choisissez un : statique pour simplicité ou dynamic pour scalabilité.
- **Dispute Resolution** : DECISIONS.md : objective criteria + multi-sig V1, DAO V3. MASTER-v2 ajoute "DAO after 1,000 missions" — incompatible avec V3 timeline. Fixez à V3 pour éviter premature DAO (risque sybil).
- **Fiat-First** : PRD §9b insiste sur fiat V1 (Stripe → USDC), mais ARCHITECTURE v2 n'a pas de stripe.ts dans la structure initiale (ajouté post-audit). Bon fix, mais incompatible avec "crypto-native" dans PRD non-goals.

### Scope Creep V1 (Features Marquées V1 qui Devraient Être V1.5)
- **Dry Run (F9)** : Marqué V1.5 dans PRD, mais sprint plan le met en Sprint 5-6 (V1). Creep : c'est une feature non-core qui dépend de mission states — push to V1.5.
- **Proof of Work Outputs (F11)** : V1.5 dans PRD, mais ARCHITECTURE v2 le liste comme V1.5 — OK, mais MASTER-v2 l'inclut dans "Must-Have". Creep : enterprise-only, defer.
- **Inter-Agent Hiring (F8)** : V1 dans PRD, mais ARCHITECTURE v2 dit V1.5. Creep majeur : dépend d'auctions complexes, push to V1.5 pour MVP viable.
- **Mission DNA (F10)** : V1.5 (pgvector), mais PRD F1.6 dit "V1: tag overlap". Creep : tag-only est V1, embedding V1.5 — clarifiez pour éviter implémentation prématurée.
- **Recommendation :** Réduisez V1 à F1-F5 + F7 (core marketplace). V1.5 pour le reste. Actuel scope V1 = 8 weeks irréaliste (sous-estime indexer/debug).

Globalement, cohérence 7/10 — DECISIONS.md sauve la mise, mais PRD/PRD est outdated.

## 2. Risques Smart Contracts

Les contrats sont bien structurés (OZ-based), mais des risques classiques non adressés menacent la prod. Pas d'audit externe mentionné — bloquant avant mainnet.

### Vecteurs d'Attaque
- **Reentrancy** : MissionEscrow.deliverMission → approveMission (release funds). Si deliver appelle un contrat malicieux qui reentre, funds drain. Fix : ReentrancyGuard sur TOUTES les fonctions with external calls (e.g., token transfers).
- **Arithmetic Overflow** : Fee calculations (calculateFeeBreakdown) utilisent uint256 sans SafeMath (Solidity 0.8+ a built-in overflow checks, mais vérifiez dans tests). Risque si totalAmount > 2^256-1 — improbable, mais testez edge cases.
- **Oracle Manipulation** : ReputationOracle.recordMissionOutcome dépend d'un oracle (protocol). Si oracle compromis (e.g., sybil attack via fake missions), reputation inflated. Fix : multi-oracle ou ZK-proof (V2), ou limitez à escrow contract calls only.
- **Slash Abuse** : ProviderStaking.slash callable par escrow, mais si dispute resolution multi-sig hacké, slashes arbitraires. Risque : treasury drain via insurance claims. Fix : add timelock (48h) sur slash >10%.

### UUPS Storage Collisions
- UUPS proxy : Bon choix, mais storage gaps non explicitement vérifiés (ARCHITECTURE v2 mentionne Slither). Risque : upgrade overwrite variables (e.g., MissionEscrow state in v2). Fix : __gap[50] dans TOUS les contrats, run Slither pre-upgrade.

### Governance / Multisig Gaps
- Multisig 3/5 pour upgrades/disputes, mais pas de timelock sur upgrades critiques (e.g., burn rate). Risque : rug pull via instant upgrade. Fix : Timelock 48h sur _authorizeUpgrade et setBurnRate.
- Ownership : Ownable2Step bon, mais pas de revocation mechanism pour roles (e.g., ADMIN). Risque : compromised admin = game over. Fix : add role revocation with multi-sig approval.

Risque global : Haut (8/10) — needs external audit (e.g., PeckShield) avant deploy. Test coverage 90% bon, mais ajoutez fuzzing pour fees/states.

## 3. Risques Backend/API

Backend est solide (Fastify + Prisma), mais scaler issues et race conditions évidentes.

### Goulots d'Étranglement
- **Indexer Sync** : watchContractEvent + 10min backfill bon, mais sur volume >1k tx/jour, BullMQ queue backlog (e.g., reorgs causent spikes). Risque : DB out-of-sync = stale UI. Fix : scale BullMQ workers horizontalement (k3s pods).
- **OFAC Screening** : Sync call à TRM Labs avant CHAQUE tx (createMission/register). Risque : latency +5s per request, DoS si TRM down. Fix : async queue pour screening non-critique, ou cache 1h pour wallets clean.

### Race Conditions
- **State Machine + Indexer** : Mission.transitionState appelle contract puis update DB. Risque : reorg après contract call = DB desync (e.g., ACCEPTED in DB, mais reorg annule). Fix : wait for L1 finality (10-15min) avant DB write pour states finals (COMPLETED/REFUNDED).
- **Mission Events Dedup** : UNIQUE(tx_hash, log_index) bon, mais si indexer restart mid-reorg, duplicate inserts. Fix : transactionnelle DB writes with lock sur mission_id.

### Failles Auth
- **JWT + SIWE** : JWT RS256 bon, mais refresh token in Redis = single point failure si Redis down. Risque : session hijack via leaked refresh. Fix : short-lived refresh (1h), add nonce per SIWE.
- **Provider Auth** : SIWE bon pour providers, mais pas de rate-limit per-wallet = spam registrations. Fix : add economic cost (e.g., min stake at register).

Risque global : Moyen (6/10) — scaler OK pour MVP, mais testez sous load (Locust).

## 4. Risques Compliance

Compliance est partiellement adressée (PRD §12b), mais gaps majeurs pour un projet fintech.

### GDPR sur Données On-Chain
- On-chain data (reputation, missions) immutable = impossible à delete. Risque : GDPR violation (droit à l'oubli) si users EU. Fix : disclose explicitly in ToS ("on-chain data permanent"), off-chain only pour PII. Mais si wallet = PII, lawsuit risk haut.

### KYC $10K Threshold — Suffisant Légalement ?
- Self-attestation bas + enhanced à $10K = faible. Risque : AML non-compliant (FinCEN requiert KYC pour "money transmitters" >$1K/tx aux US). Fix : abaissez à $1K/tx, intégrez Persona/KYC vendor dès V1. $0.50/verif = cheap.

### Token — Securities Risk
- Legal opinion required (PRD C4.1), mais pas de details sur Howey Test. Risque : $AGNT = security si "investment expectation" (e.g., burn = value accrual). Fix : obtain opinion ASAP, geofence US si security. No listing = bon, mais utility narrative faible.

Risque global : Haut (8/10) — compliance blocker pour mainnet. Budget legal $15K sous-estimé (crypto lawyers = $50K+).

## 5. Modèle Économique

Modèle OK pour utility token, mais over-hyped (burn "symbolic").

### Token Burn 3% — Justifié ?
- À $10M volume/mois = 300K tokens burned = 0.3% supply. Non justifié comme "deflationary" (PRD) — c'est du marketing. Risque : holder disappointment. Fix : pivot à "governance-first" narrative (Option A dans MASTER-v2).

### Insurance Pool 5% — Suffisant pour Couvrir les Slashes ?
- 5% fee + cap 2x = viable si dispute rate <2% (OKR target). Risque : si disputes >5%, pool bankrupt (e.g., 10 disputes à 2x = drain rapide). Fix : dynamic fee adjust (EIP-1559) ou reinsurance via treasury.

### Cold Start 5M AGNT — Réaliste ?
- 50K/agent pour 100 agents = bon incentive, mais validation (10 missions ≥8/10) = cher à opérer. Risque : low quality agents flood. Fix : cap à 50 agents initial, scale basé sur metrics.

### 10% Protocol Fee — Compétitif ?
- Haut vs competitors (e.g., NEAR ~5%). Risque : churn si providers migrent. Fix : tiered fees (e.g., 5% pour gold stakers).

Risque global : Moyen (6/10) — sustainable si adoption, mais burn hype = red flag.

## 6. Ce Qui Manque Absolument Avant de Coder

Ces gaps bloqueront les devs mid-sprint — fixez-les avant Sprint 1.
- **Specs Manquantes** : Pas de webhook-spec détaillée (events, payloads) — critique pour SDK. Pas de fiat-onramp-spec complète (Stripe webhooks pour disputes). Pas de contract-tests-spec pour edge cases (reorgs).
- **Ambiguïtés** : Reputation formula weights (40/30/20/10) — pas de code/simulations pour valider. Matching algo : "top 10 ranked" sans tie-breakers. Dispute evidence : "hash" mais pas de IPFS upload flow.
- **Autres Blockers** : Pas de env vars template (.env.example) pour RPC/Keys. Pas de migration plan pour DB schema changes. Pas de error codes standardisés (e.g., AGENT_NOT_FOUND).

Priorisez : webhook + fiat specs (2 jours dev), sinon API incomplète.

## 7. Score Global

**Score : 6/10**  
Justification : Projet solide sur papier (cohérence via DECISIONS.md, stack mature), mais risques hauts en security/compliance/éco modèlent un launch risqué. Scope creep V1 = recipe pour burnout, et gaps specs = bugs inévitables. Viable post-fixes, mais pas "prod-ready". Comparable à early DeFi projects (e.g., Uniswap V1 avait similaires gaps).

**Top 5 Priorités Avant Sprint 1** :
1. **External Contract Audit** : PeckShield ou équivalent ($50K budget) — must pour mainnet.
2. **Legal Opinion on Token** : Confirmez utility status, geofence si needed.
3. **Scope Lockdown** : Move dry run/inter-agent to V1.5, update PRD/MASTER.
4. **Indexer Stress Tests** : Simulez 10k tx/jour avec reorgs — fix desyncs.
5. **Compliance Integration** : Implémentez KYC vendor + GDPR disclosure — blocker légal.