---
title: '{title}'
slug: '{slug}'
created: '{date}'
status: 'in-progress'
stepsCompleted: []
tech_stack: []
files_to_modify: []
code_patterns: []
test_patterns: []
---

# Tech-Spec: {title}

**Created:** {date}

## Overview

### Problem Statement

{problem_statement}

### Solution

{solution}

### Scope

**In Scope:**
{in_scope}

**Out of Scope:**
{out_of_scope}

## Context for Development

### Codebase Patterns

{codebase_patterns}

### Files to Reference

| File | Purpose |
| ---- | ------- |

{files_table}

### Technical Decisions

{technical_decisions}

## Implementation Plan

### Tasks

{tasks}

### Acceptance Criteria

{acceptance_criteria}

## Additional Context

### Dependencies

{dependencies}

### Testing Strategy

{testing_strategy}

### Notes

{notes}


---
title: 'Agent Marketplace — Full Stack MVP'
slug: 'agent-marketplace-mvp'
created: '2026-02-27'
status: 'in-progress'
stepsCompleted: [1, 2, 3]
tech_stack:
  - Ethereum L2 (Base)
  - Solidity (smart contracts)
  - Node.js / TypeScript (API)
  - React (marketplace UI)
  - PostgreSQL (off-chain metadata)
  - IPFS (agent identity cards)
  - Intel SGX / AWS Nitro (TEE)
  - WebSockets (inter-agent comms)
files_to_modify: []
code_patterns:
  - ERC-20 token with burn mechanism
  - Escrow smart contract pattern
  - On-chain reputation registry
  - TEE attestation flow
test_patterns:
  - Hardhat for smart contract tests
  - Jest for API
  - Playwright for E2E
---

# Tech Spec: Agent Marketplace — Full Stack MVP

## Problem Statement

No marketplace exists where AI agents are listed with verifiable skill credentials, on-chain reputation, and accountable payment. Teams waste ~30% of agent output on rework from skill mismatch. No financial accountability, no trust signal, no recourse.

## Solution

A two-sided marketplace where:
- Providers list agents with identity cards + stake tokens as quality bond
- Users hire agents via escrow (50/50) with on-chain reputation as trust signal
- Every call burns $AGNT token — usage = deflationary pressure
- Zero-trust security: TEE for agent secrets, E2E for mission data, smart contracts for payment

## Scope

### In Scope (V1 MVP)
- $AGNT token deployment on Base (Ethereum L2)
- Escrow smart contract (50% upfront / 50% on delivery)
- Agent registry smart contract (identity cards + reputation)
- Provider staking contract (slash on bad missions)
- Marketplace UI (list, search, hire agents)
- Provider SDK (list agent, accept mission, report completion)
- On-chain reputation write (mission outcomes)
- Basic inter-agent hiring (agent calls another agent)

### Out of Scope (V2)
- TEE implementation (post-MVP security upgrade)
- Mobile app
- Fiat on-ramp
- DAO governance
- Cross-chain bridge

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Marketplace UI (React)                 │
│         Browse │ Hire │ Dashboard │ Provider Portal       │
└──────────────────────────┬──────────────────────────────┘
                           │ REST / WS
┌──────────────────────────▼──────────────────────────────┐
│                    API Gateway (Node.js/TS)               │
│    Auth │ Agent Registry │ Mission Manager │ Events       │
└──────┬──────────┬────────────────────┬───────────────────┘
       │          │                    │
┌──────▼──┐  ┌────▼──────┐  ┌─────────▼────────┐
│PostgreSQL│  │   IPFS    │  │  Base L2 (EVM)   │
│(metadata)│  │(agent     │  │  Smart Contracts │
│missions  │  │ identity) │  │  $AGNT │ Escrow  │
│users     │  └───────────┘  │  Registry│Staking│
└──────────┘                 └──────────────────┘
```

### Smart Contracts

#### 1. `AGNTToken.sol` — ERC-20 with burn
```solidity
// $AGNT token
// - Mintable by owner (initial supply + bounty rewards)
// - Burnable on every agent call (protocol fee)
// - Transferable for marketplace payments
// - Stakeable by providers
interface IAGNTToken {
    function burnOnCall(address from, uint256 amount) external; // protocol fee
    function stake(uint256 amount) external;                     // provider stake
    function slash(address provider, uint256 amount) external;   // bad mission
}
```

#### 2. `AgentRegistry.sol` — Identity cards + reputation
```solidity
struct AgentCard {
    bytes32 agentId;
    address provider;
    string  ipfsMetadataHash;  // skills, tools, env, RAM/CPU
    uint256 missionsCompleted;
    uint256 missionsFailed;
    uint256 reputationScore;   // weighted average
    bool    active;
}

interface IAgentRegistry {
    function registerAgent(bytes32 agentId, string calldata ipfsHash) external;
    function recordMissionOutcome(bytes32 agentId, bool success, uint8 score) external;
    function getReputation(bytes32 agentId) external view returns (uint256);
}
```

#### 3. `MissionEscrow.sol` — 50/50 payment flow
```solidity
// States: CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED | DISPUTED
struct Mission {
    bytes32   missionId;
    bytes32   agentId;
    address   client;
    address   provider;
    uint256   totalAmount;   // in $AGNT
    uint256   upfrontPaid;   // 50%
    uint256   remainder;     // 50% held
    MissionState state;
    uint256   deadline;
}

interface IMissionEscrow {
    function createMission(bytes32 agentId, uint256 amount, uint256 deadlineTs) external;
    function acceptMission(bytes32 missionId) external;    // provider
    function deliverMission(bytes32 missionId) external;   // provider
    function approveMission(bytes32 missionId) external;   // client → releases 50%
    function disputeMission(bytes32 missionId) external;   // client → arbitration
    function timeoutMission(bytes32 missionId) external;   // after deadline → refund
}
```

#### 4. `ProviderStaking.sol` — Skin in the game
```solidity
interface IProviderStaking {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;   // timelock: 7 days
    function getStake(address provider) external view returns (uint256);
    // slash called by MissionEscrow on disputed+lost missions
    function slash(address provider, uint256 percentage) external;
}
```

---

### Agent Identity Card (IPFS JSON Schema)

```json
{
  "agentId": "0x...",
  "name": "KubeExpert-v2",
  "version": "2.1.0",
  "provider": "0x...",
  "description": "Specialized Kubernetes infra agent — cluster setup, Helm, ArgoCD",
  "skills": [
    { "name": "kubernetes", "level": "expert", "frameworks": ["k3s", "eks", "gke"] },
    { "name": "helm", "level": "expert" },
    { "name": "argocd", "level": "advanced" },
    { "name": "terraform", "level": "intermediate" }
  ],
  "tools": ["kubectl", "helm", "argocd-cli", "terraform", "aws-cli"],
  "environment": {
    "runtime": "node:22",
    "ram": "4GB",
    "cpu": "2 cores"
  },
  "pricing": {
    "perCall": 10,         // $AGNT burned per API call
    "perMission": 100,     // base mission price in $AGNT
    "currency": "AGNT"
  },
  "availability": "24/7",
  "languages": ["en", "fr"],
  "tags": ["devops", "kubernetes", "infra", "gitops"]
}
```

---

### API Endpoints

#### Agent Registry
```
GET  /api/agents                    # list with filters (skills, price, reputation)
GET  /api/agents/:agentId           # agent card + reputation
POST /api/agents                    # register agent (provider auth)
GET  /api/agents/:agentId/reputation # on-chain reputation history
```

#### Missions
```
POST /api/missions                  # create mission (client)
GET  /api/missions/:missionId       # mission status
POST /api/missions/:missionId/accept   # provider accepts
POST /api/missions/:missionId/deliver  # provider delivers
POST /api/missions/:missionId/approve  # client approves → escrow release
POST /api/missions/:missionId/dispute  # client disputes
```

#### Token / Staking
```
GET  /api/token/balance/:address
POST /api/provider/stake
POST /api/provider/unstake
GET  /api/provider/:address/stake
```

#### Inter-Agent
```
POST /api/agents/:agentId/hire      # agent hires another agent (discount applied)
GET  /api/agents/:agentId/network   # agents this agent has worked with
```

---

### Provider SDK (TypeScript)

```typescript
import { AgentMarketplace } from '@agent-marketplace/sdk';

const sdk = new AgentMarketplace({
  apiKey: 'ak_...',
  providerAddress: '0x...',
  privateKey: process.env.PROVIDER_KEY,
  network: 'base-mainnet'
});

// Register agent
await sdk.registerAgent({
  name: 'KubeExpert-v2',
  skills: ['kubernetes', 'helm', 'argocd'],
  tools: ['kubectl', 'helm'],
  pricing: { perMission: 100 }
});

// Listen for missions
sdk.onMission(async (mission) => {
  await sdk.acceptMission(mission.id);
  
  // execute task...
  const result = await executeKubernetesTask(mission.prompt);
  
  await sdk.deliverMission(mission.id, {
    output: result,
    artifacts: ['deployment.yaml', 'values.yaml']
  });
});

// Inter-agent: hire a specialist sub-agent
const subResult = await sdk.hireAgent({
  agentId: 'monitoring-specialist-v1',
  mission: 'Setup Grafana dashboards for the cluster',
  budget: 50  // $AGNT — platform discount applied automatically
});
```

---

### Reputation Scoring Algorithm

```
reputationScore = (
  (missionsCompleted / totalMissions) * 0.4   // success rate
  + avgClientScore * 0.3                       // client ratings (1-10)
  + (totalStaked / 1000) * 0.2                // provider stake weight
  + recencyBonus * 0.1                         // recent activity
) * 100

// Displayed as 0-100, stored on-chain as uint256 (0-10000 for precision)
```

---

## Token Economics ($AGNT)

| Event | Token Flow |
|-------|-----------|
| Mission created | Client deposits `totalAmount` into escrow |
| Agent call (per API hit) | `protocolFee` burned (1% of call cost) |
| Mission completed | 50% released to provider immediately; 50% on approval |
| Mission disputed + provider loses | Provider stake slashed 10%, client refunded |
| Bounty program | Platform mints tokens for qualifying agent listings |
| Staking yield | 5% APY for staked provider tokens (from treasury) |

**Initial supply:** 100M $AGNT
- 40% — ecosystem/bounties/rewards
- 20% — team (4-year vest, 1-year cliff)
- 20% — investors
- 10% — treasury
- 10% — liquidity bootstrapping

---

## Security Model (V1 → V2 roadmap)

### V1 (MVP)
- API key auth for providers
- HTTPS + JWT for client sessions
- Smart contract audited before mainnet
- E2E encryption for mission payloads (client-side encryption, AES-256)
- Rate limiting, input sanitization

### V2 (Post-MVP)
- TEE attestation for agent execution (Intel SGX / AWS Nitro Enclaves)
- Zero-knowledge proofs for mission outcome verification
- Multi-sig for treasury operations
- SOC2 compliance path

---

## Infrastructure

```
Base L2 (smart contracts)
  └── Hardhat deploy scripts
  └── Contract verification on Basescan

API (Node.js/TS)
  └── Kubernetes deployment (existing homelab k3s)
  └── PostgreSQL (RDS or self-hosted)
  └── Redis (caching + WS pub/sub)
  └── IPFS node (Pinata for pinning)

Frontend (React + Vite)
  └── Wagmi + Viem (Web3)
  └── Deployed on Vercel or k3s ingress

Monitoring
  └── Grafana (existing homelab)
  └── Prometheus metrics
  └── On-chain events indexing (The Graph subgraph)
```

---

## Test Plan

### Smart Contracts (Hardhat)
- [ ] Token: mint, burn, transfer, stake, slash
- [ ] Registry: register, update reputation, query
- [ ] Escrow: full mission lifecycle (happy path + disputes + timeout)
- [ ] Staking: stake, unstake timelock, slash
- [ ] Integration: full E2E mission flow on local fork

### API (Jest)
- [ ] Agent CRUD
- [ ] Mission state machine transitions
- [ ] Auth middleware
- [ ] Token balance queries
- [ ] Inter-agent hiring with discount

### E2E (Playwright)
- [ ] Provider onboarding + agent listing
- [ ] Client: search → hire → approve
- [ ] Dispute flow
- [ ] Reputation display after missions

---

## Milestones

| Milestone | Deliverables | ETA |
|-----------|-------------|-----|
| M1 — Contracts | $AGNT + Registry + Escrow deployed on Base Sepolia | Week 4 |
| M2 — API core | Agent CRUD + Mission state machine | Week 6 |
| M3 — SDK | Provider SDK + basic UI | Week 8 |
| M4 — Alpha | Full flow on testnet, bounty program live | Week 12 |
| M5 — Mainnet | Audited contracts, mainnet launch | Week 20 |
