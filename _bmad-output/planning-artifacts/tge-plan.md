# $AGNT Token Generation Event (TGE) Plan

**Version:** 1.0  
**Date:** 2026-02-28  
**Status:** Final  
**Author:** Token Economics Team

---

## Executive Summary

This document defines the complete Token Generation Event mechanics for $AGNT, the native token of Agent Marketplace. The TGE is designed to distribute tokens without public sale, prioritizing long-term alignment through vesting schedules and utility-driven token emission.

**Key Parameters:**
| Parameter | Value |
|-----------|-------|
| Total Supply | 100,000,000 AGNT |
| Initial Circulating Supply | 0 AGNT (fully locked at TGE) |
| TGE Date | TBD (post-audit completion) |
| Network | Base L2 (Ethereum) |
| Token Standard | ERC-20 |

---

## 1. Token Generation Event Mechanics

### 1.1 Distribution Summary

| Category | Amount (AGNT) | % | Vesting Schedule | TGE Release |
|----------|---------------|---|-------------------|-------------|
| Team + Advisors | 15,000,000 | 15% | 4-year linear, 1-year cliff | 0% |
| Genesis Agents | 20,000,000 | 20% | 6-month linear | 0% |
| Hackathon + Bounties | 15,000,000 | 15% | 12-month programmatic | ~1.25M/mo |
| Protocol Treasury | 25,000,000 | 25% | Multi-sig controlled | Immediate |
| Community + Ecosystem | 25,000,000 | 25% | Airdrop + incentives | TBD |
| **TOTAL** | **100,000,000** | **100%** | | |

### 1.2 No ICO / No Public Sale

**Rationale:** Following the V1 mandate, there is no ICO or public token sale. Tokens enter circulation through:

1. **Staking Rewards** — 2M AGNT/year from treasury
2. **Hackathon Prizes** — Monthly budget of 1.25M AGNT
3. **Genesis Agent Allocation** — 6-month linear unlock
4. **Community Incentives** — Future airdrops and liquidity programs
5. **Treasury Operations** — Protocol development spending

### 1.3 Genesis Mint Process

```
┌─────────────────────────────────────────────────────────────┐
│                    GENESIS MINT FLOW                        │
├─────────────────────────────────────────────────────────────┤
│  1. Team Multisig (3/5) approves TGE execution             │
│  2. AGNTToken.mint(TreasuryMultisig, 100M)                 │
│  3. Treasury Multisig distributes to vesting contracts:     │
│     ├── VestingWallet (Team): 15M                           │
│     ├── VestingWallet (Genesis): 20M                        │
│     ├── VestingWallet (Hackathon): 15M                      │
│     └── Treasury remains: 50M (25M protocol + 25M community)│
│  4. Staking contract receives 2M AGNT for Year 1 rewards   │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Vesting Contracts

We use OpenZeppelin's `VestingWallet` with the following configurations:

| Contract | Beneficiary | Total Amount | Cliff | Duration | Revocable |
|----------|-------------|--------------|-------|----------|-----------|
| TeamVesting | Team Multisig | 15M AGNT | 12 months | 48 months | No |
| GenesisVesting | Genesis Agent Vault | 20M AGNT | 0 months | 6 months | Yes* |
| HackathonVesting | Program Vault | 15M AGNT | 0 months | 12 months | Yes |

*Genesis vesting is revocable if agent loses Genesis status (see Section 3).

---

## 2. Liquidity Strategy (No Exchange Listing)

### 2.1 Internal Liquidity Mechanism

Since there is no CEX listing at launch, liquidity is provided through:

| Source | Mechanism | Size |
|--------|-----------|------|
| Protocol Treasury | USDC reserves for buyback | TBD (5M AGNT worth) |
| Staking Rewards | Rewards distributed, not sold | 2M AGNT/year |
| Marketplace | AGNT:USDC trading pair (internal) | AMM-like mechanism |

**Buyback Trigger:** If AGNT price falls below $0.05 (50% of launch), treasury may execute buyback using USDC reserves.

### 2.2 Price Discovery

**Initial Phase (Months 1-6):**
- Admin-set price: $0.10 AGNT/USDC
- Used for staking calculations, hackathon valuations

**Discovery Phase (Months 6+):**
- Price adjusts based on:
  - Cumulative burn pressure
  - Staking demand
  - Mission volume
- Formula: `price = $0.10 × (1 + 0.02 × cumulativeBurn/100k)`

### 2.3 Staking APY Source

```
Annual Staking Budget: 2,000,000 AGNT (2% of treasury)
Distribution: Proportional to staked amount × tier multiplier
```

---

## 3. Genesis Agent Token Allocation

### 3.1 Allocation Details

| Parameter | Value |
|-----------|-------|
| Total Genesis Pool | 20,000,000 AGNT |
| Number of Genesis Agents | 15 |
| Per-Agent Allocation | 1,333,333.33 AGNT |
| Unlock Schedule | 6-month linear (222,222/month) |
| Minimum Stake | 100,000 AGNT |

### 3.2 Eligibility Criteria

- **Technical:** 99.5% uptime SLA, <5s latency, 100K+ context window
- **Skill Coverage:** 6 verticals (DevOps×3, Data×3, Security×2, CodeReview×2, Frontend×2, Backend×3)
- **Application:** 2-week vetting (app → interview → test mission → approval)

### 3.3 Vesting Terms

```
Timeline:
Month 0: Genesis badge awarded, staking begins
Month 1-6: 222,222 AGNT unlocks each month (if conditions met)
Month 6+: Full vesting complete, tokens freely transferable
```

### 3.4 Slash Conditions

If a Genesis Agent fails to maintain requirements:

| Violation | Consequence |
|-----------|-------------|
| Uptime < 99.5% for 30 days | Warning, 30-day cure period |
| Uptime < 99% for 7 days | Immediate slash: 50% of unvested |
| Genesis badge revoked | Forfeit ALL unvested tokens |
| Misconduct / fraud | Forfeit ALL tokens, potential legal action |

**Slash Recovery:** Slashed tokens return to GenesisVesting contract for future distribution.

---

## 4. Hackathon Token Budget

### 4.1 Program Structure

| Parameter | Value |
|-----------|-------|
| Duration | 12 months |
| Monthly Budget | 1,250,000 AGNT |
| Total Budget | 15,000,000 AGNT |

### 4.2 Monthly Distribution

| Category | AGNT Allocation | % of Monthly |
|----------|-----------------|--------------|
| 1st Place | 300,000 | 24% |
| 2nd Place | 200,000 | 16% |
| 3rd Place | 100,000 | 8% |
| Category Prizes (5×) | 50,000 each | 40% |
| Community Participation | 75,000 | 6% |
| Admin/Adjustments | 75,000 | 6% |

### 4.3 Anti-Gaming Measures

- **Vesting:** All prizes vest over 3 months (no cliff)
- **Anti-sybil:** GitHub account age requirement (6 months)
- **Anti-bot:** Manual verification of deliverables
- **Reallocation:** Unclaimed prizes roll into next month

---

## 5. Treasury Allocation

### 5.1 Breakdown

| Fund | Amount (AGNT) | Purpose | Multisig Signers |
|------|---------------|---------|------------------|
| Protocol Development | 10,000,000 | Ops, infra, hiring | 3/5 |
| Insurance Pool Backstop | 5,000,000 | Fiat equivalent emergency | 3/5 |
| Marketing + BD + Grants | 5,000,000 | Ecosystem growth | 3/5 |
| Strategic Reserves | 5,000,000 | Opportunistic use | 3/5 |
| **TOTAL** | **25,000,000** | | |

### 5.2 Spending Guidelines

**Protocol Development (10M):**
- Core team salaries
- Infrastructure costs (AWS/GCP)
- Auditor fees
- Tooling and licenses

**Insurance Pool Backstop (5M):**
- Fiat equivalent kept in USDC
- Emergency claims coverage
- Replenishes if pool depleted

**Marketing + BD (5M):**
- Hackathon sponsorships
- Developer evangelism
- B2B sales collateral
- Partner grants

**Strategic Reserves (5M):**
- Unexpected opportunities
- Competitive responses
- Legal/regulatory contingencies

---

## 6. Staking Reward Model

### 6.1 Reward Distribution

```
Annual Pool: 2,000,000 AGNT
Distribution Formula: 
  reward = (staker_stake × tier_multiplier / total_weighted_stake) × 2,000,000
```

### 6.2 Tier Multipliers

| Tier | Stake Range | Multiplier | Base APY (if 25% staked) |
|------|-------------|------------|--------------------------|
| Bronze | 1,000 - 9,999 AGNT | 1.0x | 8% |
| Silver | 10,000 - 99,999 AGNT | 1.5x | 12% |
| Gold | 100,000+ AGNT | 2.0x | 16% |

### 6.3 APY Scenarios

Assuming 2M AGNT annual reward pool:

| Participation Rate | Total Staked | Bronze APY | Silver APY | Gold APY |
|--------------------|--------------|------------|------------|----------|
| 10% of float* | 7.5M AGNT | 26.7% | 40.0% | 53.3% |
| 25% of float | 18.75M AGNT | 10.7% | 16.0% | 21.3% |
| 50% of float | 37.5M AGNT | 5.3% | 8.0% | 10.7% |

*Float = tokens not locked in vesting (approximately 75M at launch)

---

## 7. Burn Projections (24 Months)

### 7.1 Methodology

Using the mission growth model from `financial-model.md`:

- **Month 1:** 500 missions
- **Months 1-12:** 30% MoM growth
- **Months 13-24:** 15% MoM growth
- **Average Mission Value:** $45 USDC
- **Protocol Fee:** 3% of USDC value → burned as AGNT
- **Initial AGNT Price:** $0.10

**Formula:**
```
Monthly Burn = missions × $45 × 0.03 / $0.10
```

### 7.2 Burn Projection Table

| Month | Missions | Volume (USDC) | AGNT Burned | Cumulative Burn | Supply Remaining |
|-------|----------|---------------|-------------|-----------------|------------------|
| 1 | 500 | $22,500 | 6,750 | 6,750 | 99,993,250 |
| 2 | 650 | $29,250 | 8,775 | 15,525 | 99,984,475 |
| 3 | 845 | $38,025 | 11,408 | 26,933 | 99,973,067 |
| 4 | 1,099 | $49,433 | 14,830 | 41,763 | 99,958,237 |
| 5 | 1,428 | $64,262 | 19,279 | 61,042 | 99,938,958 |
| 6 | 1,857 | $83,565 | 25,070 | 86,111 | 99,913,889 |
| 7 | 2,414 | $108,633 | 32,590 | 118,701 | 99,881,299 |
| 8 | 3,138 | $141,223 | 42,367 | 161,068 | 99,838,932 |
| 9 | 4,080 | $183,590 | 55,077 | 216,145 | 99,783,855 |
| 10 | 5,304 | $238,667 | 71,600 | 287,745 | 99,712,255 |
| 11 | 6,895 | $310,267 | 93,080 | 380,825 | 99,619,175 |
| 12 | 8,963 | $403,347 | 121,004 | 501,829 | 99,498,171 |
| 13 | 10,308 | $463,847 | 139,154 | 640,983 | 99,359,017 |
| 14 | 11,854 | $533,424 | 160,027 | 801,010 | 99,198,990 |
| 15 | 13,632 | $613,438 | 184,031 | 985,041 | 99,014,959 |
| 16 | 15,677 | $705,454 | 211,636 | 1,196,677 | 98,803,323 |
| 17 | 18,028 | $811,272 | 243,382 | 1,440,059 | 98,559,941 |
| 18 | 20,732 | $932,963 | 279,889 | 1,719,948 | 98,280,052 |
| 19 | 23,842 | $1,072,907 | 321,872 | 2,041,820 | 97,958,180 |
| 20 | 27,418 | $1,233,843 | 370,153 | 2,411,973 | 97,588,027 |
| 21 | 31,531 | $1,418,920 | 425,676 | 2,837,649 | 97,162,351 |
| 22 | 36,260 | $1,631,758 | 489,527 | 3,327,176 | 96,672,824 |
| 23 | 41,699 | $1,876,522 | 562,957 | 3,890,133 | 96,109,867 |
| 24 | 47,954 | $2,158,000 | 647,400 | 4,537,533 | 95,462,467 |

### 7.3 Supply Curve

```
Month 0:  100,000,000 (TGE)
Month 6:  99,913,889 (-0.09%)
Month 12: 99,498,171 (-0.50%)
Month 18: 98,280,052 (-1.72%)
Month 24: 95,462,467 (-4.54%)
```

### 7.4 Breakeven Analysis

**Breakeven Definition:** Monthly burn rate equals new token emissions (staking rewards + hackathon + genesis)

**Monthly Emissions:**
- Staking rewards: 166,667 AGNT/month
- Hackathon: 1,250,000 AGNT/month (average)
- Genesis: ~333,333 AGNT/month (first 6 months only)

**Total Monthly Emissions:** ~1,750,000 AGNT/month (Y1)

**Breakeven Calculation:**

| Month | Monthly Burn | Monthly Emissions | Net Position |
|-------|--------------|-------------------|--------------|
| 1 | 6,750 | 1,750,000 | -1,743,250 |
| 6 | 25,070 | 1,750,000 | -1,724,930 |
| 12 | 121,004 | 1,416,667* | -1,295,663 |
| 18 | 279,889 | 1,250,000** | -970,111 |
| 24 | 647,400 | 1,250,000 | -602,600 |

*After genesis vesting ends (Month 7+)
**Hackathon only after Month 12

**Observation:** With current parameters, burn rate never exceeds emissions within 24 months. This is intentional — aggressive deflation begins in Year 3+ when:
- Genesis vesting complete (no new emissions)
- Burn rate exceeds 1M/month
- Treasury emissions reduce

**Breakeven Burn Point: Month ~36** (when cumulative burn approaches 10M and emissions decline)

---

## 8. Smart Contract Addresses

### 8.1 Contract Inventory

| Contract | Network | Address | Status |
|----------|---------|---------|--------|
| AGNTToken | Base | TBD | Not deployed |
| VestingWallet (Team) | Base | TBD | Not deployed |
| VestingWallet (Genesis) | Base | TBD | Not deployed |
| VestingWallet (Hackathon) | Base | TBD | Not deployed |
| TreasuryMultisig | Base | TBD | Not deployed |
| InsurancePool | Base | TBD | Not deployed |
| ProviderStaking | Base | TBD | Not deployed |
| AgentRegistry | Base | TBD | Not deployed |
| MissionEscrow | Base | TBD | Not deployed |

### 8.2 Deployment Sequence

```
1. Deploy TreasuryMultisig (3/5) — multisig wallet setup
2. Deploy AGNTToken — token contract
3. Deploy VestingWallet (Team) — 15M, beneficiary: team multisig
4. Deploy VestingWallet (Genesis) — 20M, beneficiary: genesis vault
5. Deploy VestingWallet (Hackathon) — 15M, beneficiary: program admin
6. Deploy ProviderStaking — staking contract
7. Deploy AgentRegistry — agent management
8. Deploy MissionEscrow — mission lifecycle
9. Execute Genesis Mint — mint 100M to treasury
10. Distribute to vesting contracts
```

### 8.3 Multisig Configuration

**TreasuryMultisig (3/5):**
- Signer 1: [TBD - Founder/CEO]
- Signer 2: [TBD - CTO]
- Signer 3: [TBD - Head of Operations]
- Signer 4: [TBD - External Advisor 1]
- Signer 5: [TBD - External Advisor 2]

Quorum: 3/5 signatures required for any transaction.

---

## 9. Governance

### 9.1 Tokenholder Rights

- **Voting:** 1 AGNT = 1 vote (simple majority)
- **Proposals:** Require 1M AGNT to submit
- **Execution:** 5M AGNT quorum for execution
- **Delay:** 48-hour execution timelock

### 9.2 Governance Launch

Per MASTER.md: Governance activates after 1,000 missions OR 6 months post-launch (whichever first).

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Low staking participation | Medium | High | Marketing push, tier incentives |
| Genesis agent dropout | Low | Medium | 15 agents = buffer for 3-5 dropouts |
| Treasury depletion | Medium | High | 25M reserve, phased spending |
| Regulatory uncertainty | Medium | High | Compliance-first, no public sale |
| Smart contract exploit | Low | Critical | Full audit (3 firms), bug bounty |

---

## 11. Appendix: Key Formulas

### Staking Reward Calculation
```
tier_multiplier = {
  BRONZE: 1.0,  // 1,000 - 9,999
  SILVER: 1.5,  // 10,000 - 99,999
  GOLD: 2.0     // 100,000+
}

weighted_stake = staked_amount × tier_multiplier
staker_reward = (weighted_stake / total_weighted_stakes) × 2,000,000
```

### Burn Calculation
```
protocol_fee_usdc = mission_value × 0.03
burn_amount_agnt = protocol_fee_usdc / agnt_price
```

### Price Adjustment
```
price_floor = $0.10 × (1 + 0.02 × cumulativeBurn / 100,000)
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-28 | Token Economics Team | Initial TGE plan |

---

**Breakeven burn at month ~36** (when cumulative emissions decline and burn rate exceeds 1M/month)
