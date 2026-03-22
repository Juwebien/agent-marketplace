# Agent Marketplace — Architecture (V1)

## 1. Vision

**Agent Marketplace is a decentralized platform that lets developers delegate GitHub issues to specialized AI agents, with a secure USDC payment system and a configurable quality verification pipeline.**

The core differentiator: **the budget buys verification density, not compute**. Clients purchase a traceable quality SLA, not raw execution.

**Why Now:** The emergence of autonomous AI agents (2024–2025) creates a trust asymmetry — clients cannot verify AI-generated code at scale, while AI agents need a credible economic framework (programmable escrow).

---

## 2. The Problem — Jeff's Use Case

**Jeff is a solo developer** maintaining an open-source project on GitHub. He doesn't have time to handle every issue, but he wants to:

1. **Delegate** a technical issue to a reliable AI agent
2. **Pay in USDC** securely (escrow) without banking friction
3. **Receive a verified deliverable** — not just code that "works", but code that has passed quality gates
4. **Have recourse** in case of problems (dispute mechanism) with resolution under 72h

**Why not Upwork/Fiverr?** 20% commission, 5–10 day turnaround. USDC = instant, <1% fees, automated conditional payment.

**Jeff's typical workflow:**
1. Creates a GitHub issue with a budget
2. Chooses a verification tier (Bronze → Platinum)
3. The system generates a workflow (staged plan)
4. AI agents execute stages sequentially
5. Each stage passes a quality gate
6. Jeff receives the deliverable with a full audit trail
7. Funds are progressively released — or refunded on failure

---

## 3. V1 Architecture — Simplified

### 3.1 On-Chain

| Decision | Rationale |
|----------|-----------|
| **WorkflowEscrow composes MissionEscrow** | Preserves the 14 existing tests |
| **Max 6 stages per workflow** | Empirical guard-rail |
| **Budget in BPS** | DeFi standard |
| **Arbitrum One** | ~250ms latency, low cost |

### 3.2 Off-Chain — Simple Coordinator with Hot Standby

**For V1: A single Coordinator service**, not 3 separate services.

```
Coordinator Service
├── State machine (Redis)
├── Matching engine (simple round-robin)
├── AttestationSigner (basic, no TEE)
└── Hot standby (simple active-passive, <30s failover)
```

**SPOF Mitigation for V1:**
- Redis with RDB + AOF persistence
- Hot standby: primary + replica, manual or automatic failover
- WAL (Write-Ahead Log) for recovery
- Configurable timeout per tier

**TEE = V2.** V1 uses basic HSM signing.

**Gnosis Safe = V2.** V1 uses a basic 2/3 admin multisig.

---

## 4. V1 Scope

### 4.1 Smart Contracts
- `MissionEscrow.sol` — Atomic escrow (unchanged, 323 lines, 14 tests)
- `WorkflowEscrow.sol` — Multi-stage orchestration
- `AgentRegistry.sol` — Agent identity and reputation
- `WorkflowRegistry.sol` — Workflow definition storage

### 4.2 Off-Chain
- **WorkflowCompiler** — Compiles tier + issue → WorkflowPlan
- **Coordinator** — Orchestration, timeouts, transitions, basic matching
- **AttestationSigner** — Basic signing (HSM), no TEE
- **GitHub Bot** — Issue → tier suggestion → workflow creation

### 4.3 Out of V1 Scope
| Excluded | Reason |
|----------|--------|
| TEE (SGX/Nitro) | V2 |
| Gnosis Safe | V2 |
| Kleros/UMA arbitration | V2 |
| Arbitrary DAG | V2 |

---

## 5. Economic Model V1

### 5.1 Infrastructure Costs

| Component | Monthly Cost |
|-----------|-------------|
| **AWS (simple)** | $1,500 |
| PostgreSQL (RDS) | $300 |
| Redis | $150 |
| Arbitrum RPC | $100 |
| CI/CD + Monitoring | $200 |
| **TOTAL** | **$2,250/mo** |

*Note: $8k/month = over-engineered architecture. V1 targets $2.25k.*

### 5.2 Fee Structure

| Tier | Volume (est.) | Fee |
|------|--------------|-----|
| Bronze | 60% | 3% |
| Silver | 25% | 4% |
| Gold | 10% | 5% |
| Platinum | 5% | 6% |

**Break-even:** ~50 workflows/month at $2,250 → far more achievable than 470.

### 5.3 Runway

| Cash | Months |
|------|--------|
| $27,000 | 12 months |

---

## 6. Quality Gates

- **Dual attestation:** 60% automated + 40% reviewer
- **Thresholds:** Bronze: 60, Silver: 75, Gold: 85, Platinum: 95
- **Reviewer ≠ Executor** (anti-collusion)
- **Failure policy:** Bronze: fail-fast, Silver: 1 retry, Gold/Platinum: 2 retries

---

## 7. Go-to-Market V1 — Pilot First

### 7.1 Strategy: "Do Things That Don't Scale"

**BEFORE building the $2.25k/month infrastructure:**

1. **Find 5–10 manual pilot clients**
   - Join DevOps/OSS Discord communities
   - Directly contact project maintainers
   - Offer 1–2 free missions in exchange for feedback

2. **Manual validation:**
   - Willingness to pay (ask for budget before starting)
   - Usage frequency (how many issues/month?)
   - Tier distribution (Bronze? Silver? Gold?)
   - Real pain points in their current workflow

3. **If Validated → Build**
   - If 5+ clients want to pay $100+/month → Build the infrastructure
   - If tier distribution = 80% Bronze → Simplify the Bronze workflow

4. **If Not Validated → Pivot**
   - The problem isn't painful enough
   - Recalibrate the product

---

## 8. Threat Model (DeFi)

### 8.1 Risk Scenarios

| Risk | Probability | Impact |
|------|-------------|--------|
| USDC -50% (depeg) | Medium | Critical |
| Arbitrum down 48h | Low | High |
| Smart contract hack | Low | Critical |
| Regulatory (SEC) | Medium | High |

### 8.2 Response Playbooks

**USDC -50% (depeg):**
```
1. Immediately pause all new workflows
2. Email notification to all active clients
3. Migrate to USDC.e or another stablecoin if market stabilizes
4. If permanent depeg → DAO vote to pivot to EURC/DAI
```

**Arbitrum down 48h:**
```
1. Coordinator continues off-chain even if L1 pauses
2. No automatic refund — wait for recovery
3. Proactive communication: status page + email
4. If >72h → consider temporary migration to Optimism
```

**Smart contract hack:**
```
1. Freeze contract via admin key (2/3 multisig)
2. Immediate external audit + published report
3. Victim compensation if protocol cover fails
4. Migration to new contract if necessary
```

**Regulatory (SEC/AMF):**
```
1. Legal entity: offshore structure if necessary
2. No "investment contract" — tooling service
3. Documentation: "not a security, utility token only"
4. Hire general counsel if subpoena received
```

---

## 9. V1 Timeline — 6 Weeks

| Week | Deliverable |
|------|-------------|
| 1–2 | Smart Contracts (WorkflowEscrow + MissionEscrow) + Tests |
| 3–4 | Basic Coordinator + Matching + AttestationSigner (no TEE) |
| 5 | GitHub Bot + minimal dashboard |
| 6 | E2E test + Beta launch (5–10 pilots) |

**Exit criterion:** 5+ active pilot clients with feedback.

---

## 10. Resolved Risks

| Risk | Mitigation |
|------|-----------|
| Coordinator SPOF | Hot standby + WAL |
| Matching monopolization | Round-robin + cold start |
| Reviewer collusion | 60% automated scoring |
| Client scam | GitHub OAuth verification |
| Agent non-payment | On-chain escrow |

---

*V3 (translated from French): Simplified per audit feedback. TEE + Gnosis Safe → V2. Timeline 12→6 weeks. Pilot-first GTM added. Threat model added.*
