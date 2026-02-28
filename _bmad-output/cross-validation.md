# Cross-Validation Report — Agent Marketplace
Date: 2026-02-27

---

## 🔴 Critical Conflicts (must resolve before coding)

### 1. Token Supply: 100M vs 1B
- **PRD.md** (lines 347, 761), **gtm-decisions.md** (line 103), **tech-spec-wip.md** (line 374): "100M $AGNT initial supply"
- **smart-contracts-spec.md** (line 30): "Total supply (1 billion at genesis)"
- **smart-contracts-spec.md** (line 841): `initialSupply=1_000_000_000e18`

**Resolution Required**: Confirm whether total supply is 100M or 1B. PRD/GTM/Tech-spec say 100M, but smart-contracts-spec says 1B. Recommend: 100M (aligns with PRD).

---

### 2. Protocol Fee: 1% vs 3%
- **PRD.md** (lines 339, 781): "Protocol fee: 1% of agent call cost"
- **smart-contracts-spec.md** (lines 370-372): Fee breakdown = 90% provider + 7% insurance + **3% burned**
- **architecture.md** (lines 170-172): MIN_PROTOCOL_FEE = 50 (0.5%), MAX_PROTOCOL_FEE = 300 (3%)

**Resolution Required**: Is protocol fee 1% or 3%? The 3% burn in smart-contracts-spec contradicts the 1% in PRD. Note: 1% fee + 7% insurance = 8% total deduction, but spec shows 10% total (3% burn + 7% insurance). Recommend: 1% protocol fee as per PRD.

---

### 3. Staking Minimum: 100 vs 1000 AGNT
- **PRD.md** (lines 288, 747): "Minimum stake: 100 $AGNT per agent"
- **gtm-decisions.md** (line 104): "Provider staking minimum: **1,000** $AGNT per agent (10× the PRD minimum)"
- **smart-contracts-spec.md** (line 844): `Min stake = 1000e18`

**Resolution Required**: Confirm minimum stake. PRD says 100, GTM/Spec say 1,000. GTM decision explicitly states "10× the PRD minimum" — was this intentional override? Recommend: 1,000 AGNT (as per GTM decision).

---

### 4. Insurance Pool Funding: 2% vs 7%
- **PRD.md** (line 972): Open question — "Start at 2%"
- **architecture-decisions.md** (line 44): "Pool funded by 2% of each provider's mission earnings"
- **smart-contracts-spec.md** (line 371): 7% to insurance pool (per mission fee breakdown)

**Resolution Required**: Is insurance pool 2% or 7% of provider earnings? PRD open question says 2%, but contract spec says 7%. Recommend: 2% (per architecture-decisions).

---

### 5. Token Distribution: 20% Team vs 15% Team
- **PRD.md** (lines 764-770): Team allocation = **20%**
- **architecture-decisions.md** (line 50): Team allocation = **15%**

**Resolution Required**: Team token allocation is 20% (PRD) vs 15% (arch decisions). Recommend: 15% (lower team = stronger community alignment signal per arch decisions rationale).

---

### 6. Mission State Machine: ASSIGNED vs ACCEPTED
- **PRD.md** (lines 275, 682): `CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED | DISPUTED`
- **smart-contracts-spec.md** (lines 351-359): Uses `ASSIGNED` instead of `ACCEPTED`
- **architecture.md** (lines 393-403): Uses `ACCEPTED`, adds `REFUNDED` state

**Resolution Required**: State machine has inconsistent naming. PRD/Architecture use ACCEPTED, Spec uses ASSIGNED. Also missing: RESOLVED (spec), REFUNDED (PRD). Recommend: Use PRD naming (ACCEPTED), add RESOLVED/REFUNDED as needed.

---

## 🟡 Minor Inconsistencies (clean up before MASTER.md)

### 7. Burn Mechanism Floor/Ceiling
- **PRD.md** (lines 783-784): Floor: 0.5%, Ceiling: 3%
- **gtm-decisions.md** (line 105): Floor 0.5%, ceiling 3% — CONSISTENT ✓

### 8. Team Vesting
- **PRD.md** (line 767): "4-year vest, 1-year cliff"
- **architecture-decisions.md** (line 58): "4-year vest, 1-year cliff" — CONSISTENT ✓

### 9. Unstake Timelock
- **PRD.md** (line 748): "Unstake timelock: 7 days"
- **smart-contracts-spec.md** (line 844): "Unstake cooldown = 7 days" — CONSISTENT ✓
- **architecture.md** (line 653): `UNSTAKE_TIMELOCK() = 7 days` — CONSISTENT ✓

### 10. Slash Penalty
- **PRD.md** (line 749): "Slash penalty: 10%"
- **smart-contracts-spec.md** (line 654): `SLASH_MAX_PERCENTAGE() = 1000 = 10%` — CONSISTENT ✓
- **architecture.md** (line 490): `SLASH_PERCENTAGE() = 1000 = 10%` — CONSISTENT ✓

### 11. V1/V2 Feature Scope
- **PRD.md** (lines 103-108): TEE, cross-chain, DAO, fiat on-ramp all deferred to V2
- **tech-spec-wip.md** (lines 130-135): Same V2 exclusions — CONSISTENT ✓
- **product-brief.md** (line 110): Lists TEE as part of "Zero Trust" — implies V1 intent?

### 12. Exchange Listing
- **PRD.md** (lines 108, 622): "No exchange listing at launch"
- **gtm-decisions.md**: "No exchange listing at launch" — CONSISTENT ✓
- **brainstorm-report.md** (line 21): "No exchange listing" — CONSISTENT ✓

### 13. Inter-Agent Discount
- **PRD.md** (line 355): "-20% on protocol fees for agent-to-agent"
- **PRD.md** (line 841): "-20% protocol fees" — CONSISTENT ✓
- **architecture.md** (line 792): `INTER_AGENT_DISCOUNT() = 2000 = 20%` — CONSISTENT ✓

### 14. Dry Run Pricing
- **PRD.md** (line 370): "Run 10% of mission at fixed mini-price ($1)"
- **PRD.md** (line 1039): "Dry run: 5-minute timeout"
- **smart-contracts-spec.md** (line 394): "5-min timeout, 10% price" — CONSISTENT ✓

### 15. Governance Timing
- **gtm-decisions.md** (line 106): "DAO voting starts after 1,000 missions completed OR 6 months post-launch (whichever comes first)"
- **PRD.md**: No explicit governance timing — MINOR GAP

### 16. Reputation Algorithm Weights
- **PRD.md** (lines 251-255): 40% success rate, 30% client score, 20% stake, 10% recency
- **tech-spec-wip.md** (lines 352-356): 40% success, 30% client score, 20% stake, 10% recency — CONSISTENT ✓

### 17. Genesis Agents Count
- **PRD.md** (line 457): "15-20 pre-selected agents live at launch"
- **PRD.md** (line 945): "15 live at launch"
- **gtm-decisions.md** (line 124): "15 agents" — CONSISTENT ✓

### 18. Insurance Pool Payout Cap
- **architecture-decisions.md** (line 42): "2x mission value cap"
- **PRD.md**: No explicit cap mentioned — MINOR GAP

### 19. Database: PostgreSQL vs The Graph
- **architecture-decisions.md** (line 68): "PostgreSQL for V1 speed, migrate to The Graph V2"
- **tech-spec-wip.md** (line 420): "On-chain events indexing (The Graph subgraph)"
- Minor: Tech spec references The Graph directly, but arch decisions say PostgreSQL for V1

### 20. Mission Delivery Method
- **PRD.md** (line 1039): "On-chain events — agent listens L2 events via RPC provider"
- **architecture.md**: Shows "Agent Execution Environment" separate from blockchain (conceptually consistent but not explicit)

---

## 🟢 Missing Specs (need to be written)

### 21. Mission DNA Implementation
- **PRD.md** (lines 379-391): Describes feature but no implementation spec
- No API endpoint defined
- No matching algorithm detailed beyond "embed mission description"

### 22. Insurance Pool Smart Contract Interface
- Referenced in PRD (F13) and architecture-decisions
- No detailed interface in smart-contracts-spec.md
- Should define: `claim()`, `fund()`, `getBalance()`, `calculatePayout()`

### 23. Dispute Resolution Mechanism
- **PRD.md** (line 274): "Dispute flow with arbitration mechanism"
- **PRD.md** (line 538): "resolveDispute() — Governance or arbiter"
- No defined: Who is arbiter? What are criteria? How long to resolve?
- **architecture-decisions.md** (line 41): "Objective criteria" mentioned but not detailed

### 24. Inter-Agent Protocol API Endpoints
- **PRD.md** (lines 789-843): Describes partner network, auctions, treasury
- **tech-spec-wip.md** (lines 297-301): Only 2 endpoints listed
- Missing: Auction creation, bid submission, treasury management, guild operations

### 25. Webhook Specifications (Enterprise)
- **PRD.md** (line 859): "Webhook support" mentioned for enterprise API
- No detailed webhook events defined (mission.created, mission.completed, etc.)

### 26. Testnet Contract Addresses
- **smart-contracts-spec.md** (lines 830-837): All addresses = "0x..." (TBD)
- No Base Sepolia deployment addresses

### 27. TEE Attestation Flow (V2)
- **PRD.md**: Deferred to V2
- No interface defined for Intel SGX / AWS Nitro attestation
- Should define: `attest()`, `verifyAttestation()`, `getEnclavePublicKey()`

### 28. ZK Proof Integration (V2)
- **PRD.md** (lines 592-602): Feature described
- No circuit specifications or on-chain verification interface

### 29. DAO Governance Contract (V3)
- **PRD.md**: Deferred to V3
- No voting mechanism, proposal flow, or timelock defined

### 30. Guild Smart Contract
- **PRD.md** (lines 552-564): Guild feature in V2 Could Have
- No detailed interface for: guild creation, membership, shared reputation, revenue split

---

## ✅ Validated (consistent across all docs)

| Decision | Value | Locations |
|----------|-------|-----------|
| Network | Base L2 (Ethereum) | PRD, Architecture, Tech-spec |
| Token Symbol | $AGNT | All docs |
| Mission payments | USDC | PRD, Brainstorm, GTM |
| Escrow pattern | 50% upfront, 50% on approval | PRD, Smart-contracts-spec, Architecture |
| Slash on dispute | 10% of stake | PRD, Smart-contracts-spec, Architecture |
| Unstake timelock | 7 days | PRD, Smart-contracts-spec, Architecture |
| Inter-agent discount | 20% | PRD, Architecture |
| Dry run timeout | 5 minutes | PRD, Smart-contracts-spec |
| Auto-approve timeout | 48 hours | PRD, Smart-contracts-spec |
| Reputation weights | 40/30/20/10 | PRD, Tech-spec |
| TEE | Deferred to V2 | PRD, Tech-spec |
| Exchange listing | Not at launch | PRD, Brainstorm, GTM |
| Fiat on-ramp | Deferred to V2 | PRD |
| Mobile app | Deferred to V2 | PRD |
| DAO governance | Deferred to V3 | PRD |
| Cross-chain | Deferred to V2 | PRD |
| Genesis agents | 15 at launch | PRD, GTM |
| Team vesting | 4-year cliff 1-year | PRD, Architecture-decisions |
| Protocol fee floor | 0.5% | PRD, GTM, Architecture |
| Protocol fee ceiling | 3% | PRD, GTM, Architecture |

---

## Summary

| Category | Count |
|----------|-------|
| Critical Conflicts | 6 |
| Minor Inconsistencies | 14 (mostly validated) |
| Missing Specs | 10 |
| Validated Items | 24 |

**Recommendation**: Resolve critical conflicts #1-6 before coding begins. Fill missing specs #21-30 during implementation of respective features.
