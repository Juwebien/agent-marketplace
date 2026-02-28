# Architecture Decisions — Agent Marketplace

**Date:** 2026-02-27  
**Status:** Final  
**Context:** Base L2 decentralized AI agent marketplace

---

### Decision 1: Reputation Scoring Algorithm

**Choice:** Weighted average (recent missions > old, large > small)

**Rationale:**
1. Already aligned with PRD-defined weights (40% success rate, 30% client score, 20% stake, 10% recency) — minimizes spec churn
2. Recency weighting naturally handles agent improvement/degradation over time without complex ELO-style volatility
3. Mission size weighting (implied by "large > small" in mission value) prevents gaming via micro-missions

**Implementation note:** Store mission value (USDC) alongside outcome; weight each mission's reputation impact by `log(missionValue + 1)` to prevent single-large-mission dominance while still valuing larger missions.

---

### Decision 2: Mission DNA / Matching Algorithm

**Choice:** Hybrid (embeddings for discovery, tags for filtering)

**Rationale:**
1. Pure embeddings lack precision for skill verification — a "Kubernetes" agent shouldn't match "Docker" queries just because text similarity is high
2. Tags provide deterministic, auditable matching criteria essential for enterprise compliance and dispute resolution
3. Embeddings enable discovery of agents with related but non-identical capabilities (e.g., "monitoring" agent finds "observability" agents)

**Implementation note:** Run embeddings (sentence-transformers/all-MiniLM-L6-v2) as secondary ranking layer after tag intersection filter. Display both: "94% tag match + 87% semantic similarity."

---

### Decision 3: Insurance Pool Mechanics

**Choice:** Smart contract objective criteria + 2x max payout

**Rationale:**
1. DAO votes introduce governance overhead and timing uncertainty — V1 needs automated, predictable resolution
2. Objective criteria (timeout > 48h, failed delivery + provider stake exhausted) are enforceable on-chain without subjectivity
3. 2x mission value cap prevents pool depletion while providing meaningful enterprise coverage

**Implementation note:** Pool funded by 2% of each provider's mission earnings (deducted at escrow release). Claims auto-processed when: (a) mission times out OR (b) dispute ruled against provider AND provider stake < refund amount. Pool address: `InsurancePool.sol` with `claim()` function callable by client post-dispute resolution.

---

### Decision 4: Token Distribution at Launch

**Choice:** Team 15% | Genesis agents 20% | Hackathon/bounties 15% | Treasury 25% | Community/ecosystem 25%

**Rationale:**
1. Lower team allocation (15% vs PRD 20%) signals alignment — team earns via vesting but community owns the protocol
2. Genesis agents 20% seeds supply-side liquidity — without agents, marketplace has no product
3. Community 25% + hackathon 15% = 40% total for ecosystem bootstrapping (higher than typical 20-30%) reflects cold-start priority

**Implementation note:** 
- Team: 4-year vest, 1-year cliff (same as PRD)
- Genesis agents: 6-month linear unlock, allocated per-agent by governance vote at launch
- Hackathon/bounties: 12-month program budget, paid as missions complete
- Treasury: Multi-sig (3/5), funds protocol development, insurance pool backstop
- Community: Airdrop to early wallet addresses + liquidity mining rewards

---

### Decision 5: The Graph vs Custom Indexer

**Choice:** Hybrid (PostgreSQL for V1 speed, migrate to The Graph V2)

**Rationale:**
1. V1 speed matters — reputation queries must be <500ms for UI responsiveness; The Graph can take 10-30s on Base
2. Custom indexer enables rapid iteration on reputation algorithms without subgraph redeployment
3. Hybrid approach: ship fast with Postgres, build toward decentralization for V2 per protocol roadmap

**Implementation note:** Indexer runs as API service (separate from node): listens to `MissionCompleted` / `MissionDisputed` events via Base RPC (Alchemy), writes to PostgreSQL `reputation` table. Query layer: `GET /api/reputation/:agentId` returns cached score + mission history. V2: export indexer data to The Graph subgraph, switch read path.

---

## Summary

| Decision | Choice |
|----------|--------|
| 1. Reputation | Weighted average (40% success / 30% score / 20% stake / 10% recency) |
| 2. Matching | Hybrid (tags filter + embeddings rank) |
| 3. Insurance | Objective criteria in contract + 2x payout cap |
| 4. Token Dist | 15% team / 20% genesis / 15% hackathon / 25% treasury / 25% community |
| 5. Indexer | PostgreSQL (V1) → The Graph (V2) |

---

*Decisions documented — implementation ready.*
