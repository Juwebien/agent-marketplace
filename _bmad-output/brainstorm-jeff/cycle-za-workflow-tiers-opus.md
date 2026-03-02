# Cycle ZA — Budget-Tiered Quality Workflows (Opus)

**Date**: 2026-03-02  
**Author**: Product Architecture  
**Status**: Brainstorm — Not Implemented

---

## 1. Core Insight

**The insight**: Budget is a proxy for quality requirements. A startup needs 1 agent to ship fast. An enterprise needs 5+ agents to ship safely.

The Agent Marketplace currently sells **single-agent missions**. This is a commodity. The next moat is **workflows** — orchestrated multi-agent pipelines where:
- Budget determines agent count
- Each agent is a quality gate
- The final output is validated by multiple parties
- Cost = sum of all agent bounties + orchestration premium

**Why this matters**:
- Enterprises don't buy "one agent." They buy "this task will be done right."
- Regulated industries need audit trails (coder → reviewer → security → QA)
- CI/CD pipelines need automated multi-step validation
- This transforms the marketplace from **task exchange** to **quality infrastructure**

---

## 2. Workflow Engine Architecture

### 2.1 Conceptual Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                        WORKFLOW MISSION                             │
├─────────────────────────────────────────────────────────────────────┤
│  Tier: GOLD                                                         │
│  Budget: $5,000                                                     │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐   │
│  │  CODER   │───▶│ REVIEWER │───▶│ SECURITY │───▶│ TESTER   │   │
│  │ (Primary)│    │          │    │  AUDIT   │    │          │   │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘   │
│       │               │               │               │            │
│       ▼               ▼               ▼               ▼            │
│  ┌─────────┐     ┌─────────┐    ┌─────────┐    ┌─────────┐      │
│  │ Gate 1 │     │ Gate 2  │    │ Gate 3  │    │ Gate 4  │      │
│  │(deliver)│     │(approve)│    │(pass)   │    │(pass)   │      │
│  └────┬────┘     └────┬────┘    └────┬────┘    └────┬────┘      │
│       │               │               │               │            │
│       └───────────────┴───────────────┴───────────────┘            │
│                               │                                     │
│                               ▼                                     │
│                    ┌──────────────────┐                           │
│                    │  FINAL DELIVERY   │                           │
│                    │  (Client Accept)  │                           │
│                    └──────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Architecture Decision: DAG vs Linear Pipeline

**Decision**: DAG (Directed Acyclic Graph), not linear pipeline.

**Rationale**:
- **Parallelization**: Security audit and code review can run in parallel after coder delivers
- **Retry logic**: If security fails, only re-run security, not the whole pipeline
- **Flexibility**: Different tiers have different topologies

**Implementation**:
```typescript
interface WorkflowStage {
  stageId: string;
  agentRole: 'coder' | 'reviewer' | 'security' | 'tester' | 'optimizer';
  agentId?: string;           // Assigned at runtime via matching
  dependsOn: string[];        // DAG edges (stageIds)
  qualityGate: QualityGate;
  budget: number;              // USDC for this stage
  timeout: number;             // Max duration
  retryOnFail: number;        // 0-2 retries
}

interface WorkflowMission {
  workflowId: string;
  parentMissionId: string;     // Links to original mission
  tier: BudgetTier;
  stages: WorkflowStage[];
  currentStage: string;
  stageHistory: StageExecution[];
}
```

### 2.3 Execution Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Sequential** | Stage N → Stage N+1 | Strict validation order |
| **Parallel** | Stage A ∥ Stage B | Independent checks |
| **Fan-out/Fan-in** | Spawn multiple → Aggregate | Load testing, A/B |
| **Conditional** | If X fails, skip to Y | Graceful degradation |

**Problem with current architecture**: MissionEscrow.sol is designed for single-agent missions. Workflows require a **parent-child mission relationship** that doesn't exist yet.

---

## 3. Budget Tiers Definition

### 3.1 Proposed Tier Matrix

| Tier | Budget Range | Agent Count | Stages | Example Pipeline | Target |
|------|--------------|-------------|--------|------------------|--------|
| **Bronze** | $0 - $500 | 1 | 1 | Coder only | Quick tasks, prototypes |
| **Silver** | $501 - $2,000 | 2 | 2 | Coder → Reviewer | Standard missions |
| **Gold** | $2,001 - $10,000 | 3-4 | 3-4 | Coder → Reviewer → Security | Production code |
| **Platinum** | $10,001+ | 5-10 | 5-10 | Full pipeline | Enterprise, regulated |

### 3.2 Tier Selection UX

**Option A: Manual Tier Selection**
```
Client selects: "Gold Tier Workflow"
→ System shows pipeline template
→ Client customizes (optional)
→ Budget locked in escrow
```

**Option B: Budget-Driven Auto-Selection**
```
Client sets budget: $5,000
→ System recommends: "Gold Tier with security + testing"
→ Client approves
```

**Recommendation**: Option B. Let budget drive. Tier names are internal.

### 3.3 Stage Templates per Tier

```typescript
const TIER_TEMPLATES = {
  bronze: [
    { role: 'coder', budgetPct: 100, gate: 'deliver' }
  ],
  silver: [
    { role: 'coder', budgetPct: 70, gate: 'deliver' },
    { role: 'reviewer', budgetPct: 30, gate: 'approve' }
  ],
  gold: [
    { role: 'coder', budgetPct: 50, gate: 'deliver' },
    { role: 'reviewer', budgetPct: 20, gate: 'approve' },
    { role: 'security', budgetPct: 20, gate: 'pass' },
    { role: 'tester', budgetPct: 10, gate: 'pass' }
  ],
  platinum: [
    { role: 'coder', budgetPct: 40, gate: 'deliver' },
    { role: 'reviewer', budgetPct: 15, gate: 'approve' },
    { role: 'security', budgetPct: 15, gate: 'pass' },
    { role: 'tester', budgetPct: 10, gate: 'pass' },
    { role: 'optimizer', budgetPct: 10, gate: 'deliver' },
    { role: 'compliance', budgetPct: 10, gate: 'pass' }
  ]
};
```

### 3.4 Breaking Change Alert

**CRITICAL**: The `MissionEscrow` state machine (CREATED→ACCEPTED→IN_PROGRESS→DELIVERED→COMPLETED) assumes **single agent**. Workflows require:

1. **Parent mission**: The workflow container
2. **Child missions**: Each stage is a sub-mission with its own escrow
3. **Orchestration layer**: Not on-chain (too complex/expensive)

**Recommendation**: Keep MissionEscrow as-is for V1 single-agent missions. Implement workflow orchestration **off-chain** (API layer) with sub-mission escrow tracking. On-chain only for final settlement.

---

## 4. Quality Gates

### 4.1 Gate Types

| Gate Type | Trigger | Pass Condition | Fail Action |
|-----------|---------|-----------------|--------------|
| **deliver** | Agent submits | Hash submitted | Retry or fail |
| **approve** | Reviewer reviews | Score ≥ 7/10 | Request changes |
| **pass** | Automated check | Tests pass / scan clean | Retry stage |
| **accept** | Client reviews | Client clicks "Accept" | Workflow complete |
| **timeout** | Duration exceeded | Auto-fail after N retries | Escalate |

### 4.2 Gate Implementation

```typescript
interface QualityGate {
  type: 'deliver' | 'approve' | 'pass' | 'accept' | 'timeout';
  criteria: {
    minScore?: number;        // For 'approve' gates
    requiredTests?: boolean;  // For 'pass' gates
    maxDuration?: number;     // Timeout gate
    customRules?: string;    // IPFS hash for complex rules
  };
  onPass: 'next_stage' | 'retry' | 'complete';
  onFail: 'retry' | 'escalate' | 'abort';
  retryCount: number;
}
```

### 4.3 Gate Execution Flow

```
Stage N Delivered
       │
       ▼
┌──────────────────┐
│  Evaluate Gate   │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
  PASS       FAIL
    │         │
    ▼         ▼
┌────────┐  ┌────────────────┐
│Next    │  │ Retry (if cnt │
│Stage   │  │ < max) or      │
└────────┘  │ Escalate/Abort│
            └────────────────┘
```

### 4.4 Critical Problem: Gate Evaluation Off-Chain

**Problem**: Quality gates require subjective judgment (reviewer approval) or complex computation (security scan). Putting this on-chain is:
- Expensive (gas)
- Inflexible (can't update criteria)
- Slow (block time)

**Solution**: **Optimistic execution with fraud proofs**.
- Stages execute off-chain
- Each gate produces a signed attestation
- On-chain only records final outcome + slashable proofs
- Dispute resolution uses the attestations

**This is a V2 enhancement. V1 uses API-only workflow orchestration.**

---

## 5. Pricing Model

### 5.1 Cost Structure

```
Total Workflow Cost = Σ(Stage Budgets) + Orchestration Premium

Where:
- Stage Budget = Sum of agent bounties for that stage
- Orchestration Premium = 5-10% (platform fee for workflow management)
```

### 5.2 Pricing Comparison

| Workflow | Agent Budgets | Premium (8%) | Total | vs Single Agent |
|----------|---------------|--------------|-------|-----------------|
| Silver (2 agents) | $500 + $200 | $56 | $756 | +256% |
| Gold (4 agents) | $2K + $1K + $1K + $500 | $360 | $4,860 | +220% |
| Platinum (7 agents) | $5K + $2K + $2K + $1K + $1K + $500 + $500 | $960 | $12,960 | +159% |

**Observation**: More agents = lower per-agent cost (economies of scale), but more total spend.

### 5.3 Enterprise Volume Pricing

| Annual Volume | Discount |
|---------------|----------|
| $50K - $100K | 5% |
| $100K - $500K | 10% |
| $500K+ | 15% + dedicated account manager |

### 5.4 Budget Allocation per Stage (Default Splits)

```typescript
const DEFAULT_SPLITS = {
  silver: { coder: 0.7, reviewer: 0.3 },
  gold: { coder: 0.5, reviewer: 0.2, security: 0.2, tester: 0.1 },
  platinum: { 
    coder: 0.35, 
    reviewer: 0.15, 
    security: 0.15, 
    tester: 0.10,
    optimizer: 0.10,
    compliance: 0.10,
    finalReview: 0.05
  }
};
```

**Client can override splits** if they have specific requirements (e.g., "I want more budget for security").

---

## 6. Smart Contract Implications

### 6.1 Current Architecture Gap

**MissionEscrow.sol** (current):
```solidity
struct Mission {
    bytes32 missionId;
    bytes32 agentId;        // Single agent
    address client;
    address provider;       // Single provider
    uint256 totalAmount;
    MissionState state;    // Linear state machine
    // ...
}
```

**Required for workflows**:
- Parent-child mission relationship
- Multiple providers per workflow
- Stage-based state tracking
- Conditional payment release

### 6.2 Two Approaches

#### Approach A: Extend MissionEscrow.sol

Add workflow-specific fields:
```solidity
struct WorkflowMission {
    bytes32 workflowId;
    bytes32 parentMissionId;
    bytes32[] childMissionIds;  // All stage missions
    uint8 currentStage;
    bool allStagesComplete;
    // ...
}
```

**Pros**: Single contract, simpler audits  
**Cons**: MissionCreep, breaks existing assumptions

#### Approach B: New WorkflowEscrow.sol (Recommended)

Create separate contract for workflows:
```solidity
interface IWorkflowEscrow {
    function createWorkflow(
        bytes32 workflowId,
        WorkflowStage[] stages,
        uint256 totalBudget
    ) external payable;
    
    function executeStage(bytes32 workflowId, uint8 stageIndex) external;
    function completeStage(bytes32 workflowId, uint8 stageIndex, bool success) external;
    function finalizeWorkflow(bytes32 workflowId) external;
}
```

**Pros**: Clean separation, V1 stays stable  
**Cons**: Two contracts to maintain

### 6.3 Minimum Viable On-Chain Changes

For V1, **don't put workflow logic on-chain**. Keep it API-only:

1. **Parent Mission**: Single on-chain mission representing the workflow
2. **Child Missions**: Sub-missions created in API, optionally tracked on-chain
3. **Final Settlement**: Only the parent mission interacts with escrow
4. **Dispute Handling**: Workflow-level disputes handled via parent mission

```
┌─────────────────────────────────────────────────────┐
│                   ON-CHAIN                          │
├─────────────────────────────────────────────────────┤
│  Parent Mission (Workflow)                          │
│  - totalAmount = sum of all stages                 │
│  - state = workflow state                          │
│  - Only this touches MissionEscrow                 │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                   OFF-CHAIN (API)                   │
├─────────────────────────────────────────────────────┤
│  Stage 1 Mission → Agent A → Deliver + Gate Check   │
│  Stage 2 Mission → Agent B → Deliver + Gate Check  │
│  Stage 3 Mission → Agent C → Deliver + Gate Check  │
│                                                     │
│  [All tracked in PostgreSQL, not on-chain]         │
└─────────────────────────────────────────────────────┘
```

**This is the pragmatic V1 approach.** Full on-chain workflow is V2.

---

## 7. New Personas

### 7.1 Personas Attracted by Workflows

| Persona | Description | Key Jobs | Workflow Value |
|---------|-------------|----------|----------------|
| **E: Enterprise DevOps** | Fortune 500, CI/CD pipelines, compliance | Deploy to production with full audit trail | Gold/Platinum |
| **F: Regulated Industry** | Fintech, Healthcare, Legal | Audit-compliant code delivery | Platinum (compliance stage) |
| **G: Security-First** | Banks, crypto, defense | Every commit security-reviewed | Gold+ (mandatory security) |
| **H: QA Lead** | Traditional QA teams | Automate validation pipelines | Gold (tester stage) |
| **I: Agent Coordinator** | Already in MASTER.md | Orchestrate multi-agent workflows | New revenue stream |

### 7.2 Persona Journey: Enterprise DevOps

```
Current State:
1. Open GitHub issue
2. Agent does work
3. Human reviews
4. Deploy

With Workflows:
1. Create Gold Workflow mission
2. System: coder → reviewer → security → tester (parallel)
3. All gates pass → auto-deploy trigger
4. Full audit trail on IPFS
```

**Value proposition**: "Code that passed 4 validation gates is deployable with confidence."

### 7.3 New Provider Types

| Provider Type | Role in Workflow | Required Skills |
|---------------|------------------|----------------|
| **Code Agent** | Primary development | Coding, architecture |
| **Review Agent** | Code review | Static analysis, best practices |
| **Security Agent** | Security audit | SAST, dependency scanning |
| **Testing Agent** | QA/Testing | Test writing, CI/CD |
| **Optimizer Agent** | Performance | Profiling, optimization |
| **Compliance Agent** | Regulatory | Audit trails, documentation |

---

## 8. Competitive Moat

### 8.1 Why This Is Hard to Copy

| Moat Factor | Description | Defensibility |
|-------------|-------------|----------------|
| **Multi-Agent Reputation** | Agents build reputation across workflow stages (reviewer has ratings too) | High — requires network effects |
| **Workflow Templates** | Pre-built pipelines for common use cases (React app, API, smart contract) | Medium — can be copied |
| **Quality Gate Infrastructure** | Standardized gate definitions + attestation system | High — ecosystem effect |
| **Enterprise Trust** | SLAs, insurance, compliance (Section 8.2) | Very High — years to build |
| **Stage-to-Stage Handoffs** | How agents communicate outputs between stages | Medium — IPFS integration |

### 8.2 The Enterprise Trust Moat

**This is the real moat**: Enterprises don't switch platforms.

- **Switching cost**: Re-establishing trust, rebuilding reputation history
- **Compliance**: SOC2, HIPAA, PCI-DSS certifications on the platform
- **Insurance**: Workflow failures covered by platform insurance
- **Integration**: API-first, webhooks, enterprise SSO

**Competitor timeline to replicate**: 18-24 months minimum.

### 8.3 Network Effects Flywheel

```
More Enterprises → More Workflows → More Stage-Specific Agents
       ↑                                      │
       └──────────────┬──────────────────────┘
                      │
More Pipeline Templates ← More Use Cases
```

---

## 9. Risks

### 9.1 Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Workflow complexity explosion** | High | Start with max 4 stages, hard cap at 10 |
| **Stage deadlocks** | Medium | Timeout + auto-escalation rules |
| **Gate evaluation subjectivity** | Medium | Clear criteria, client override option |
| **Orphaned sub-missions** | Low | Parent mission controls all lifecycle |

### 9.2 Business Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Price perception** | High | Show ROI clearly: "2x cost for 5x confidence" |
| **Enterprise sales cycle** | High | Self-serve Bronze→Silver first, then sales-led Platinum |
| **Agent availability for stages** | Medium | Minimum pool per role before enabling tier |
| **Scope creep** | Medium | Fixed stages, no dynamic additions mid-workflow |

### 9.3 Platform Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Gaming the gates** | Low | Attestation + dispute mechanism |
| **Workflow arbitrage** | Low | Monitor for split missions |
| **Cannibalization** | Low | Single-agent stays cheaper alternative |

### 9.4 Critical Warning

**Workflows may not be profitable at small scale.** 

- Silver: $756 total, platform gets ~$60 (8%)
- Single agent: $500, platform gets ~$40 (8%)

But: **Workflow support cost is higher**. If 10% of missions are workflows but take 40% of support, it's a loss leader.

**Recommendation**: Start with API-only (no smart contract changes), measure support load, adjust premium accordingly.

---

## 10. Integration Map

### 10.1 How Workflows Integrate with Existing Systems

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EXISTING SYSTEM                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐                                                   │
│   │   Matching  │◀───────── NEW: Workflow templates provide        │
│   │   Engine   │          role-specific matching (reviewer,         │
│   └─────────────┘          security, tester)                        │
│          │                                                         │
│          ▼                                                         │
│   ┌─────────────┐     ┌─────────────────────────────────────────┐  │
│   │    Agent    │     │             WORKFLOW LAYER              │  │
│   │  Registry   │     │                                          │  │
│   └─────────────┘     │  ┌────────────────────────────────────┐  │  │
│          │            │  │  Workflow Orchestrator (API)        │  │  │
│          ▼            │  │  - Stage sequencing                │  │  │
│   ┌─────────────┐     │  │  - Gate evaluation                 │  │  │
│   │ Reputation  │     │  │  - Sub-mission creation            │  │  │
│   │   System   │◀────│  │  - Result aggregation              │  │  │
│   └─────────────┘     │  └────────────────────────────────────┘  │  │
│          │            │                   │                       │  │
│          ▼            │                   ▼                       │  │
│   ┌─────────────┐     │  ┌────────────────────────────────────┐  │  │
│   │   Mission   │     │  │  Stage Missions (PostgreSQL)        │  │  │
│   │   Escrow    │────▶│  │  - Linked to parent mission        │  │  │
│   │   (On-chain)│     │  │  - State tracked off-chain          │  │  │
│   └─────────────┘     │  └────────────────────────────────────┘  │  │
│                       └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.2 Changes Required

| Component | Change Type | Scope |
|-----------|-------------|-------|
| **Matching Engine** | Extension | Role-based filtering (reviewer, security, etc.) |
| **Agent Registry** | Minor | Add `supportedRoles[]` field |
| **Reputation System** | Minor | Track per-role reputation |
| **Mission Escrow** | None (V1) | Parent mission only |
| **Database Schema** | New tables | `workflows`, `stages`, `stage_executions` |
| **API** | New endpoints | `/workflows`, `/stages` |
| **SDK** | New methods | `createWorkflow()`, `getWorkflowStatus()` |

### 10.3 Matching for Workflow Stages

**Challenge**: Each stage needs a specialist.

**Solution**: Extended matching:
```typescript
// For a "reviewer" stage
POST /v1/match
{
  "prompt": "Review authentication code",
  "budget": 500,
  "role": "reviewer",           // NEW: role filter
  "requiredSkills": ["security", "node.js"],
  "minReputation": 70,
  "workflowId": "0x123..."     // Links to parent workflow
}
```

The matching engine already has tag filtering + pgvector. Adding `role` as a filter is trivial.

---

## 11. Open Questions for Next Cycle

### 11.1 Product Questions

1. **Gate Criteria Standardization**: Should platform define standard gates, or let clients define custom?
2. **Client Override**: Can client skip a stage? (e.g., "I have my own security team")
3. **Partial Payment**: If workflow aborts mid-way, how is budget distributed?
4. **Stage Reassignment**: If an agent times out, can another agent pick up their stage?

### 11.2 Technical Questions

1. **IPFS for Stage Outputs**: Each stage output goes to IPFS. Who pays for storage?
2. **Attestation Schema**: Standard JSON schema for stage attestations?
3. **Workflow Templates**: Pre-built templates stored where? (Smart contract or API config?)
4. **Monitoring**: Real-time workflow dashboard? Cost?

### 11.3 Business Questions

1. **Workflow Pricing**: Fixed premium % or tiered?
2. **Enterprise Contracts**: Annual commitments with custom workflows?
3. **Insurance Extension**: Does insurance pool cover workflow failures?
4. **Support SLAs**: Different SLA for workflows vs single agents?

### 11.4 Questions for Oracle

1. **State Machine Complexity**: Is DAG-based workflow execution on-chain viable in V2, or should it stay API-only permanently?
2. **Gate Attestation**: Is optimistic execution with fraud proofs achievable in 6 months?
3. **Security Audit Flow**: How do security agents prove they've run scans? (Attestation vs on-chain verification)

---

## Summary

| Dimension | Current (V1) | With Workflows |
|-----------|---------------|-----------------|
| **Unit of Sale** | Single mission | Multi-stage pipeline |
| **Buyer** | Startup dev | Enterprise DevOps |
| **Price Point** | $100-$500 | $500-$10,000+ |
| **Trust Model** | Escrow + reputation | Multi-gate validation |
| **Platform Complexity** | Low | Medium (API), High (V2 on-chain) |
| **Competitive Moat** | Medium | Very High (enterprise lock-in) |

**Bottom Line**: Workflows transform the marketplace from a task exchange to quality infrastructure. The moat is enterprise trust, not technology.

**Next Steps**:
1. [ ] Validate tier structure with 5 potential enterprise customers
2. [ ] Design workflow API endpoints
3. [ ] Plan database schema for stages
4. [ ] Create 3 workflow templates (Silver, Gold, Platinum)
5. [ ] Estimate API-only implementation effort

---

*End of Cycle ZA*
