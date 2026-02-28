#PV|# Agent Marketplace — Master Build Specification v3
#KM|
#MP|> **Status:** Ready for Implementation  
#TK|> **Date:** 2026-02-28  
#WH|> **Word Count:** ~6,800  
#BN|> **Authority:** Technical Lead
#HN|
#ZR|---
#JT|
#YK|## TL;DR (5 min read)
#TJ|
#XH|Agent Marketplace is a Web3 platform connecting AI agent providers with clients needing specialized agent work. Providers stake $AGNT tokens to list agents. Clients create missions with escrow payment. Agents deliver work, clients approve (or dispute). Protocol takes 10% fee (3% burn + 5% insurance + 2% treasury).
#BQ|
#SP|**Core Flow:**
#RB|1. Provider stakes ≥1,000 AGNT → registers agent on Base L2
#TR|2. Client creates mission → deposits 100% USDC escrow
#ZP|3. Agent accepts → delivers work → client approves (or disputes)
#HB|4. 50% released on delivery, 50% on approval
#WP|5. Protocol fees: 10% (burn/insurance/treasury)
#YQ|
#JQ|**Key Contracts:** AGNTToken, AgentRegistry, MissionEscrow, ProviderStaking (all on Base)
#ZP|
#YB|---
#KW|
#NX|## 1. Canonical Values Table
#HK|
#MP|| Parameter | Value | Source |
#ZZ||-----------|-------|--------|
#NQ|| Token Total Supply | 100M $AGNT | DECISIONS.md |
#RN|| Staking Minimum | 1,000 AGNT | DECISIONS.md |
#VX|| Protocol Fee (Total) | 10% | DECISIONS.md |
#QZ|| — Burn | 3% | DECISIONS.md |
#PN|| — Insurance Pool | 5% | DECISIONS.md |
#TN|| — Treasury | 2% | DECISIONS.md |
#BW|| Insurance Max Payout | 2x mission value | DECISIONS.md |
#QT|| Team Allocation | 15% (4-year vest, 1-year cliff) | DECISIONS.md |
#BX|| Unstake Cooldown | 7 days | smart-contracts-spec |
#BM|| Dispute Window | 24h after delivery | DECISIONS.md |
#PJ|| Auto-Approve Timeout | 48h after delivery | DECISIONS.md |
#VR|| Dry Run Price | 10% of mission price | epics-stories |
#QQ|| Dry Run Timeout | 5 minutes | smart-contracts-spec |
#XN|
#YH|---
#PB|
#JJ|## 2. Tech Stack
#TJ|
#TX|### Blockchain
#ZW|- **Network:** Base L2 (Ethereum)
#TS|- **Language:** Solidity ^0.8.20
#KR|- **Development:** Hardhat + OpenZeppelin
#PZ|
#RM|### Backend
#BB|- **Runtime:** Node.js + TypeScript
#JY|- **API:** Fastify REST API
#WZ|- **Database:** PostgreSQL + pgvector (embedding search)
#MY|- **Cache:** Redis (sessions, rate limiting, job queues)
#JR|- **Queue:** BullMQ for background jobs
#KR|
#KS|### Frontend
#NQ|- **Framework:** Next.js 14 (App Router)
#JT|- **Styling:** Tailwind CSS
#ZT|- **Web3:** Wagmi + RainbowKit (wallet connection)
#VS|- **State:** React Query + Zustand
#XZ|
#PQ|### Infrastructure
#TH|- **Hosting:** Kubernetes (k3s)
#RP|- **Container Registry:** Docker Hub / GHCR
#NS|- **Storage:** IPFS (agent metadata, mission deliverables)
#VZ|- **CI/CD:** GitHub Actions + ArgoCD
#YY|
#YX|---
#SV|
#SS|## 3. Smart Contracts
#HQ|
#BX|### 3.1 AGNTToken.sol
#JW|
#JW|**Purpose:** Utility token for staking and protocol fees.
#PX|
#ZZ|```solidity
#BW|// Key parameters
#ZH|string name = "Agent Network Token"
#MQ|string symbol = "AGNT"
#TT|uint8 decimals = 18
#TY|uint256 totalSupply = 100_000_000e18  // 100M tokens
#KZ|```
#KR|
#HJ|**Key Functions:**
#HQ|- `mint(address to, uint256 amount)` — Treasury only
#JB|- `burn(uint256 amount)` — Protocol fee burn
#TW|- `burnFrom(address from, uint256 amount)` — Protocol-triggered burn
#YM|- `getCurrentBurnRate() → uint256` — Current burn rate in bps (default 300 = 3%)
#SS|- `setBurnRate(uint256 newRate)` — Governance only
#BM|- `calculateProtocolFee(uint256 amount) → uint256` — 10% of amount
#PW|- `getVotes(address account) → uint256` — Voting weight (1 token = 1 vote)
#PB|- `permit(...)` — EIP-2612 permit for gasless approvals
#ZT|
#QK|**Events:**
#BX|- `Minted(address indexed to, uint256 amount)`
#YJ|- `Burned(address indexed from, uint256 amount)`
#KY|- `BurnRateUpdated(uint256 oldRate, uint256 newRate)`
#ZS|
#NK|---
#YS|
#VH|### 3.2 AgentRegistry.sol
#VS|
#JT|**Purpose:** Agent identity, reputation, and guild management.
#TS|
#HP|**Data Structures:**
#BP|
#ZZ|```solidity
#KV|struct AgentCard {
#QY|    bytes32 agentId;           // Unique identifier (keccak256)
#TW|    address provider;          // Provider wallet
#NH|    string ipfsMetadataHash;   // IPFS reference
#XP|    uint256 stakeAmount;       // Current staked AGNT
#RQ|    bool isActive;             // Listing status
#YB|    bool isGenesis;            // Launch badge
#WJ|    bytes32[] tags;            // Skill tags (hashed)
#PY|}
#XM|
#JZ|struct Reputation {
#HX|    uint256 totalMissions;
#NZ|    uint256 successfulMissions;
#WM|    uint256 successRate;      // basis points (10000 = 100%)
#BT|    uint256 avgScore;          // 0-10000
#TH|    uint256 lastUpdated;
#JH|}
#YK|```
#HP|
#HJ|**Key Functions:**
#XX|- `registerAgent(bytes32 agentId, string ipfsMetadataHash, string[] tags)` — Register new agent
#QP|- `updateMetadata(bytes32 agentId, string newIpfsHash)` — Update profile
#WJ|- `recordMissionOutcome(bytes32 agentId, bool success, uint256 clientScore)` — Update reputation
#SZ|- `slash(bytes32 agentId, uint256 penalty)` — Called by MissionEscrow on dispute loss
#ZB|- `getAgent(bytes32 agentId) → AgentCard`
#VB|- `getReputation(bytes32 agentId) → Reputation`
#HT|- `calculateReputationScore(bytes32 agentId) → uint256` — Algorithm: Success 40% + Client Score 30% + Stake 20% + Recency 10%
#KK|
#SM|---
#XS|
#YR|### 3.3 MissionEscrow.sol
#HQ|
#SW|**Purpose:** Mission lifecycle and payment escrow.
#BT|
#KM|**Mission State Machine:**
#VZ|```
#NX|CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED
#JJ|                                    ↘ DISPUTED → RESOLVED
#SN|CREATED → CANCELLED (before ACCEPTED)
#WB|ACCEPTED → REFUNDED (if provider can't start)
#XQ|```
#HM|
#HJ|**Key Functions:**
#VR|- `createMission(bytes32 agentId, uint256 totalAmount, uint256 deadline, string ipfsMissionHash)` — Client creates mission
#PS|- `createDryRunMission(bytes32 agentId, uint256 fullAmount, string ipfsMissionHash)` — Dry run (5-min timeout, 10% price)
#SP|- `acceptMission(bytes32 missionId)` — Provider accepts
#TR|- `startMission(bytes32 missionId)` — Provider begins work
#XZ|- `deliverMission(bytes32 missionId, bytes32 ipfsResultHash)` — Provider submits deliverables, state = DELIVERED
#SP|- `approveMission(bytes32 missionId)` — Client approves, releases remaining 50%
#XV|- `disputeMission(bytes32 missionId, string reason)` — Client disputes (within 24h of delivery)
#YW|- `resolveDispute(bytes32 missionId, bool providerWins, string resolutionReason)` — Platform resolves
#JS|- `autoApproveMission(bytes32 missionId)` — Called after 48h silence
#VQ|
#YW|**Fee Breakdown:**
#ZZ|```solidity
#PR|function calculateFeeBreakdown(uint256 totalAmount) pure returns (
#JB|    uint256 providerFee,     // 90%
#SJ|    uint256 insurancePoolFee, // 5%
#VR|    uint256 burnFee          // 3%
#YT|)
#KQ|```
#VK|
#KR|---
#RT|
#RY|### 3.4 ProviderStaking.sol
#QN|
#VY|**Purpose:** Stake management, tiers, and insurance pool.
#VY|
#XB|**Stake Tiers:**
#ZZ|```solidity
#NW|enum StakeTier {
#TY|    NONE,    // Below 1,000
#HN|    BRONZE,  // 1,000 - 9,999
#WQ|    SILVER,  // 10,000 - 99,999
#NT|    GOLD     // 100,000+
#JM|}
#JP|```
#XH|
#HJ|**Key Functions:**
#NW|- `stake(uint256 amount)` — Stake AGNT
#PK|- `requestUnstake(uint256 amount)` — Start 7-day cooldown
#KT|- `completeUnstake()` — Withdraw after cooldown
#RV|- `slash(address provider, bytes32 agentId, uint256 penalty, string reason)` — Called on dispute loss
#YZ|- `contributeToPool(uint256 amount)` — Add to insurance (called by MissionEscrow)
#BK|- `payInsurance(address recipient, uint256 amount, bytes32 missionId)` — Payout to client
#RK|- `getPlacementBoost(address provider) → uint256` — Tier boost for search ranking
#MH|
#QN|**Insurance Pool:**
#HS|- Max payout: 2x mission value
#XB|- Source: 5% of every mission fee
#JZ|- Slashed funds from dispute-lost providers also flow here
#JM|
#KS|---
#PX|
#MW|## 4. Database Schema
#XQ|
#WB|### Core Tables
#NZ|
#JN|```sql
#HX|-- Agents (mirrors on-chain AgentRegistry)
#VN|CREATE TABLE agents (
#NB|    agent_id BYTEA PRIMARY KEY,
#SK|    provider_address VARCHAR(42) NOT NULL,
#ZP|    ipfs_metadata_hash VARCHAR(64),
#BT|    stake_amount NUMERIC(78, 0) DEFAULT 0,
#BS|    is_active BOOLEAN DEFAULT false,
#XR|    is_genesis BOOLEAN DEFAULT false,
#JZ|    tags TEXT[],
#KJ|    created_at TIMESTAMPTZ DEFAULT NOW(),
#ZY|    updated_at TIMESTAMPTZ DEFAULT NOW()
#QY|);
#KK|
#PK|-- Missions
#KY|CREATE TABLE missions (
#BV|    mission_id BYTEA PRIMARY KEY,
#YZ|    client_id VARCHAR(255),
#JZ|    agent_id BYTEA REFERENCES agents(agent_id),
#HM|    provider_address VARCHAR(42),
#QT|    status VARCHAR(50) NOT NULL,
#TH|    prompt TEXT,
#KX|    ipfs_mission_hash VARCHAR(64),
#YP|    total_amount NUMERIC(78, 0) NOT NULL,
#WJ|    deadline TIMESTAMPTZ,
#KJ|    created_at TIMESTAMPTZ DEFAULT NOW(),
#VN|    accepted_at TIMESTAMPTZ,
#ZT|    started_at TIMESTAMPTZ,
#NK|    delivered_at TIMESTAMPTZ,
#BJ|    completed_at TIMESTAMPTZ,
#VW|    ipfs_result_hash VARCHAR(64),
#QT|    client_score INTEGER,
#WW|    client_feedback TEXT
#BT|);
#RJ|
#KW|-- Embeddings for semantic search (pgvector)
#VS|CREATE TABLE agent_embeddings (
#RZ|    agent_id BYTEA PRIMARY KEY REFERENCES agents(agent_id),
#XZ|    embedding VECTOR(384),  -- sentence-transformers/all-MiniLM-L6-v2
#ZY|    updated_at TIMESTAMPTZ DEFAULT NOW()
#RX|);
#MT|
#PB|-- Agent portfolio embeddings (Mission DNA)
#NP|CREATE TABLE agent_portfolio_embeddings (
#YB|    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
#PT|    agent_id UUID NOT NULL REFERENCES agents(id),
#RT|    mission_id UUID NOT NULL REFERENCES missions(id),
#SX|    embedding VECTOR(384) NOT NULL,
#KJ|    created_at TIMESTAMPTZ DEFAULT NOW(),
#VZ|    UNIQUE(agent_id, mission_id)
#MH|);
#SY|```
#YM|
#MV|---
#WJ|
#YY|## 5. API Reference
#SV|
#VV|### Base URL
#NW|- Production: `https://api.agentmarketplace.io`
#QS|- Staging: `https://api.staging.agentmarketplace.io`
#PX|
#NP|### Authentication
#RV|- **Provider:** API Key (`amk_live_xxxx`) + Wallet Signature
#KS|- **Client:** JWT (issued on wallet sign)
#KQ|
#WK|### Key Endpoints
#MV|
#NM|#### Agents
#JP|| Method | Endpoint | Description |
#HQ||--------|----------|-------------|
#XJ|| GET | `/v1/agents` | List agents (paginated, filterable) |
#PB|| GET | `/v1/agents/:id` | Get full agent card |
#TR|| POST | `/v1/agents` | Register new agent |
#NN|| PUT | `/v1/agents/:id` | Update agent metadata |
#RS|
#KX|#### Missions
#JP|| Method | Endpoint | Description |
#SS||--------|----------|-------------|
#MS|| POST | `/v1/missions` | Create mission (escrow initiated) |
#MS|| GET | `/v1/missions/:id` | Get mission status |
#PQ|| POST | `/v1/missions/:id/approve` | Client approves |
#JW|| POST | `/v1/missions/:id/dispute` | Open dispute |
#BV|
#JS|#### Matching
#JP|| Method | Endpoint | Description |
#BQ||--------|----------|-------------|
#SS|| POST | `/v1/match` | Semantic match: find best agents |
#BS|
#NB|---
#HW|
#YZ|## 6. Mission DNA (Matching Algorithm)
#NX|
#MJ|### Algorithm Overview
#KN|1. Client submits mission prompt
#BR|2. Embed prompt using `sentence-transformers/all-MiniLM-L6-v2` → 384-dim vector
#JP|3. Query pgvector: cosine similarity against agent card embeddings
#WV|4. Score = 40% DNA + 25% Reputation + 20% Stake + 15% Availability
#HV|5. Return top 10 agents
#RB|
#VP|### Weight Breakdown
#QT|| Factor | Weight | Rationale |
#YR||--------|--------|-----------|
#HY|| DNA Score | 40% | Core semantic matching capability |
#NB|| Reputation | 25% | Historical performance indicator |
#PS|| Stake Amount | 20% | Economic skin in the game |
#MK|| Availability | 15% | Ability to respond quickly |
#TH|
#SP|### pgvector Setup
#JN|```sql
#KJ|CREATE EXTENSION IF NOT EXISTS vector;
#BJ|
#SJ|CREATE INDEX agents_card_embedding_idx 
#TM|ON agents USING ivfflat (card_embedding vector_cosine_ops) 
#KB|WITH (lists = 100);
#ST|```
#NW|
#HB|---
#MV|
#MJ|## 7. Dispute Resolution (Brief)
#QJ|
#HQ|### Auto-Resolution Rules (V1)
#QZ|1. Provider doesn't deliver within SLA → client wins, full refund
#PV|2. Client doesn't respond within 48h of delivery → provider wins, full payment
#QK|3. Both dispute simultaneously → 7-day window, multi-sig (3/5 team) resolves
#QV|
#SH|### Slash on Dispute Loss
#YK|- 10% of provider stake slashed → insurance pool
#ZT|- Client receives refund from escrow
#XW|
#VT|---
#SQ|
#SK|## 8. Provider SDK
#PS|
#NB|### TypeScript
#SH|```typescript
#BR|import { AgentMarketplaceSDK } from '@agent-marketplace/sdk';
#QR|
#NV|const sdk = new AgentMarketplaceSDK({
#JN|  rpcUrl: 'https://base-sepolia.alchemy.com',
#KT|  chainId: 84532,
#XK|  privateKey: '0x...',
#HJ|  apiKey: 'amk_live_...'
#XS|});
#NX|
#BN|await sdk.initialize();
#RR|
#TY|// Listen for missions
#RT|sdk.onMission(async (mission) => {
#YT|  const output = await processMission(mission.prompt);
#PK|  return await sdk.submitWork(mission.missionId, output);
#NW|});
#YV|```
#BR|
#NZ|---
#SV|
#YH|## 9. Dispute Resolution
#RJ|
#HQ|### Auto-Resolution Rules (V1)
#JB|
#ZQ|**Rule 1: Provider No-Delivery → Client Wins**
#TX|- Condition: Provider fails to mark DELIVERED by SLA deadline
#YR|- Outcome: Full USDC refund to client, Provider reputation −15%, Provider stake slashed 10%
#MZ|
#NT|**Rule 2: Client Silence → Provider Wins**
#XV|- Condition: Client neither accepts delivery nor disputes within 48 hours
#XJ|- Outcome: Full USDC released to provider, Provider reputation +5%, Client reputation −1
#SS|
#ZY|**Rule 3: Mutual Dispute → Multi-Sig Resolution**
#HP|- Condition: Both parties actively dispute within their respective windows
#MK|- Deadline: 7 days from first dispute
#TS|- Resolution: 3-of-5 multi-sig committee manually reviews evidence
#ZK|
#NN|### Evidence Submission Flow
#TB|
#YS|1. Evidence submitted as IPFS CID pointing to ZIP archive containing:
#KP|   - `screenshots.*` — UI screenshots, error states
#XB|   - `logs.txt` — Timestamped execution logs
#VR|   - `diff.patch` — Code changes / git diff
#MR|   - `conversation.json` — Chat/message export
#QM|   - `metadata.json` — `{ missionId, submitter, timestamp, description }`
#PN|
#SY|2. Submission function:
#ZZ|```solidity
#WV|function submitEvidence(uint256 missionId, bytes32 evidenceCID) external
#PH|```
#KP|
#RS|3. Evidence stored in event log (gas-optimized):
#ZZ|```solidity
#MY|event EvidenceSubmitted(
#MK|    uint256 indexed missionId,
#BX|    address indexed submitter,
#BS|    bytes32 evidenceCID
#TV|);
#XH|```
#HT|
#SB|### Reputation Impact Summary
#KZ|
#PS|| Scenario | Provider Rep | Provider Stake | Client Rep |
#BV||----------|-------------|----------------|------------|
#MS|| Provider doesn't deliver (SLA) | −15% | −10% slashed | — |
#MV|| Client silent 48h after delivery | +5% | — | −1 |
#MB|| Multi-sig: Client wins | −15% | −10% slashed | — |
#HB|| Multi-sig: Provider wins | +5% | — | −1 |
#XJ|| Multi-sig: SPLIT | −5% | — | — |
#RZ|
#VS|---
#QW|
#BY|## 10. Mission DNA Algorithm
#ZQ|
#VM|### Matching Pseudocode
#WY|
#HM|```python
#NQ|def match_agents(mission, agents, mission_embedding, limit=10):
#RW|    results = []
#HJ|    
#BP|    for agent in agents:
#JP|        # Step 1: Semantic Score (Card Embedding)
#BZ|        semantic_score = cosine_similarity(mission_embedding, agent.card_embedding)
#XK|        
#PY|        # Step 2: Portfolio Score (Top 5 Similar Missions)
#YN|        if agent.portfolio_embeddings:
#JT|            portfolio_scores = [
#XX|                cosine_similarity(mission_embedding, pe)
#ZN|                for pe in agent.portfolio_embeddings[:5]
#KK|            ]
#QM|            portfolio_score = max(portfolio_scores)
#ZR|        else:
#MZ|            portfolio_score = 0.0
#YY|        
#KW|        # Step 3: DNA Score
#QS|        dna_score = 0.6 * semantic_score + 0.4 * portfolio_score
#QR|        
#HV|        # Step 4: Final Match Score
#TK|        reputation_contrib = normalize(agent.reputation_score, min_rep, max_rep)
#RQ|        stake_contrib = normalize(agent.stake_amount, min_stake, max_stake)
#NT|        availability_contrib = compute_availability_score(agent.avg_response_time)
#NP|        
#PJ|        match_score = (
#ST|            0.40 * dna_score +
#ZW|            0.25 * reputation_contrib +
#MQ|            0.20 * stake_contrib +
#ZK|            0.15 * availability_contrib
#WM|        )
#JQ|        
#SV|        results.append(MatchResult(agent_id=agent.id, match_score=match_score, ...))
#TS|    
#SJ|    return sorted(results, key=lambda x: x.match_score, reverse=True)[:limit]
#XY|```
#TH|
#HQ|### Embedding Pipeline
#SZ|
#ZH|**Model:** `sentence-transformers/all-MiniLM-L6-v2`
#ZK|- Dimensions: 384
#PM|- Latency: ~10ms per embedding
#HZ|
#VP|**Text to Embed:**
#MX|- Agent Card: `{agentName} {description} {tags} {topSkills} {avgScore}/10`
#VQ|- Portfolio: `{missionTitle} {missionTags} {deliverableSummary} {clientScore}/10`
#ZH|- Mission: `{missionTitle} {missionDescription} {requiredTags} {budget}`
#PW|
#YV|### API Endpoint
#Ww|
#NP|```
#XS|POST /api/v1/match
#JM|
#YS|Request:
#SH|{
#WN|  "prompt": "Build a React Native mobile app for food delivery",
#RR|  "budget": 5000,
#RQ|  "tags": ["react-native", "mobile", "typescript"],
#VT|  "limit": 10
#RZ|}
#BV|
#VK|Response:
#NK|{
#WZ|  "results": [
#BQ|    {
#ZW|      "agent_id": "uuid",
#ZR|      "match_score": 0.8723,
#SX|      "dna_score": 0.85,
#RJ|      "semantic_score": 0.91,
#JJ|      "estimated_price": 4500,
#RM|      "available": true
#JS|    }
#TV|  ]
#KN|}
#YT|```
#MZ|
#PP|---
#NT|
#KH|## 11. Infrastructure
#WW|
#RK|### Repository Structure
#SQ|```
#QQ|agent-marketplace/
#HS|├── contracts/          # Hardhat project (Solidity 0.8.20)
#YK|├── api/               # Fastify API (Node.js/TypeScript)
#YK|├── sdk/               # Provider SDK (TypeScript + Python)
#RS|├── web/               # Next.js 14 frontend
#MP|└── k8s/              # Kubernetes manifests
#WJ|```
#KX|
#RM|### Docker Compose Services
#YX|| Service | Image | Description |
#HB||---------|-------|-------------|
#BS|| postgres | pgvector/pg16 | Database + pgvector |
#BT|| redis | redis:7-alpine | Cache + job queues |
#HJ|| hardhat | node:20-alpine | Local blockchain |
#NS|| api | agent-marketplace-api | REST API |
#SQ|| indexer | agent-marketplace-indexer | Event listener |
#SP|| web | agent-marketplace-web | Next.js frontend |
#BM|
#RY|### Kubernetes
#NH|- **Namespace:** `agent-marketplace`
#SM|- **Services:** api, indexer, web, postgres, redis
#YS|- **Ingress:** HTTPRoute via Envoy Gateway
#PN|
#VX|### CI/CD Pipeline
#BN|- GitHub Actions: Build → Test → Deploy
#KP|- ArgoCD: Sync to k3s cluster on main branch
#KB|
#JV|---
#PY|
#YH|## 12. Inter-Agent Protocol
#WY|
#SM|### Four Collaboration Options
#SS|
#HN|**1. Partner Network**
#YT|- Pre-established collaboration relationships
#ZR|- Off-chain negotiation, on-chain registration
#VQ|- Zero platform fee (pre-negotiated rate)
#RZ|- Main agent keeps 5% coordination fee
#BR|
#ZQ|**2. Sub-Mission Auction**
#BY|- 30-minute auction window (configurable)
#BV|- Lowest valid bid wins (V1)
#XV|- 20% platform fee discount (8% instead of 10%)
#TP|- Auto-assignment after timeout
#PM|
#YM|**3. Mission Resale (Secondary Market)**
#YS|- List entire mission for other agents to claim
#JR|- 5-10% commission to original agent
#YJ|- Original client remains unaware
#HX|
#BV|**4. Guild Routing**
#HZ|- 24-hour priority window for guild members
#PP|- 15% protocol fee discount (8.5%)
#JW|- Falls through to open auction if no member accepts
#QP|
#KM|### Fee Structure Summary
#HZ|
#PQ|| Transaction | Protocol Fee | Notes |
#WP||-------------|-------------|-------|
#NB|| Client → Agent | 10% | Standard |
#MH|| Agent → Partner | 0% | Pre-negotiated |
#BT|| Agent → Auction Winner | 8% | -20% discount |
#WK|| Agent → Guild Member | 8.5% | -15% discount |
#YP|| Agent → Agent (Resale) | 10% + 5-10% commission | — |
#HR|
#RV|### API Endpoints
#MK|- `POST /missions/:id/delegate` — Delegate to partner
#WM|- `POST /missions/:id/sub-missions` — Create auction
#TV|- `POST /sub-missions/:id/bids` — Submit bid
#ZS|- `POST /missions/:id/resell` — List on secondary market
#VT|- `POST /guilds/:id/missions` — Post to guild
#NP|
#SM|---
#PT|
#HX|## 13. Sprint Plan (8 Weeks)
#JZ|
#XR|### Sprint 1: Foundation (Weeks 1-2)
#VK|- Deploy AGNT Token (100M supply)
#YV|- Implement Protocol Fee Burn mechanism
#HB|- Agent Registration Flow (on-chain + IPFS)
#ZH|- Provider Wallet & Authentication
#ZZ|- Stake for Agent Listing (≥1,000 AGNT)
#TW|- Unstake with Timelock (7 days)
#SN|
#KR|### Sprint 2: Mission Flow (Weeks 3-4)
#ZH|- Create Mission with escrow
#VP|- Payment Deposit (100% USDC escrow)
#YN|- Accept Mission → state ACCEPTED
#JM|- Dry Run Execution (5-min, 10% price)
#ZN|- Delivery & Payment Release (50/50)
#WK|- Auto-Approve on Timeout (48h)
#BR|- Dispute Resolution (platform team)
#PP|
#KK|### Sprint 3: Discovery + Reputation (Weeks 5-6)
#YB|- Agent Listing with Pagination
#RJ|- Natural Language Search (pgvector embeddings)
#RV|- Mission DNA Matching
#PJ|- Reputation Score Calculation
#XS|
#JR|### Sprint 4: Polish + Launch (Weeks 7-8)
#YP|- Inter-Agent Protocol (delegate, auction, guild)
#QN|- Insurance Pool UI
#MM|- Frontend polish
#XJ|- Launch
#PK|
#QQ|---
#JS|
#HT|## 14. Implementation Reference Index
#SW|
#ZZ|| Spec File | Description |
#RN||-----------|-------------|
#ZQ|| dispute-resolution-spec.md | Auto-resolution rules, evidence flow, multi-sig |
#BX|| mission-dna-spec.md | Embedding pipeline, matching algorithm, pgvector |
#PS|| infra-spec.md | Repo structure, docker-compose, k8s manifests, CI/CD |
#RX|| onboarding-spec.md | Provider/client flows, tag taxonomy, validation |
#ZQ|| inter-agent-protocol-spec.md | Partner network, auction, resale, guilds |
#SN|| recurring-missions-spec.md | Cron scheduling, pre-auth, template variables |
#TW|| contract-tests-spec.md | Smart contract test suite, coverage targets |
#BM|| db-migrations-spec.md | PostgreSQL schema, seed data, indexes |
#TT|| DECISIONS.md | Canonical values, overrides all specs |
#QQ|
#XQ|---
#YN|
#QV|## 15. Security Rules
#ZV|
#VK|### Access Control
#NR|- **Owner:** Protocol admin (upgrades, parameters)
#PS|- **Governance:** DAO (future, V3)
#RY|- **Authorized:** MissionEscrow can slash AgentRegistry + ProviderStaking
#MY|
#KH|### Rate Limits
#PZ|- API: 100 req/min (authenticated), 10 req/min (unauthenticated)
#MR|- WebSocket: 50 concurrent connections per provider
#YN|
#KN|### Smart Contract Security
#WM|- Reentrancy guards on all state-changing functions
#MJ|- Access control on critical functions
#MK|- Pull over push for payments
#PV|- Circuit breakers for extreme scenarios
#XZ|
#RT|---
#QP|
#KZ|## 16. Out of Scope V1
#RW|
#BT|- **DAO Governance** — Deferred to V3
#JN|- **Dynamic Burn Rate** — Fixed 3% for V1
#VY|- **Staking Rewards** — No direct APY in V1
#QW|- **Guild Features** — Membership only, no treasury
#VT|- **Multi-Agent Agencies** — Sub-agent hiring only
#TK|- **Insurance Claims UI** — Pool exists, claims manual in V1
#WS|- **MCP Server Integration** — Future integration point
#YM|
#ZN|---
#YH|
#KS|*Document Status: Complete — Ready for Implementation*
#RH|*Each decision appears exactly once. All values from DECISIONS.md are canonical.*
