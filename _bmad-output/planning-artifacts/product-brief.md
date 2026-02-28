---
stepsCompleted: []
inputDocuments: []
date: 2026-02-27
author: Ju
---

# Product Brief: Agent Marketplace

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Vision Decisions Log

| Question | Decision | Rationale |
|----------|----------|-----------|
| Blockchain | Ethereum L2 (Base/Arbitrum) | Mature ecosystem, bridging, fast launch |
| Security | Zero Trust (TEE + E2E + Smart Contract Escrow) | Full security stack, real moat |
| Skill Validation | Reputation on-chain + Staking/Slash | Track record immutable + financial alignment of providers |
| Business Model | Token protocol fees (burn on each call) | Value captured via token itself, pure DeFi model |
| Primary User | Engineering teams (startup 10-50) + Enterprise (API) | Startups = early adopters, Enterprise = revenue at scale |
| Go-to-Market | Open source protocol + hackathon/bounty program | OSS attracts devs, bounties bootstrap agent supply with token incentives |
| V1 Scope | Full stack MVP (marketplace + token + reputation) | Coherent with vision, everything minimal but present |


---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: []
date: 2026-02-27
author: Ju
---

# Product Brief: Agent Marketplace

## Executive Summary

Agent Marketplace is a decentralized compute marketplace where AI agents are bought and sold as specialized services. Users hire agents by skill match, track record, and availability. Providers monetize their compute infrastructure by listing preconfigured agents. Payment flows through a native utility token on Ethereum L2, with every agent call burning tokens — creating a deflationary flywheel tied directly to usage.

The core insight: today's agent ecosystem is broken because any agent can claim any task. The 30% rework tax is paid silently by every engineering team. Agent Marketplace fixes this with immutable on-chain reputation, provider staking for accountability, and zero-trust security so sensitive missions can be delegated safely.

---

## Core Vision

### Problem Statement

Engineering teams lose ~30% of agent output to rework caused by skill/tool mismatch. An agent is assigned to a Kubernetes infra task with no Kubernetes context. A design agent is given a frontend task without knowing the stack. There is no mechanism to know — before hiring — whether an agent is actually qualified.

### Problem Impact

- **Development teams:** 30% rework waste, frustrated engineers, degraded trust in AI tooling
- **Organizations:** Silent productivity loss, risk of low-quality merges "by exhaustion"
- **The ecosystem:** No accountability for agents, no incentive to specialize deeply

### Why Existing Solutions Fall Short

| Solution | Gap |
|----------|-----|
| LangChain Hub | Template repository, no runtime reputation, no payment, no accountability |
| AgentVerse (Fetch.ai) | Infrastructure-focused, no marketplace UX, no skill matching |
| Relevance AI | Centralized, no on-chain trust, no provider ecosystem |
| Generic AI APIs | No specialization signal, no track record, no escrow |

None address the **trust + accountability + specialization** triangle simultaneously.

### Proposed Solution

A two-sided marketplace where:
- **Providers** list specialized agents with identity cards (skills, tools, stack, env, RAM/CPU requirements) and stake tokens as accountability bond
- **Users** browse, filter by skill match and on-chain reputation, hire with escrow payment (50% upfront / 50% on satisfaction)
- **The protocol** records every mission outcome immutably on-chain — building an unstealable reputation layer
- **The token** is the compute unit — every agent call burns tokens, aligning usage with token value

### Key Differentiators

1. **On-chain immutable reputation** — track record that can't be deleted or faked
2. **Provider staking / slash mechanism** — financial skin in the game for quality
3. **Zero-trust security stack** — TEE (agent secrets) + E2E encryption (mission data) + smart contract escrow (payments)
4. **Inter-agent communication** — agents can hire other agents, with platform discounts creating network effects
5. **Deflationary token model** — usage burns tokens, value grows with adoption

---

## Target Users

### Primary: Engineering Teams (Startup 10-50 people)
- Already run agents in production
- Feel the mismatch pain acutely
- Rational buyers, budget available, no long sales cycle
- Entry point for product-market fit validation

### Secondary: Enterprise (via API)
- Integrate marketplace into CI/CD pipelines
- High volume = major revenue driver
- Zero-trust security stack addresses their compliance requirements
- Longer sales cycle but 10-100x the contract value

### Supply Side: Compute Providers
- Monetize existing GPU/CPU infrastructure
- List preconfigured specialized agents
- Earn tokens proportional to mission success rate
- Staking mechanism aligns their incentives with quality

---

## Technical Architecture Decisions

| Dimension | Decision | Rationale |
|-----------|----------|-----------|
| Blockchain | Ethereum L2 (Base / Arbitrum) | Mature ecosystem, tooling, ETH bridging, fast launch |
| Security | Zero Trust: TEE + E2E + Smart Contract Escrow | Full stack, real moat, enterprise-ready |
| Skill Validation | On-chain reputation + Staking/Slash | Track record immutable + financial alignment |
| Business Model | Token protocol fees (burn per call) | Value captured via token, deflationary flywheel |
| V1 Scope | Full stack MVP | Coherent vision requires all three pillars |

---

## Business Model

**Token burn on every agent call** — the protocol fee is paid in native token and burned. No token, no compute. This creates:

- Direct correlation between platform usage and token scarcity
- No intermediary taking a cut (trustless)
- Provider revenue in token (aligned with ecosystem growth)
- Platform treasury via initial token allocation + staking rewards

**Flywheel:**
```
Usage → Token burn → Scarcity → Token value ↑ → Provider incentive ↑ → Better agents → More usage
```

---

PT|### Phase 1 — Genesis Program (Months 1-3)
#HK|- **Open source the protocol** — attract developers, build community, enable forks that drive back to main marketplace
#PP|- **Genesis agent program (5M AGNT budget)** — 50K AGNT per validated genesis agent, target 100 agents
#KK|- Validation: Complete 10 test missions with score ≥ 8/10 to unlock full allocation
#JJ|
#HZ|Hackathon pool: 15M AGNT for 3-month bounty program
#JJ|
#KB|### Phase 2 — Activate Demand (Months 4-6)
#RM|- Target engineering teams via developer communities (HN, dev Twitter, Discord)
#JH|- Free mission credits: First 200 clients get 500 AGNT credit (100K AGNT total)
#VX|- Case studies from genesis program early users
#RS|
#RH|### Phase 3 — Enterprise (Months 7-12)
#MB|- API-first enterprise offering
#MJ|- Compliance documentation (SOC2 pathway, TEE in V2)
#TP|- Pre-launch outreach target: 5 design partners willing to pilot in alpha phase (paid or unpaid)

### Phase 2 — Activate Demand (Months 4-6)
- Target engineering teams via developer communities (HN, dev Twitter, Discord)
- Free tier with limited token allocation for first missions
- Case studies from bounty program early users

### Phase 3 — Enterprise (Months 7-12)
- API-first enterprise offering
- Compliance documentation (SOC2 pathway leveraging zero-trust architecture)
- Direct sales to 5-10 anchor enterprise clients

---

## Success Metrics

| Metric | 6 months | 12 months |
|--------|----------|-----------|
| Active providers | 20 | 100 |
| Active agents listed | 50 | 500 |
| Monthly missions | 500 | 10,000 |
| Token burn rate | Baseline | 3x baseline |
| Rework reduction (user survey) | 15% | 30% |

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Chicken-and-egg (no providers → no users) | High | Bounty program bootstraps supply before demand activation |
| Token speculation disrupts compute pricing | Medium | Price stability mechanism, token/USD peg for compute costs |
| Enterprise security requirements block adoption | Medium | Zero-trust architecture as first-class feature, SOC2 roadmap |
| Competitor copies reputation system | Low | On-chain data is the moat — 2 years of history can't be copied |
| Regulation (crypto payments) | Medium | Fiat on-ramp option, compliance-first design |

---

## Competitive Positioning

**"The only agent marketplace where reputation is trustless, compute is accountable, and every call makes the network stronger."**

Not a prompt store. Not an infra layer. A **marketplace with financial accountability** — where providers stake their reputation and users have recourse.

## Brainstorm Decisions

### Tokenomics
| Question | Decision |
|----------|----------|
| Prix compute | USDC pour les missions + $AGNT pour staking/governance/frais protocole |
| Burn mechanism | Dynamic burn (EIP-1559 style) — congestion-based fee adjustment |

### Core Reframe (2026-02-27)
**Token/crypto = implementation detail. The real product = smart contracts as automation layer.**
- Escrow conditionnel auto
- Réputation on-chain auto-écrite
- Inter-agent hiring sans intervention humaine
- SLA contractualisé (deadline dépassée = refund automatique)
Le token est juste l'unité de compte. L'intérêt est l'automatisation trustless.
| Agent Card — Proof of competence | Portfolio missions (last 10, anonymized, with client score) |
| Agent Card — Differentiation | Endorsements by other agents (peer certification) |
| Agent Card — Hiring decision | Auto match score (mission description → agent ranking 0-100) |
| Agent Card — UX | Real-time availability + avg response time |
| Agent Card — Transparency | Price estimation before commit (paste prompt → get cost estimate) |
| Agent Card — Discovery | Social recommendations ("teams using ArgoCD+k3s also used...") |
| Agent Card — Differentiation | Ultra-granular tags (k3s homelab + ArgoCD GitOps vs EKS enterprise + Terraform) |
| Agent Card — Transparency | Stack visible (LLM model, context window, MCP tools connected) |
| Agent Card — Interaction style | Mode visible (fully autonomous vs collaborative/step-by-step) |
| Agent Card — Accountability | SLA contractualized (deadline → auto-refund via smart contract) |
| Inter-agent — Recruitment | Pre-established partner network (agents declare preferred collaborators, negotiated rates) |
| Inter-agent — Sub-mission | Auction system (agent posts sub-mission, specialists bid, cheapest wins) |
| Inter-agent — Payment | Platform discount on agent-to-agent transactions (-20% protocol fees) |
| Inter-agent — Organization | Shared treasury (agent partners pool revenue in multi-sig → "agent agencies") |
| Inter-agent — Coordinator | Orchestrator agent type (sole skill = decompose complex missions + recruit specialists) |
| Inter-agent — Community | Agent guilds (mutual certification + shared reputation + revenue sharing) |
| Inter-agent — Market | Secondary mission market (agent resells out-of-scope mission + takes commission) |
| Cold Start — Supply | Genesis agents (10-20 hand-picked, internally tested, "Genesis" badge + seeded reputation) |
| Cold Start — Demand | Free missions (first 100 users get credits, first agents do free missions to build reputation) |
| Cold Start — Trust signal | Inverted staking (high stake = top placement, money signals confidence before track record exists) |
| Cold Start — GTM | VS Code / CLI plugin (marketplace embedded in dev workflow, no new site to visit) |
| Cold Start — Community | Hackathon founding users (50 eng teams, real missions, token rewards for feedback) |
| Cold Start — Revenue | B2B direct sales pre-launch (5 anchor startups committed to X missions/month from day 1) |
| Cold Start — Token | No exchange listing at launch (token only usable on marketplace, liquidity from usage not speculation) |
| Killer Feature | Dry run (10% of mission at fixed mini-price, see quality before committing) |
| Killer Feature | Mission DNA (semantic fingerprint → match agent with historically similar successful missions) |
| Killer Feature | Permanent agent team (persistent shared memory of your project, natural lock-in) |
| Killer Feature | Recurring missions (cron-style scheduled agent calls, marketplace becomes part of CI/CD) |
| Killer Feature | Proof of Work outputs (every agent output signed + hashed on-chain, cryptographically verifiable) |
| Killer Feature | Agent DAOs (top-performing agents become autonomous entities with treasury + governance rights) |
| Killer Feature | Cross-chain reputation portability (open standard, agent reputation exportable to any protocol) |
| Killer Feature | Insurance pool (collective provider staking pool covers client if agent fails + insufficient individual stake) |
