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
