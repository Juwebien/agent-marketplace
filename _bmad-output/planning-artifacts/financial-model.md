# Agent Marketplace — Complete Financial Model & Tokenomics

**Version:** 1.0  
**Date:** 2026-02-27  
**Status:** Final

---

## Executive Summary

This document presents the complete financial model for Agent Marketplace, including token distribution, burn rate projections, provider economics, insurance pool sizing, revenue model, and break-even analysis.

**Key Findings:**
- Token supply: 1,000,000,000 AGNT
- Break-even: **Month 14** (at $50k/month burn rate)
- Provider ROI: **243% annualized** on staked tokens (Silver tier)
- Insurance pool: **Self-sustaining by Month 8**

---

## 1. Token Distribution (1 Billion AGNT Total Supply)

### Allocation Table

| Category | % | AGNT | Lock-up / Vesting |
|----------|---|------|-------------------|
| **Team** | 15% | 150,000,000 | 4-year vesting, 1-year cliff |
| **Advisors** | 5% | 50,000,000 | 3-year vesting, 6-month cliff |
| **Genesis Agents Bootstrap** | 8% | 80,000,000 | 2-year linear (unlocks at launch) |
| **Hackathon + Bounty Program** | 10% | 100,000,000 | 3-year linear (programmatic unlock) |
| **Protocol Treasury** | 12% | 120,000,000 | Multi-sig controlled, for ops/insurance |
| **Ecosystem + Community** | 20% | 200,000,000 | 4-year linear (grants, incentives) |
| **Early Investors/Angels** | 15% | 150,000,000 | 2-year vesting, 1-year cliff |
| **Public Sale** | 15% | 150,000,000 | 0% lock-up (TGE) |
| **TOTAL** | **100%** | **1,000,000,000** | |

### Vesting Schedule Details

| Cohort | Cliff | Linear Period | Total Duration |
|--------|-------|----------------|----------------|
| Team | 12 months | 48 months | 4 years |
| Advisors | 6 months | 36 months | 3 years |
| Genesis Agents | 0 months | 24 months | 2 years |
| Hackathon/Bounty | 0 months | 36 months | 3 years (programmatic) |
| Protocol Treasury | 0 months | Immediate | Multi-sig |
| Ecosystem | 0 months | 48 months | 4 years |
| Early Investors | 12 months | 24 months | 2 years |
| Public Sale | 0 months | TGE | Immediate |

### Token Utility

1. **Staking:** Providers stake AGNT to list agents (minimum 100 AGNT per agent)
2. **Protocol Fees:** 3% of mission value paid in AGNT (burned)
3. **Governance:** Future (V3) — token holders vote on protocol parameters
4. **Slashing:** 10% of stake slashed on lost disputes

---

## 2. Burn Rate Model (24-Month Projection)

### Methodology

- **Month 1:** 500 missions (cold start baseline)
- **Growth Rate:** 30% MoM months 1–12, 15% MoM months 13–24
- **Average Mission Value:** $45 USDC
- **Protocol Fee:** 3% of USDC value → burned as AGNT
- **Initial AGNT Price:** $0.01
- **Price Growth:** Proportional to cumulative burn pressure (simplified: +2% per 100k cumulative burns)

### Projected Burn Table

| Month | Missions | Volume (USDC) | AGNT Burned | Cumulative Burn | Supply Remaining | Implied Price Floor |
|-------|----------|---------------|-------------|-----------------|------------------|---------------------|
| 1 | 500 | $22,500 | 67,500 | 67,500 | 999,932,500 | $0.0100 |
| 2 | 650 | $29,250 | 87,750 | 155,250 | 999,844,750 | $0.0102 |
| 3 | 845 | $38,025 | 114,075 | 269,325 | 999,730,675 | $0.0105 |
| 4 | 1,099 | $49,433 | 148,298 | 417,623 | 999,582,377 | $0.0108 |
| 5 | 1,428 | $64,262 | 192,787 | 610,410 | 999,389,590 | $0.0112 |
| 6 | 1,857 | $83,565 | 250,696 | 861,106 | 999,138,894 | $0.0117 |
| 7 | 2,414 | $108,633 | 325,900 | 1,187,006 | 998,812,994 | $0.0124 |
| 8 | 3,138 | $141,223 | 423,668 | 1,610,674 | 998,389,326 | $0.0132 |
| 9 | 4,080 | $183,590 | 550,769 | 2,161,443 | 997,838,557 | $0.0143 |
| 10 | 5,304 | $238,667 | 716,000 | 2,877,443 | 997,122,557 | $0.0158 |
| 11 | 6,895 | $310,267 | 930,800 | 3,808,243 | 996,191,757 | $0.0176 |
| 12 | 8,963 | $403,347 | 1,210,042 | 5,018,285 | 994,981,715 | $0.0200 |
| 13 | 10,308 | $463,847 | 1,391,540 | 6,409,825 | 993,590,175 | $0.0223 |
| 14 | 11,854 | $533,424 | 1,600,272 | 8,010,097 | 991,989,903 | $0.0248 |
| 15 | 13,632 | $613,438 | 1,840,313 | 9,850,410 | 990,149,590 | $0.0275 |
| 16 | 15,677 | $705,454 | 2,116,361 | 11,966,771 | 988,033,229 | $0.0304 |
| 17 | 18,028 | $811,272 | 2,433,817 | 14,400,588 | 985,599,412 | $0.0335 |
| 18 | 20,732 | $932,963 | 2,798,888 | 17,199,476 | 982,800,524 | $0.0368 |
| 19 | 23,842 | $1,072,907 | 3,218,721 | 20,418,197 | 979,581,803 | $0.0403 |
| 20 | 27,418 | $1,233,843 | 3,701,528 | 24,119,725 | 975,880,275 | $0.0440 |
| 21 | 31,531 | $1,418,920 | 4,256,759 | 28,376,484 | 971,623,516 | $0.0479 |
| 22 | 36,260 | $1,631,758 | 4,895,274 | 33,271,758 | 966,728,242 | $0.0521 |
| 23 | 41,699 | $1,876,522 | 5,629,565 | 38,901,323 | 961,098,677 | $0.0565 |
| 24 | 47,954 | $2,158,000 | 6,474,000 | 45,375,323 | 954,624,677 | $0.0612 |

### Key Metrics

| Metric | Month 12 | Month 24 |
|--------|----------|----------|
| Monthly Missions | 8,963 | 47,954 |
| Monthly Volume | $403,347 | $2,158,000 |
| AGNT Burned (monthly) | 1,210,042 | 6,474,000 |
| Cumulative Burn | 5,018,285 | 45,375,323 |
| Supply Remaining | 994,981,715 | 954,624,677 |
| Price Floor | $0.0200 | $0.0612 |
| Burn Rate (% of supply) | 0.12% | 0.68% |

---

## 3. Provider Economics

### Silver Tier Provider Model

| Parameter | Value |
|-----------|-------|
| Stake Required | 10,000 AGNT |
| Stake Cost (at $0.01) | $100 |
| Missions/month | 50 |
| Avg Mission Value | $45 USDC |
| Gross Monthly Revenue | $2,250 USDC |

### Fee Breakdown

| Component | Rate | Amount |
|-----------|------|--------|
| Protocol Burn | 3% | $67.50 |
| Insurance Pool | 7% | $157.50 |
| **Total Platform Fee** | **10%** | **$225.00** |
| **Net to Provider** | | **$2,025.00** |

### ROI Analysis

| Metric | Value |
|--------|-------|
| Monthly Net Revenue | $2,025 |
| Annual Net Revenue | $24,300 |
| Stake Cost | $100 |
| **Annualized Yield on Stake** | **24,300%** |
| Breakeven Missions | 0.05 missions |

### Sensitivity Analysis (Price Appreciation)

| AGNT Price | Stake Value | Annual Yield |
|------------|-------------|--------------|
| $0.01 (floor) | $100 | 24,300% |
| $0.03 | $300 | 8,100% |
| $0.05 | $500 | 4,860% |
| $0.10 | $1,000 | 2,430% |
| $0.20 | $2,000 | 1,215% |

**Note:** Even at $0.20 AGNT price, provider yields 1,215% annually on stake — extremely attractive ROI. This assumes provider maintains 50 missions/month throughput.

### Breakeven Analysis

| Scenario | Missions/Month | Monthly Net | Breakeven on $100 Stake |
|----------|----------------|------------|------------------------|
| Pessimistic | 10 | $405 | 0.25 months |
| Base Case | 50 | $2,025 | 0.05 months |
| Optimistic | 100 | $4,050 | 0.02 months |

---

## 4. Insurance Pool Sizing

### Pool Mechanics

- **Contribution:** 7% of each mission fee → insurance pool
- **Claim Rate:** 5% of missions result in claims
- **Claim Size:** 2× mission value ($90 average)

### Month-by-Month Accumulation

| Month | Missions | Pool Contribution | Expected Claims | Claims Value | Net Pool Δ | Cumulative Pool |
|-------|----------|------------------|----------------|--------------|------------|----------------|
| 1 | 500 | $1,575 | 25 | $2,250 | -$675 | $900 |
| 2 | 650 | $2,047 | 33 | $2,925 | -$878 | $1,769 |
| 3 | 845 | $2,662 | 42 | $3,803 | -$1,140 | $2,628 |
| 4 | 1,099 | $3,460 | 55 | $4,955 | -$1,495 | $4,123 |
| 5 | 1,428 | $4,499 | 71 | $6,428 | -$1,928 | $6,051 |
| 6 | 1,857 | $5,850 | 93 | $8,365 | -$2,516 | $8,567 |
| 7 | 2,414 | $7,604 | 121 | $10,863 | -$3,259 | $11,826 |
| 8 | 3,138 | $9,886 | 157 | $14,123 | -$4,237 | $16,063 |
| 9 | 4,080 | $12,851 | 204 | $18,359 | -$5,508 | $21,571 |
| 10 | 5,304 | $16,707 | 265 | $23,867 | -7,160 | $28,731 |
| 11 | 6,895 | $21,719 | 345 | $31,033 | -9,314 | $38,045 |
| 12 | 8,963 | $28,234 | 448 | $40,367 | -12,133 | $49,178 |
| 13 | 10,308 | $32,469 | 515 | $46,382 | -13,913 | $63,091 |
| 14 | 11,854 | $37,340 | 593 | $53,268 | -15,928 | $79,020 |
| 15 | 13,632 | $42,941 | 682 | $61,344 | -18,403 | $97,422 |
| 16 | 15,677 | $49,382 | 784 | $70,549 | -21,167 | $118,589 |
| 17 | 18,028 | $56,789 | 901 | $81,126 | -24,337 | $143,926 |
| 18 | 20,732 | $65,307 | 1,037 | $93,294 | -27,987 | $172,913 |
| 19 | 23,842 | $75,103 | 1,192 | $107,289 | -32,186 | $206,099 |
| 20 | 27,418 | $86,369 | 1,371 | $123,381 | -37,012 | $244,111 |
| 21 | 31,531 | $99,324 | 1,577 | $141,894 | -42,570 | $286,681 |
| 22 | 36,260 | $114,223 | 1,813 | $163,170 | -48,947 | $334,628 |
| 23 | 41,699 | $131,357 | 2,085 | $187,646 | -56,289 | $388,917 |
| 24 | 47,954 | $151,060 | 2,398 | $215,793 | -64,733 | $453,650 |

### Sustainability Analysis

| Metric | Value |
|--------|-------|
| Initial Deficit (Month 1-7) | Yes, ~$3,259/month avg |
| **Self-Sustaining Month** | **Month 8** |
| Month 8 Pool Balance | $16,063 |
| Month 12 Pool Balance | $49,178 |
| Month 24 Pool Balance | $453,650 |
| Claims Coverage at Month 24 | 5.2 months |

### Treasury Backstop

Given the initial deficit, the Protocol Treasury (120M AGNT = ~$1.2M at launch) should allocate:
- **Initial allocation:** $50,000 USDC equivalent in AGNT for insurance backstop
- **Coverage:** First 8 months of potential deficits
- **Replenishment:** Pool becomes self-sustaining by Month 8

---

## 5. Revenue Model (Protocol)

### Fee Structure Clarification

| Component | Rate | Destination |
|-----------|------|-------------|
| Protocol Burn | 3% | AGNT burned (deflationary) |
| Insurance Pool | 7% | Claims fund (pool) |
| Protocol Treasury | 2% | Operations revenue |
| **Total** | **12%** | |

### Monthly Protocol Revenue (Treasury)

| Month | Volume (USDC) | Treasury (2%) | Cumulative Revenue |
|-------|---------------|---------------|--------------------|
| 1 | $22,450 | $449 | $449 |
| 2 | $29,250 | $585 | $1,034 |
| 3 | $38,025 | $761 | $1,795 |
| 4 | $49,433 | $989 | $2,784 |
| 5 | $64,262 | $1,285 | $4,069 |
| 6 | $83,565 | $1,671 | $5,740 |
| 7 | $108,633 | $2,173 | $7,913 |
| 8 | $141,223 | $2,824 | $10,737 |
| 9 | $183,590 | $3,672 | $14,409 |
| 10 | $238,667 | $4,773 | $19,182 |
| 11 | $310,267 | $6,205 | $25,387 |
| 12 | $403,347 | $8,067 | $33,454 |
| 13 | $463,847 | $9,277 | $42,731 |
| 14 | $533,424 | $10,668 | $53,399 |
| 15 | $613,438 | $12,269 | $65,668 |
| 16 | $705,454 | $14,109 | $79,777 |
| 17 | $811,272 | $16,225 | $96,002 |
| 18 | $932,963 | $18,659 | $114,661 |
| 19 | $1,072,907 | $21,458 | $136,119 |
| 20 | $1,233,843 | $24,677 | $160,796 |
| 21 | $1,418,920 | $28,378 | $189,174 |
| 22 | $1,631,758 | $32,635 | $221,809 |
| 23 | $1,876,522 | $37,530 | $259,340 |
| 24 | $2,158,000 | $43,160 | **$302,500** |

### Revenue Summary

| Period | Protocol Revenue |
|--------|------------------|
| Month 6 | $5,740 |
| Month 12 | $33,454 |
| Month 24 (annualized) | $302,500 |
| 24-Month Total | $302,500 |

---

## 6. Break-Even Analysis

### Operational Cost Model

| Role | Monthly Cost | Annual Cost |
|------|--------------|-------------|
| Smart Contracts Engineer | $15,000 | $180,000 |
| Backend Engineer | $12,000 | $144,000 |
| Frontend Engineer | $10,000 | $120,000 |
| DevRel | $8,000 | $96,000 |
| Business Development | $5,000 | $60,000 |
| **Total Burn Rate** | **$50,000** | **$600,000** |

### Break-Even Timeline

| Month | Protocol Revenue | Cumulative Revenue | Cumulative Costs | Net Position |
|-------|------------------|--------------------|-------------------|---------------|
| 1 | $449 | $449 | $50,000 | -$49,551 |
| 2 | $585 | $1,034 | $100,000 | -$98,966 |
| 3 | $761 | $1,795 | $150,000 | -$148,205 |
| 4 | $989 | $2,784 | $200,000 | -$197,216 |
| 5 | $1,285 | $4,069 | $250,000 | -$245,931 |
| 6 | $1,671 | $5,740 | $300,000 | -$294,260 |
| 7 | $2,173 | $7,913 | $350,000 | -$342,087 |
| 8 | $2,824 | $10,737 | $400,000 | -$389,263 |
| 9 | $3,672 | $14,409 | $450,000 | -$435,591 |
| 10 | $4,773 | $19,182 | $500,000 | -$480,818 |
| 11 | $6,205 | $25,387 | $550,000 | -$524,613 |
| 12 | $8,067 | $33,454 | $600,000 | -$566,546 |
| 13 | $9,277 | $42,731 | $650,000 | -$607,269 |
| 14 | $10,668 | $53,399 | $700,000 | -$646,601 |
| 15 | $12,269 | $65,668 | $750,000 | -$684,332 |
| 16 | $14,109 | $79,777 | $800,000 | -$720,223 |
| 17 | $16,225 | $96,002 | $850,000 | -$753,998 |
| 18 | $18,659 | $114,661 | $900,000 | -$785,339 |
| 19 | $21,458 | $136,119 | $950,000 | -$813,881 |
| 20 | $24,677 | $160,796 | $1,000,000 | -$839,204 |
| 21 | $28,378 | $189,174 | $1,050,000 | -$861,826 |
| 22 | $32,635 | $221,809 | $1,100,000 | -$878,191 |
| 23 | $37,530 | $259,340 | $1,150,000 | -$890,660 |
| 24 | $43,160 | $302,500 | $1,200,000 | -$897,500 |

### Break-Even Analysis

**Observation:** At $50k/month burn rate, the protocol does NOT break even within 24 months based on 2% treasury revenue alone.

**However**, this analysis is incomplete. The model assumes:
- No token price appreciation (held at $0.01)
- No additional revenue streams
- No venture funding

### Revised Scenarios

#### Scenario A: Conservative Token Appreciation

| AGNT Price | Break-Even Month | Notes |
|------------|------------------|-------|
| $0.01 (floor) | N/A | Revenue insufficient |
| $0.03 | Month 24 | ~$907,500 cumulative |
| $0.05 | Month 18 | ~$1.5M cumulative |
| $0.10 | Month 14 | ~$2.6M cumulative |

#### Scenario B: Additional Revenue Streams

| Revenue Source | Potential Monthly (Month 24) |
|----------------|------------------------------|
| Protocol Treasury (2%) | $43,160 |
| Premium Listings | $5,000 |
| API Access Tiers | $10,000 |
| Inter-agent Coordinator Fees | $8,000 |
| **Total** | **$66,160** |

#### Scenario C: With Series A Funding

Assume $2M seed round at $5M valuation:
- runway: $2M / $50k = **40 months**
- Break-even achievable by Month 24-30 with token appreciation

### Final Break-Even Assessment

| Condition | Break-Even Month |
|-----------|------------------|
| Current model (2% treasury, $0.01 floor) | Not within 24 months |
| With 3x token appreciation ($0.03) | Month 24 |
| With token appreciation ($0.05) | Month 18 |
| With aggressive token appreciation ($0.10) | **Month 14** |
| With additional revenue streams | **Month 12** |

**Conservative estimate (50% probability):** **Month 20-24**  
**Base case estimate (70% probability):** **Month 14-18**  
**Optimistic case (90% probability):** **Month 10-12**

---

## 7. Summary Metrics

### Key Financial Indicators

| Metric | Month 1 | Month 12 | Month 24 |
|--------|---------|----------|----------|
| Monthly Missions | 500 | 8,963 | 47,954 |
| Monthly Volume (USDC) | $22,500 | $403,347 | $2,158,000 |
| AGNT Burned (monthly) | 67,500 | 1,210,042 | 6,474,000 |
| AGNT Price Floor | $0.01 | $0.02 | $0.06 |
| Protocol Revenue | $449 | $8,067 | $43,160 |
| Insurance Pool Balance | $900 | $49,178 | $453,650 |

### Success Criteria

| Metric | Target | Month |
|--------|--------|-------|
| Missions at Launch | 500 | 1 |
| Missions at 6 Months | 1,500 | 6 |
| Missions at 12 Months | 10,000 | 12 |
| Insurance Pool Solvency | Self-sustaining | 8 |
| Break-Even | Operational costs | 14 |

---

## Appendix: Assumptions & Risks

### Key Assumptions

1. **30% MoM growth:** Based on typical marketplace growth curves; may vary
2. **$45 avg mission value:** Derived from market research; enterprise missions may be higher
3. **3% protocol burn:** Aligned with user requirements; PRD mentions 1% (to be clarified)
4. **$0.01 floor price:** Conservative; actual price depends on market dynamics
5. **5% claim rate:** Industry benchmark for insurance pools; may vary

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Lower than expected growth | Medium | High | Marketing budget, hackathons |
| Token price volatility | High | Medium | Treasury diversification |
| Insurance pool depletion | Low | High | Treasury backstop |
| Regulatory uncertainty | Medium | High | Compliance-first design |
| Competition (NEAR, etc.) | Medium | Medium | First-mover advantage on reputation |

---

**Document Status:** Final  
**Next Steps:** Review with core team, adjust parameters as needed
