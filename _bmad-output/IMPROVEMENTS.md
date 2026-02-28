# IMPROVEMENTS.md — Audit Corrections Applied

> Generated: 2026-02-28
> Source: GPT Audit Review

---

## Executive Summary

This document captures all corrections applied to the Agent Marketplace documentation based on a brutal GPT audit. The audit identified critical gaps: unrealistic sprint planning, misleading security claims, missing indexer architecture, dishonest tokenomics, absent cold-start budget, and crypto-onboarding friction.

**Changes Applied:** 10 major corrections across 2 files
**Status:** Complete — ready for implementation

---

## Changes Applied

### 1. Sprint Plan — Realistic Timeline

**File:** `_bmad-output/MASTER-v2.md` (Section 12)

**Problem:** Original 8-week plan was fantasy — attempted to ship 4 smart contracts + full API + 2 SDKs + frontend + pgvector matching + inter-agent protocol + webhooks in 8 weeks.

**Correction Applied:**
- **Sprint 1-2 (Weeks 1-2):** Smart Contracts only — AGNTToken, AgentRegistry, MissionEscrow, ProviderStaking + Hardhat tests (90% coverage target) + Base Sepolia deployment
- **Sprint 3-4 (Weeks 3-4):** Core API only — Agent CRUD + Mission lifecycle + JWT/SIWE auth + PostgreSQL schema + basic blockchain event listener (ethers.js → BullMQ → PostgreSQL). NO WebSocket yet.
- **Sprint 5-6 (Weeks 5-6):** Minimal UI — Agent listing + search (tag filter only, no pgvector yet) + Mission creation flow + Provider dashboard + Wagmi/RainbowKit wallet connect
- **Sprint 7-8 (Weeks 7-8):** Testnet Alpha — E2E flow on Base Sepolia + provider onboarding + bug fixes + internal testing with genesis agents

**New Section Added:** "V1.5 Features (Weeks 9-16)" containing:
- SDK (TypeScript + Python)
- pgvector / Mission DNA matching
- Dry run
- Inter-agent protocol
- Webhooks
- WebSocket for real-time events

**Revised Milestones:**
| Milestone | Target |
|-----------|--------|
| Contracts on Base Sepolia | Week 4 |
| API core complete | Week 6 |
| Basic UI | Week 8 |
| Alpha testnet (5-10 providers) | Week 12 |
| V1.5 (SDK + pgvector + dry run) | Week 16 |
| Inter-agent protocol | Week 20 |
| Mainnet launch | Week 24 |

---

### 2. Security — Remove Zero-Trust V1 Claims

**File:** `_bmad-output/MASTER-v2.md` (Section 9)

**Problem:** Documentation claimed "Zero-trust security stack" as a V1 feature. TEE was listed as deferred to V2 but marketing language conflicted with this.

**Correction Applied:**
- Updated Section 9: Security to explicitly state:
  - **V1:** "Smart Contract Security + E2E Encryption (AES-256-GCM for mission payloads)"
  - **V2:** "Zero-Trust: TEE attestation (Intel SGX / AWS Nitro Enclaves)"
- Added clear note: "V1 does NOT include TEE. Enterprise zero-trust pitch is V2+."
- Removed "Zero-trust" from Section 1.3 Differentiators — replaced with honest "Smart contract escrow + E2E encryption (V1) / TEE (V2)"

---

### 3. Blockchain Indexer Architecture

**File:** `_bmad-output/MASTER-v2.md` (NEW section after Database Schema)

**Problem:** No specification for how blockchain events are indexed to PostgreSQL. Original spec just said "PostgreSQL" with no implementation detail.

**Correction Applied:** Added new section "Indexer Architecture (V1)" with:
- Component: `indexer/` service (Node.js + ethers.js)
- Pattern: Event listener → validate → BullMQ job → PostgreSQL write
- Events to watch: MissionCreated, MissionAccepted, MissionDelivered, MissionCompleted, MissionDisputed, AgentRegistered, ReputationUpdated, StakeDeposited, StakeSlashed
- Reorg handling: Track block numbers, rollback up to 12 blocks on reorg detection
- Retry: BullMQ exponential backoff (3 retries, max 30s delay)
- RPC failover: Primary Alchemy, fallback Infura (env-configurable)

---

### 4. Token Economics — Honest Burn Numbers

**File:** `_bmad-output/MASTER-v2.md` (Section 8)

**Problem:** Claimed "deflationary token model" with 3% burn. Original spec didn't include honest math.

**Correction Applied:** Added "Burn Reality Check" subsection:
- At 10K missions/month × $1K avg = $10M volume
- 3% burn of 10% fee = 0.3% of volume = $30K/month burned
- At $0.10/token = 300K tokens/month burned = 0.3% annual burn
- **Conclusion:** NOT strongly deflationary — symbolic burn only

**Added Revised Burn Strategy — Two Options:**
- **Option A (Recommended):** Keep 3% burn, add governance value narrative (token = voting rights, not deflation)
- **Option B:** Increase burn to 8%, reduce treasury to 0%, rely on protocol fee revenue instead

**Added new section: Staking Yield (V1.5)**
- 5% APY from treasury allocation
- Requires governance vote to activate
- **V1 has NO staking yield** — providers stake for listing rights only

---

### 5. Cold Start Budget

**File:** `_bmad-output/MASTER-v2.md` (NEW section)

**Problem:** Original GTM mentioned "bounty program" but had no explicit budget or timeline.

**Correction Applied:** Added "Genesis Program (5M AGNT = 5% of total supply)"
- 50K AGNT per validated genesis agent (target: 100 genesis agents = 5M AGNT)
- Validation criteria: agent must complete 10 test missions with score ≥ 8/10
- Client credits: First 200 clients get 500 AGNT credit for first mission (total: 100K AGNT)
- Hackathon pool: 15M AGNT (already allocated) — 3-month bounty program

**Cold Start Timeline:**
- Month 1-2: Recruit 10 internal genesis agents (team-operated)
- Month 3: Open genesis program to external providers
- Month 4-6: Activate demand (free mission credits)
- Month 7+: Self-sustaining marketplace

---

### 6. Fiat-First Onboarding

**File:** `_bmad-output/MASTER-v2.md` (NEW section)

**Problem:** Original spec assumed users would buy crypto, bridge to Base, acquire AGNT — massive friction for target users (engineering teams).

**Correction Applied:** Added "User Onboarding: Fiat-First Design"
- **V1 approach:** Users pay in USD via Stripe → Platform converts USD → USDC → handles AGNT mechanics transparently → Users see mission price in USD only → Crypto wallet optional (for advanced users / providers who want on-chain reputation)
- **V2 approach:** Full crypto-native experience, direct wallet payment, on-chain everything
- **Target user V1:** "engineering teams who want results" not "crypto-native users"

---

### 7. Dry Run — Hero Feature

**File:** `_bmad-output/MASTER-v2.md` (Multiple sections)

**Problem:** Dry run was buried in Sprint 4 as an "advanced feature."

**Correction Applied:**
- Added dry run to Section 0 (Canonical Values Quick Reference) as a highlighted feature
- Added to Section 1 (Product Vision) as a key differentiator
- Moved dry run implementation from Sprint 4 to Sprint 3 (implement alongside mission flow)
- Added UX note: "Dry run is the primary conversion mechanism — it removes the leap of faith barrier. It must be frictionless: one click, visible progress, clear output within 5 minutes."

---

### 8. Specs Index — New Items

**File:** `_bmad-output/MASTER-v2.md` (Section 11)

**Problem:** Specs Index missing critical V1/V1.5 spec documents.

**Correction Added:**
- `blockchain-indexer-spec.md` — NEW — to be created
- `fiat-onramp-spec.md` — NEW — to be created
- `genesis-program-spec.md` — NEW — to be created

---

### 9. Product Brief — GTM Updates

**File:** `_bmad-output/planning-artifacts/product-brief.md`

**Problem:** GTM section had vague "bounty program" and fictional "5 anchor startups committed from day 1."

**Correction Applied:**
- Replaced vague "bounty program" with explicit Genesis Program details (matching Section 6 above)
- Replaced "5 anchor startups committed from day 1" with honest language: "Pre-launch outreach target: 5 design partners willing to pilot in alpha phase (paid or unpaid)"

---

### 10. Out of Scope V1 — Updated

**File:** `_bmad-output/MASTER-v2.md` (Section 13)

**Added to explicit deferral list:**
- Fiat on-ramp (moved to V1 with fiat-first design)
- SDK (moved to V1.5)
- pgvector matching (moved to V1.5)
- Dry run (moved to V1)
- WebSocket (moved to V1.5)

---

## Files Modified

| File | Changes |
|------|---------|
| `_bmad-output/MASTER-v2.md` | 10 corrections applied |
| `_bmad-output/planning-artifacts/product-brief.md` | 1 correction applied |
| `_bmad-output/IMPROVEMENTS.md` | Created (this file) |

---

## Open Questions for Ju

1. **Token Launch Mechanics:** How is the token initially distributed? Liquidity provision? Launch on DEX? This is critical for Day 1 usability.

2. **Insurance Pool Mechanics:** What happens when the pool is empty? Who's backstop? What's the claim process? The spec says "5% of fees" but doesn't say what happens when claims > pool.

3. **Provider Classification:** How are providers legally classified? Contractors? Employees? This has tax and liability implications.

4. **Price Discovery:** How do agents set prices? Is there a market mechanism or just fixed pricing? What prevents price fixing?

5. **Exit/Cancellation:** What happens if a provider goes offline mid-mission? What if an agent is delisted? These edge cases need specs.

6. **Legal Entity:** Who operates this? Under what jurisdiction? This is existential for regulatory compliance.

---

## Summary

The documentation is now honest about:
- What can ship in 8 weeks (contracts + basic API + minimal UI)
- What's V1.5 (SDK, pgvector, dry run, inter-agent)
- What requires V2 (TEE, full crypto-native, enterprise features)
- The real tokenomics (symbolic burn, governance narrative)
- The cold start budget (explicit AGNT allocation)
- The fiat-first onboarding (Stripe → USD, crypto optional)

**Status:** Ready for implementation planning.
