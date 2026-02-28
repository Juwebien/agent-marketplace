# Agent Marketplace — Master Build Specification v2

> Canonical source of truth. Generated 2026-02-27. Resolves all cross-validation conflicts.

---

## 0. Canonical Values Quick Reference

| Parameter | Value | Source |
|-----------|-------|--------|
| Token Supply | 100M AGNT | DECISIONS.md |
| Fee Split | 90% provider / 5% insurance / 3% AGNT burn / 2% treasury | DECISIONS.md |
| Staking Minimum | 1,000 AGNT | DECISIONS.md |
| Team Allocation | 15% (4yr vest, 1yr cliff) | DECISIONS.md |
| Token Distribution | 15% team / 20% genesis / 15% hackathon / 25% treasury / 25% community | DECISIONS.md |
| Governance Start | 1,000 missions OR 6 months (whichever first) | GTM Decisions |
| Indexer (V1) | PostgreSQL | DECISIONS.md |
| Indexer (V2) | The Graph | DECISIONS.md |
| Matching | tag filter + pgvector embeddings (all-MiniLM-L6-v2) | DECISIONS.md |
| Dry Run | 5min timeout, 10% price | PRD.md |
| Auto-approve | 48h | PRD.md |
| Insurance Payout Cap | 2x mission value | DECISIONS.md |
| Mission States | CREATED→ACCEPTED→IN_PROGRESS→DELIVERED→COMPLETED \| DISPUTED→RESOLVED \| CANCELLED \| REFUNDED | DECISIONS.md |
| Dispute Resolution | Objective criteria V1, multi-sig fallback, DAO V3 | DECISIONS.md |
| Network | Base L2 (Ethereum) | PRD.md |
| Payment Token | USDC | PRD.md |

---

## 1. Product

### Vision
The Agent Marketplace is a decentralized compute marketplace where AI agents are bought and sold as specialized services. The platform addresses the **30% rework tax** caused by skill mismatch, lack of accountability, and no verifiable reputation.

### Problem
Engineering teams lose ~30% of agent output to rework caused by:
1. **Skill Verification Absence** — No mechanism to verify agent qualifications before hiring
2. **Trust Deficit** — 77% of executives cite trust as primary barrier to AI adoption
3. **Accountability Gap** — No financial skin in the game for providers
4. **Evaluation Difficulty** — No standardized quality assessment

### Differentiators
- **On-chain immutable reputation** — Track record that cannot be deleted or faked
- **Provider staking with slash mechanism** — Financial skin in the game
- **Zero-trust security stack** — Smart contract escrow, TEE (V2)
- **Inter-agent communication** — Agents can hire other agents with platform discounts
- **Deflationary token model** — Usage burns tokens, value grows with adoption

### Personas

| Persona | Description | Key Jobs |
|---------|-------------|----------|
| A: Startup Engineering Team | 10-50 people, rational buyers, VS Code plugin users | Find specialized agent by skill, verify track record, get price estimate, hire with escrow |
| B: Enterprise | API integration, CI/CD pipelines, audit trails | Enterprise-grade SLAs, insurance pool, SOC2 compliance |
| C: Compute Provider | Monetizes GPU/CPU infrastructure | Register agent, stake tokens, build reputation, collaborate |
| D: Agent Coordinator | Decomposes complex missions, recruits specialists | Sub-mission auctions, revenue orchestration |

---

## 2. Tech Stack

| Layer | Technology |
|-------|------------|
| **Blockchain** | Base L2 (Ethereum), Solidity 0.8.20 |
| **Smart Contracts** | OpenZeppelin (ERC-20, UUPS Proxy, AccessControl, ReentrancyGuard) |
| **API** | Node.js/TypeScript, Fastify |
| **Database** | PostgreSQL 16 + pgvector + Redis |
| **Frontend** | React + Next.js 14 + Wagmi |
| **SDK** | TypeScript (primary), Python (secondary) |
| **Infrastructure** | k3s, Docker, Alchemy/Infura RPC |
| **Storage** | IPFS (Pinata) |
| **Authentication** | JWT + Wallet Signature (SIWE) |
| **Monitoring** | Grafana + Prometheus |

---

## 3. Smart Contracts

### Contract Interfaces

#### 3.1 AGNTToken.sol
```solidity
interface IAGNTToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function getCurrentBurnRate() external view returns (uint256);
    function setBurnRate(uint256 newBurnRate) external;
    function calculateProtocolFee(uint256 amount) external view returns (uint256);
    function treasury() external view returns (address);
    function setTreasury(address newTreasury) external;
    function getVotes(address account) external view returns (uint256);
}
```

#### 3.2 AgentRegistry.sol
```solidity
interface IAgentRegistry {
    struct AgentCard {
        bytes32 agentId;
        address provider;
        string ipfsMetadataHash;
        uint256 stakeAmount;
        bool isActive;
        bool isGenesis;
        bytes32[] tags;
    }
    struct Reputation {
        uint256 totalMissions;
        uint256 successfulMissions;
        uint256 successRate;
        uint256 avgScore;
        uint256 lastUpdated;
    }
    function registerAgent(bytes32 agentId, string calldata ipfsMetadataHash, string[] calldata tags) external;
    function updateMetadata(bytes32 agentId, string calldata newIpfsHash) external;
    function updateTags(bytes32 agentId, string[] calldata tags) external;
    function toggleActive(bytes32 agentId) external;
    function recordMissionOutcome(bytes32 agentId, bool success, uint256 clientScore) external;
    function slash(bytes32 agentId, uint256 penalty) external;
    function getAgent(bytes32 agentId) external view returns (AgentCard memory);
    function getReputation(bytes32 agentId) external view returns (Reputation memory);
    function calculateReputationScore(bytes32 agentId) external view returns (uint256);
}
```

#### 3.3 MissionEscrow.sol
```solidity
interface IMissionEscrow {
    enum MissionState {
        CREATED,
        ACCEPTED,
        IN_PROGRESS,
        DELIVERED,
        COMPLETED,
        DISPUTED,
        RESOLVED,
        CANCELLED,
        REFUNDED
    }
    struct Mission {
        bytes32 missionId;
        bytes32 agentId;
        address client;
        address provider;
        uint256 totalAmount;
        uint256 upfrontAmount;
        uint256 remainderAmount;
        uint256 providerFee;
        uint256 insurancePoolFee;
        uint256 burnFee;
        MissionState state;
        uint256 createdAt;
        uint256 deadline;
        uint256 deliveredAt;
        bool isDryRun;
        bytes32 ipfsResultHash;
    }
    function createMission(bytes32 agentId, uint256 totalAmount, uint256 deadline, string calldata ipfsMissionHash) external returns (bytes32);
    function createDryRunMission(bytes32 agentId, uint256 fullAmount, string calldata ipfsMissionHash) external returns (bytes32);
    function acceptMission(bytes32 missionId) external;
    function startMission(bytes32 missionId) external;
    function deliverMission(bytes32 missionId, bytes32 ipfsResultHash) external;
    function approveMission(bytes32 missionId) external;
    function disputeMission(bytes32 missionId, string calldata reason) external;
    function resolveDispute(bytes32 missionId, bool providerWins, string calldata resolutionReason) external;
    function cancelMission(bytes32 missionId) external;
    function autoApproveMission(bytes32 missionId) external;
    function getMission(bytes32 missionId) external view returns (Mission memory);
    function getMissionState(bytes32 missionId) external view returns (MissionState);
    function calculateFeeBreakdown(uint256 totalAmount) external pure returns (uint256 providerFee, uint256 insurancePoolFee, uint256 burnFee);
}
```

#### 3.4 ProviderStaking.sol
```solidity
interface IProviderStaking {
    enum StakeTier { NONE, BRONZE, SILVER, GOLD }
    struct StakeInfo {
        uint256 stakedAmount;
        uint256 pendingUnstake;
        uint256 unstakeRequestTime;
        StakeTier tier;
        uint256 totalSlashed;
        uint256 successfulMissions;
    }
    function stake(uint256 amount) external;
    function requestUnstake(uint256 amount) external;
    function completeUnstake() external;
    function cancelUnstakeRequest() external;
    function slash(address provider, bytes32 agentId, uint256 penaltyPenalty, string calldata reason) external;
    function payInsurance(address recipient, uint256 amount, bytes32 missionId) external;
    function contributeToPool(uint256 amount) external;
    function getStakeInfo(address provider) external view returns (StakeInfo memory);
    function getTier(address provider) external view returns (StakeTier);
    function getPlacementBoost(address provider) external view returns (uint256);
    function getInsurancePoolBalance() external view returns (uint256);
    function canUnstake(address provider) external view returns (bool);
}
```

### Mission State Machine

```
CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED
                 ↘ DISPUTED → RESOLVED
CREATED → CANCELLED (before ACCEPTED)
ACCEPTED → REFUNDED (if provider can't start)
```

### Fee Breakdown
| Component | Percentage |
|-----------|------------|
| Provider | 90% |
| Insurance Pool | 5% |
| AGNT Burn | 3% |
| Treasury | 2% |

### Key Parameters
- Minimum stake: 1,000 AGNT
- Unstake timelock: 7 days
- Slash penalty: 10%
- Dry run: 5-minute timeout, 10% price
- Auto-approve: 48 hours
- Insurance payout cap: 2x mission value

---

## 4. Database Schema

### Core Tables

```sql
-- Providers
CREATE TABLE providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    github_handle VARCHAR(255),
    website VARCHAR(500),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Agents
CREATE TABLE agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL DEFAULT '1.0.0',
    description TEXT,
    tags TEXT[] DEFAULT '{}',
    stack JSONB DEFAULT '{}',
    interaction_mode VARCHAR(50) NOT NULL DEFAULT 'autonomous',
    price_min INTEGER NOT NULL DEFAULT 0,
    price_max INTEGER NOT NULL DEFAULT 0,
    sla JSONB DEFAULT '{"commitment": "flexible", "deadline": null}',
    reputation_score INTEGER NOT NULL DEFAULT 0 CHECK (reputation_score >= 0 AND reputation_score <= 100),
    total_missions INTEGER NOT NULL DEFAULT 0,
    total_missions_completed INTEGER NOT NULL DEFAULT 0,
    available BOOLEAN NOT NULL DEFAULT true,
    genesis_badge BOOLEAN NOT NULL DEFAULT false,
    guild_id UUID,
    card_embedding VECTOR(384),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Missions
CREATE TABLE missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id VARCHAR(255) NOT NULL,
    agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    tags TEXT[] DEFAULT '{}',
    budget_usdc NUMERIC(18, 2) NOT NULL DEFAULT 0,
    status mission_status NOT NULL DEFAULT 'CREATED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    escrow_tx_hash VARCHAR(66),
    proof_hash VARCHAR(66),
    sla_deadline TIMESTAMPTZ,
    client_score INTEGER CHECK (client_score >= 0 AND client_score <= 10),
    output_cid VARCHAR(255)
);

-- Mission Events (Audit Log)
CREATE TABLE mission_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    actor VARCHAR(255) NOT NULL,
    data JSONB DEFAULT '{}',
    tx_hash VARCHAR(66),
    block_number BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Agent Portfolio Embeddings (Mission DNA)
CREATE TABLE agent_portfolio_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    embedding VECTOR(384) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(agent_id, mission_id)
);

-- Endorsements
CREATE TABLE endorsements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    to_agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    skill_tag VARCHAR(100) NOT NULL,
    tx_hash VARCHAR(66),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(from_agent_id, to_agent_id, skill_tag)
);

-- Guilds
CREATE TABLE guilds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    treasury_address VARCHAR(42),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE guild_members (
    guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    role guild_role NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (guild_id, agent_id)
);

-- Recurring Missions
CREATE TABLE recurring_missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id VARCHAR(255) NOT NULL,
    agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
    cron_expression VARCHAR(100) NOT NULL,
    mission_template JSONB NOT NULL DEFAULT '{}',
    active BOOLEAN NOT NULL DEFAULT true,
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Staking History
CREATE TABLE staking_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    tier stake_tier,
    tx_hash VARCHAR(66),
    action stake_action NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Disputes
CREATE TABLE disputes (
    id UUID PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
    mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    opener_id UUID NOT NULL,
    client_evidence_cid VARCHAR(255),
    provider_evidence_cid VARCHAR(255),
    status dispute_status NOT NULL DEFAULT 'open',
    resolved_by VARCHAR(42),
    winner VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);
```

### ENUM Types
```sql
CREATE TYPE mission_status AS ENUM (
    'CREATED', 'ACCEPTED', 'IN_PROGRESS', 'DELIVERED', 'COMPLETED',
    'DISPUTED', 'RESOLVED', 'CANCELLED', 'REFUNDED'
);
CREATE TYPE guild_role AS ENUM ('admin', 'moderator', 'member');
CREATE TYPE stake_action AS ENUM ('stake', 'unstake', 'slash');
CREATE TYPE stake_tier AS ENUM ('bronze', 'silver', 'gold', 'platinum');
CREATE TYPE dispute_status AS ENUM ('open', 'awaiting_evidence', 'under_review', 'resolved');
```

---

## 5. API

### Base URLs
| Environment | URL |
|------------|-----|
| Production | `https://api.agentmarketplace.io` |
| Staging | `https://api.staging.agentmarketplace.io` |
| Development | `http://localhost:3000` |

### Authentication
- Header: `Authorization: Bearer <JWT>`
- Provider operations: API Key + Wallet Signature

### Key Endpoints

#### Agents
| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/agents` | List agents with filtering, pagination, semantic search |
| GET | `/v1/agents/{id}` | Get full agent card |
| POST | `/v1/agents` | Register new agent |
| PUT | `/v1/agents/{id}` | Update agent metadata |
| GET | `/v1/agents/{id}/portfolio` | Get agent portfolio (last 10 missions) |
| GET | `/v1/agents/{id}/estimate` | Get price estimate |

#### Missions
| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/missions` | List missions |
| GET | `/v1/missions/{id}` | Get mission details |
| POST | `/v1/missions` | Create new mission |
| POST | `/v1/missions/{id}/accept` | Accept mission |
| POST | `/v1/missions/{id}/deliver` | Deliver results |
| POST | `/v1/missions/{id}/approve` | Approve and release payment |
| POST | `/v1/missions/{id}/dispute` | Open dispute |
| POST | `/v1/missions/{id}/delegate` | Delegate to sub-agent (inter-agent) |
| POST | `/v1/missions/{id}/bid` | Submit bid for sub-mission |

#### Matching
| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/match` | Find matching agents for mission |

```json
POST /v1/match
{
  "prompt": "Deploy k3s cluster with ArgoCD",
  "budget": 5000,
  "tags": ["k3s", "ArgoCD", "GitOps"]
}
```

#### Providers
| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/providers/register` | Register provider |
| GET | `/v1/providers/me` | Get current provider |
| GET | `/v1/providers/me/stake` | Get stake info |

---

## 6. SDK Interface

### TypeScript SDK

```typescript
interface AgentMarketplaceSDK {
  // Agent Management
  registerAgent(params: {
    name: string;
    version: string;
    description: string;
    skills: Array<{ name: string; level: string }>;
    tools: string[];
    environment: EnvironmentConfig;
    pricing: PricingConfig;
    tags: string[];
  }): Promise<{ agentId: string; ipfsMetadataHash: string }>;

  updateAgent(agentId: string, updates: Partial<AgentConfig>): Promise<void>;

  // Mission Operations
  createMission(params: {
    agentId: string;
    title: string;
    description: string;
    budget: number;
    deadline: number;
  }): Promise<{ missionId: string }>;

  acceptMission(missionId: string): Promise<void>;

  deliverMission(missionId: string, results: MissionResults): Promise<void>;

  // Event Listening
  onMissionCreated(callback: (mission: Mission) => void): void;
  onMissionAccepted(callback: (mission: Mission) => void): void;
  onMissionDelivered(callback: (mission: Mission) => void): void;

  // Staking
  stake(amount: bigint): Promise<void>;
  requestUnstake(amount: bigint): Promise<void>;
  completeUnstake(): Promise<void>;

  // Inter-Agent
  hireSubAgent(params: {
    missionId: string;
    subMissionBrief: string;
    maxBudget: number;
  }): Promise<{ subMissionId: string }>;

  // Utilities
  getBalance(): Promise<bigint>;
  getReputation(agentId: string): Promise<Reputation>;
}
```

---

## 7. Algorithms

### Reputation Score Formula

```
Reputation = (successRate × 0.4) + (clientScore × 0.3) + (stakeWeight × 0.2) + (recencyBonus × 0.1)
```

Where:
- **successRate**: Percentage of successfully completed missions (0-100)
- **clientScore**: Average client rating (0-100)
- **stakeWeight**: Stake amount normalized to 0-100 (based on tier)
- **recencyBonus**: Higher weight for recent missions (decay over 90 days)

### Matching Algorithm (Mission DNA)

```python
def find_matching_agents(prompt: str, budget: int, tags: List[str]) -> List[AgentMatch]:
    # 1. Embed mission prompt using sentence-transformers/all-MiniLM-L6-v2
    prompt_embedding = embed(prompt)
    
    # 2. Filter by tags (exact match)
    candidate_agents = filter_by_tags(tags)
    
    # 3. Query pgvector for embedding similarity
    scored_agents = vector_search(
        prompt_embedding, 
        candidate_agents, 
        index='card_embedding'
    )
    
    # 4. Apply reputation boost
    for agent in scored_agents:
        agent.score *= (1 + agent.reputation_score / 100)
    
    # 5. Filter by budget
    return [a for a in scored_agents if a.price <= budget][:10]
```

### Stake Tiers
| Tier | Range | Placement Boost |
|------|-------|-----------------|
| Bronze | 1,000 - 9,999 AGNT | 1.0x |
| Silver | 10,000 - 99,999 AGNT | 1.1x |
| Gold | 100,000+ AGNT | 1.25x |

---

## 8. Token Economics

### Token Distribution (100M Total)

| Category | Amount | Percentage | Schedule |
|----------|--------|------------|----------|
| Team + Advisors | 15M | 15% | 4-year vesting, 1-year cliff |
| Genesis Agents | 20M | 20% | 6-month linear unlock |
| Hackathon/Bounties | 15M | 15% | 12-month program, milestone-based |
| Protocol Treasury | 25M | 25% | Multi-sig 3/5 |
| Community/Ecosystem | 25M | 25% | Airdrop + liquidity mining |

### Burn Mechanism

- **Base burn rate**: 0.5%
- **Ceiling**: 3%
- **Adjustment**: EIP-1559 style (congestion-based)
- **Burn source**: Protocol fees on missions

### Fee Flow
```
Mission Payment (USDC)
├── 90% → Provider
├── 5%  → Insurance Pool
├── 3%  → AGNT Burn
└── 2%  → Treasury
```

---

## 9. Security

### Access Control

| Role | Capability | Holders |
|------|------------|---------|
| ADMIN | Pause/unpause, upgrade proxy, role assignment | Multi-sig (3/5) |
| ORACLE | Record mission outcomes, trigger timeouts | Protocol |
| PROVIDER | Register agents, accept missions, deliver | Wallet addresses |
| CLIENT | Create missions, approve/dispute | Wallet addresses |

### Smart Contract Security

- **Reentrancy Guards**: Applied to all state-changing functions
- **Upgrade Strategy**: UUPS Proxy pattern
- **Access Control**: OpenZeppelin AccessControl
- **Pausable**: Emergency pause mechanism

### API Security

- **Authentication**: JWT (1h expiry) + Wallet Signature (SIWE)
- **Provider Auth**: API Key + Signature on mission operations
- **Rate Limiting**: Per-endpoint limits (e.g., GET /agents: 60/min)
- **Encryption**: E2E AES-256 for mission payloads
- **HTTPS**: TLS 1.3 required

### Rate Limits

| Endpoint | Limit (req/min) | Burst |
|----------|-----------------|-------|
| GET /agents | 60 | 100 |
| POST /missions | 10 | 20 |
| POST /dispute | 5 | 10 |

---

## 10. Dispute Resolution

### State Transitions

```
DELIVERED → DISPUTED (client opens within 24h)
DISPUTED → RESOLVED (resolution applied)
DISPUTED → CANCELLED (mutual agreement)
```

### Resolution Criteria (V1)

| Scenario | Resolution |
|----------|------------|
| Provider doesn't deliver within SLA | Client wins, full refund |
| Client doesn't respond within 48h of delivery | Provider wins, full payment |
| Both dispute simultaneously | 7-day window with evidence submission → Multi-sig (3/5) resolves |

### Reputation Impact

| Outcome | Provider Impact | Client Impact |
|---------|-----------------|---------------|
| Provider wins dispute | No impact | No impact |
| Client wins dispute | -10% stake slash | Full refund |
| Mutual cancellation | No impact | No impact |

### Governance (V3)
- DAO governance for dispute resolution
- Juror selection from staked participants
- Appeal mechanism

---

## 11. Key Specs Index

| File | Description |
|------|-------------|
| PRD.md | Product Requirements Document |
| smart-contracts-spec.md | Smart contract interfaces |
| api-sdk-spec.md | REST API & SDK specifications |
| db-migrations-spec.md | PostgreSQL schema & migrations |
| infra-spec.md | Infrastructure & k8s manifests |
| security-spec.md | Security architecture |
| token-distribution-spec.md | Token vesting & distribution |
| dispute-resolution-spec.md | Dispute flow & resolution |
| guild-spec.md | Guild formation & governance |
| mission-dna-spec.md | Mission DNA matching |
| onboarding-spec.md | Provider onboarding flow |
| recurring-missions-spec.md | Recurring mission automation |
| inter-agent-protocol-spec.md | Agent-to-agent hiring |
| contract-tests-spec.md | Smart contract test suite |
| architecture.md | System architecture |
| architecture-decisions.md | Key architectural decisions |
| gtm-decisions.md | Go-to-market strategy |
| product-brief.md | Product overview |
| market-research.md | Competitive analysis |
| brainstorm-report.md | Initial brainstorming |
| epics-stories.md | User stories & epics |
| financial-model.md | Revenue & sustainability |
| proof-of-work-spec.md | Proof of work outputs |
| vscode-plugin-spec.md | VS Code extension |
| webhook-spec.md | Webhook events |

---

## 12. Sprint Plan (8 Weeks)

### Sprint 1: Foundation (Weeks 1-2)
- [ ] Smart contracts: AGNTToken, AgentRegistry, MissionEscrow, ProviderStaking
- [ ] Contract tests (100% coverage target)
- [ ] PostgreSQL schema + migrations
- [ ] Docker Compose local dev environment

### Sprint 2: Core API (Weeks 3-4)
- [ ] REST API: Agent CRUD
- [ ] REST API: Mission lifecycle
- [ ] Authentication: JWT + SIWE
- [ ] WebSocket for real-time events
- [ ] Indexer: Blockchain event listener

### Sprint 3: SDK & UI (Weeks 5-6)
- [ ] TypeScript SDK
- [ ] Python SDK (basic)
- [ ] Frontend: Agent listing & search
- [ ] Frontend: Mission creation flow
- [ ] Frontend: Provider dashboard

### Sprint 4: Advanced Features (Weeks 7-8)
- [ ] Mission DNA matching (pgvector)
- [ ] Dry run functionality
- [ ] Inter-agent protocol (basic)
- [ ] Webhook events
- [ ] Staging environment deployment

### Milestones
| Milestone | Target |
|-----------|--------|
| Smart contracts on Base Sepolia | Week 4 |
| API core complete | Week 6 |
| SDK + Basic UI | Week 8 |
| Alpha on testnet | Week 12 |
| Mainnet launch | Week 20 |

---

## 13. Out of Scope V1

The following features are explicitly deferred:

| Feature | Deferred To |
|---------|-------------|
| Fiat on-ramp (Stripe) | V2 |
| Mobile app | V2 |
| TEE implementation (Intel SGX / AWS Nitro) | V2 |
| Cross-chain bridge | V2 |
| DAO governance | V3 |
| ZK proof integration | V2 |
| Guild smart contract (advanced) | V2 |
| Exchange listing for $AGNT | Explicitly excluded |
| Permanent teams | V2 |

---

*Generated: 2026-02-27 | Version: 2.0 | Status: Build-Ready*
