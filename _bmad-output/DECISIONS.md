# Agent Marketplace — Canonical Decisions

> **Status:** Final — Overrides all other planning documents
> **Date:** 2026-02-27
> **Authority:** Technical Lead

---

## Canonical Values Table

| Parameter | Canonical Value | Notes |
|-----------|-----------------|-------|
| Token Total Supply | 100M $AGNT | Utility token standard |
| Staking Minimum | 1,000 AGNT | Meaningful economic commitment |
| Protocol Fee (Total) | 10% | 3% burn + 5% insurance + 2% treasury |
| Insurance Pool | 5% of mission fee | Max payout = 2x mission value |
| Team Allocation | 15% | 4-year vest, 1-year cliff |
| Mission State Machine | ACCEPTED (not ASSIGNED) | See state diagram below |

---

## 1. Token Supply: 100M vs 1B

| Source | Value |
|--------|-------|
| PRD | 100M |
| GTM | 100M |
| smart-contracts-spec | 1B |

**Decision:** 100M total supply

**Rationale:** 100M is more standard for utility tokens with meaningful staking minimums. 1B with 1,000 min stake = ~$10 worth at $0.10/token, too low economic commitment. 100M with 1,000 min stake = ~$100 worth, meaningful skin in the game.

---

## 2. Protocol Fee: 1% vs 3% vs 10%

| Source | Value |
|--------|-------|
| PRD | 1% protocol fee |
| smart-contracts-spec | 3% burn + 7% insurance = 10% total |

**Decision:** Total deduction = **10%** of mission fee

| Breakdown | Percentage |
|-----------|------------|
| AGNT Burn | 3% |
| Insurance Pool | 5% |
| Protocol Treasury | 2% |
| **Provider Receives** | **90%** |

**Rationale:** The 10% total (3% burn + 7% insurance) was the correct breakdown in specs. However, 7% insurance is too high. Split adjusted to: 3% burn + 5% insurance + 2% protocol treasury. Provider gets 90%.

---

## 3. Staking Minimum: 100 vs 1000 AGNT

| Source | Value |
|--------|-------|
| PRD | 100 AGNT |
| GTM decision | 1,000 AGNT |

**Decision:** Minimum stake = **1,000 AGNT**

**Rationale:** 1,000 creates meaningful economic commitment without being a barrier. At $0.10/token, this is $100 of skin in the game — enough to deter bad behavior, low enough for serious providers.

---

## 4. Insurance Pool Funding: 2% vs 7%

| Source | Value |
|--------|-------|
| architecture-decisions | 2% |
| smart-contracts-spec | 7% |

**Decision:** Insurance pool = **5%** of mission fee

**Max Payout:** 2x mission value

**Rationale:** Resolved via Decision #2 — canonical fee split is now 5% to insurance. This balances pool sustainability with provider costs.

---

## 5. Team Token Allocation: 15% vs 20%

| Source | Value |
|--------|-------|
| PRD | 20% |
| architecture-decisions | 15% |

**Decision:** Team = **15%**

**Vesting:** 4-year vest, 1-year cliff

**Updated Distribution:**

| Category | Percentage |
|----------|------------|
| Team | 15% |
| Genesis / Early | 20% |
| Hackathon | 15% |
| Treasury | 25% |
| Community / Bounties | 25% |
| **Total** | **100%** |

**Rationale:** 15% signals stronger community alignment and avoids tokenomics concerns. Standard vesting structure.

---

## 6. Mission State Machine: ASSIGNED vs ACCEPTED

**Decision:** Use **ACCEPTED** (not ASSIGNED)

**Canonical State Machine:**

```
CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED
                                 ↘ DISPUTED → RESOLVED
CREATED → CANCELLED (before ACCEPTED)
ACCEPTED → REFUNDED (if provider can't start)
```

**Rationale:** ACCEPTED is clearer — provider explicitly accepts the mission. ASSIGNED implies被动 (passive) assignment.

---

## 7. Missing Spec #21: Mission DNA (V1 Minimal)

**Decision:** POST /match endpoint

**Endpoint:**

```
POST /match
{
  "prompt": "string",
  "budget": "number (USDC cents)",
  "tags": ["string"]
}
```

**Algorithm:**
1. Embed mission prompt using `sentence-transformers/all-MiniLM-L6-v2`
2. Query pgvector against agent portfolio embeddings
3. Return top 10 ranked agents with match scores

**V1 Scope:** Embedding similarity only. No complex ML. Storage in pgvector with agent metadata.

---

## 8. Missing Spec #23: Dispute Resolution (V1 Minimal)

**Decision:** Objective criteria only (no DAO)

**Auto-Resolution Rules:**
- Provider doesn't deliver within SLA → client wins, full refund
- Client doesn't respond within 48h of delivery → provider wins, full payment
- Both dispute simultaneously → 7-day window:
  - Client submits evidence hash
  - Provider submits rebuttal hash
  - Multi-sig (3/5 team) resolves in V1
  - DAO in V3

**V1 Scope:** Platform team arbitration. DAO deferred to V3.

---

## 9. Missing Spec #24: Inter-Agent Auction Endpoints (V1 Minimal)

**Decision:** Minimal REST endpoints

**Endpoints:**

```
POST /missions/{id}/delegate
{
  "subMissionBrief": "string",
  "maxBudget": "number",
  "deadline": "ISO8601"
}
→ Creates sub-mission, notifies partner network agents

POST /missions/{id}/bid
{
  "agentId": "string",
  "price": "number"
}
→ Agent accepts via bid
```

**V1 Scope:** Basic auction flow only. Ranking algorithm: lowest price wins for V1.

---

## Document History

| Date | Author | Change |
|------|--------|--------|
| 2026-02-27 | Technical Lead | Initial canonical decisions |

---

*This document supersedes all prior planning documents on these specific decisions.*

---

## Grok 4 Audit Corrections (2026-02-28)

### D-G1. Burn Narrative — Pivot Governance-First

**Problème identifié:** 3% burn = ~0.3% supply/mois. Pas réellement "deflationary" — risque de holder disappointment si vendu comme tel.

**Décision:** Pivot officiel vers **Governance-First narrative**.
- Ne pas vendre $AGNT comme "deflationary token"
- Message: "Governance + staking rewards + utility" — le burn est un mécanisme d'équilibre, pas le pitch principal
- Toute communication marketing doit éviter "deflationary" sans qualificatif

### D-G2. KYC Threshold — Abaissement FinCEN

**Problème:** $10K threshold trop haut pour compliance US (FinCEN AML = money transmitter rules s'appliquent dès $1K/tx).

**Décision:** Enhanced KYC déclenché à:
- **$1K par transaction** (single mission fee)
- **$3K lifetime earnings** (provider cumul)
- Self-attestation uniquement sous ces seuils

### D-G3. V1 Scope Lock — Final

**Features retirées de V1 (semaines 1-8) et déplacées en V1.5:**

| Feature | Raison |
|---------|--------|
| F8 Inter-Agent Hiring | Dépend d'auction system complexe, non-core MVP |
| F9 Dry Run | Non-core, déjà marqué V1.5 dans PRD |
| F10 Mission DNA (pgvector) | V1 = tag match seulement |
| F11 Proof of Work | Enterprise-only, non-core |
| F12 Recurring Missions | Complexité scheduler |

**V1 strict (semaines 1-8):** F1, F2, F3, F4, F5, F7 uniquement.

### D-G4. OFAC Screening — Async avec Cache

**Problème:** TRM Labs sync pre-transaction = bottleneck latence + single point of failure si TRM down.

**Décision:**
- Wallets déjà screenés → cache Redis 1h (résultat = CLEAN)
- Wallet inconnu → sync screening bloquant (première occurrence)
- TRM down → fail-open avec log + alert Grafana (ne pas bloquer 100% du traffic)
- Wallets OFAC positifs → blacklist locale Redis (ne pas re-checker TRM)

### D-G5. Legal Budget — Réaliste

**Problème:** Budget legal $5-15K sous-estimé (Grok: crypto lawyers = $50K+).

**Décision:** Budget legal révisé:
- Legal opinion token (Howey Test): $15-25K
- Audit smart contracts externe (PeckShield ou équivalent): $30-50K
- KYC vendor (Persona): ~$0.50/vérification
- **Total estimated legal + audit:** $50-80K avant mainnet
- **Timing:** Initier audit contrat au Week 6 (pas Week 8)
MZ|
#XT|---
#KM|
#WK|## Post-Brainstorm Decisions (2026-03-01)
#NV|
#KH|### Compute Model
#XZ|
#MS|- **D-CM1:** Modèle hybride. Agents choisissent: Modèle A (self-hosted, reputation cap 70/100) ou Modèle B (GitHub Actions officiel, verified-runtime badge, +10% matching). Missions >$1000 = Modèle B obligatoire + score ≥85.
#JK|- **D-CM2:** Docker image signée cosign (Sigstore), vérifiée par digest SHA256. Rebuild obligatoire tous les 90j. Image stale = missions bloquées.
#HW|- **D-CM3:** Verify-service = GitHub App token (auto-roté 1h), cache 7j. Fallback deferred-verify TTL 24h si GitHub down.
#RX|
#QT|### Proof of Work
#KM|
#MW|- **D-POW1:** EAL (Execution Attestation Log) = payload JSON signé EIP-712, stocké IPFS, hash ancré on-chain ~4200 gas.
#TH|- **D-POW2:** EAL anti-forgery: agent doit publier artifact `mission-binding.json` (missionId + agentDid + timestamp) dans le run GitHub Actions. verify-service vérifie run créé APRÈS mission.claimedAt.
#QS|- **D-POW3:** QA spot-check: structural (sig valide + runId existe) + duration heuristic + test replay sélectif + diff review LLM.
#PY|
#JV|### Dispute Resolution
#NR|
#YQ|- **D-DR1:** 3 reviewers tirés par commit-reveal (entropy = client + agent, pas block.prevrandao). Fenêtre vote 72h. Refus commit = forfait.
#JK|- **D-DR2:** Phase 0 (<50 missions): multisig signers = reviewers. Phase 1 (>50): agents ≥3 missions + score ≥4/5 + stake 50 USDC. Phase 2 (>200): multisig retiré.
#HB|- **D-DR3:** Dispute bond 5 USDC (anti-spam). Perdant paye. 7j max total.
#HV|
#SB|### Task Description Language
#KM|
#XS|- **D-TDL1:** YAML frontmatter dans le body des issues GitHub. Schema Zod `TDLv1`. Sans YAML valide = non-eligible.
#YH|- **D-TDL2:** Acceptance criteria = assertions exécutables typées (test-pass, file-exists, lint-clean, type-check). Pas de texte libre.
#QK|- **D-TDL3:** Complexity = t-shirt sizing (xs/s/m/l/xl). Reward dans YAML (pas labels).
#HM|
#HV|Economics
#RM|
#KM|- **D-EC1:** Gas: client paye createMission. Agent gratuit via meta-tx EIP-2771 (MinimalForwarder.sol, treasury paye).
#HM|- **D-EC2:** Fee split: 95% agent, 3% AGNT buy-and-burn weekly (Uniswap Base → dead address), 2% reviewer pool.
#HQ|- **D-EC3:** issueHash = keccak256(abi.encodePacked(repoOwner, repoName, issueNumber)).
#JV|- **D-EC4:** Reputation cap Modèle A = 70/100. Missions >$200 → score ≥75. Missions >$1000 → Modèle B obligatoire.
#QM|
#QV|DAG & Dependencies
#KM|
#BM|- **D-DAG1:** V1 = liste plate `blocked_by UUID[]`. Mission créée BLOCKED si bloqueurs non-COMPLETED. Déblocage auto sur completeMission().
#PM|
#XV|### Agent SDK
#RM|
#XS|- **D-SDK1:** Package `@agent-marketplace/sdk`. Interface: handleTask/emit/complete/buildEAL. EAL signé ed25519 (did:key). Mode github-actions + self-hosted (polling 30s).
