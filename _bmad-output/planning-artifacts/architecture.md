# Agent Marketplace — Technical Architecture Document

**Version:** 1.0  
**Date:** 2026-02-27  
**Status:** Ready for Implementation

---

## 1. System Architecture Diagram

### 1.1 High-Level Architecture (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    CLIENT LAYER                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                  │
│  │  Web UI (React) │    │   SDK (Node.js)  │    │  Enterprise API │                  │
│  │  - Agent Browse │    │  - Provider SDK  │    │  - REST API      │                  │
│  │  - Mission Flow │    │  - Mission Events│    │  - Webhooks      │                  │
│  │  - Dashboard    │    │  - Inter-agent  │    │  - Auth (JWT)    │                  │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘                  │
│           │                       │                       │                             │
│           └───────────────────────┼───────────────────────┘                             │
│                                   │                                                     │
│                                   ▼                                                     │
│                    ┌──────────────────────────────┐                                    │
│                    │      API Gateway (Node.js)    │                                    │
│                    │  ┌─────────────────────────┐ │                                    │
│                    │  │  Rate Limiting           │ │                                    │
│                    │  │  Authentication          │ │                                    │
│                    │  │  Request Validation      │ │                                    │
│                    │  │  WebSocket Handler       │ │                                    │
│                    │  └─────────────────────────┘ │                                    │
│                    └──────────────┬───────────────┘                                    │
│                                   │                                                     │
│           ┌───────────────────────┼───────────────────────┐                             │
│           │                       │                       │                             │
│           ▼                       ▼                       ▼                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                  │
│  │   PostgreSQL    │    │   Redis Cache    │    │      IPFS       │                  │
│  │  - Agents       │    │  - Sessions      │    │  - Metadata     │                  │
│  │  - Missions     │    │  - Real-time     │    │  - Agent Cards  │                  │
│  │  - Users        │    │  - Pub/Sub       │    │  - Artifacts    │                  │
│  │  - Audit Logs   │    │  - Rate Limits   │    │  - Outputs      │                  │
│  └─────────────────┘    └─────────────────┘    └────────┬────────┘                  │
│                                                         │                             │
└─────────────────────────────────────────────────────────┼─────────────────────────────┘
                                                          │
                    ┌─────────────────────────────────────┴─────────────────────────────┐
                    │                    BLOCKCHAIN LAYER (Base L2)                      │
                    │  ┌─────────────────────────────────────────────────────────────┐  │
                    │  │                    $AGNT Token (ERC-20)                     │  │
                    │  │  - burnOnCall() - Protocol fee burning                      │  │
                    │  │  - stake() / unstake() - Provider bonding                  │  │
                    │  │  - slash() - Dispute penalty                                │  │
                    │  └─────────────────────────────────────────────────────────────┘  │
                    │  ┌─────────────────────────────────────────────────────────────┐  │
                    │  │                  AgentRegistry.sol                           │  │
                    │  │  - registerAgent() - Create agent identity                  │  │
                    │  │  - recordMissionOutcome() - Write reputation                │  │
                    │  │  - getReputation() - Query scores                          │  │
                    │  │  - updateMetadata() - IPFS hash updates                    │  │
                    │  └─────────────────────────────────────────────────────────────┘  │
                    │  ┌─────────────────────────────────────────────────────────────┐  │
                    │  │                  MissionEscrow.sol                          │  │
                    │  │  - createMission() - Fund escrow                           │  │
                    │  │  - acceptMission() / deliverMission() / approveMission()  │  │
                    │  │  - disputeMission() - Arbitration trigger                 │  │
                    │  │  - timeoutMission() - Auto-refund                         │  │
                    │  └─────────────────────────────────────────────────────────────┘  │
                    │  ┌─────────────────────────────────────────────────────────────┐  │
                    │  │                 ProviderStaking.sol                          │  │
                    │  │  - stake() - Lock tokens as bond                           │  │
                    │  │  - requestUnstake() - Start 7-day timelock                 │  │
                    │  │  - executeUnstake() - Complete withdrawal                 │  │
                    │  │  - slash() - Penalty on dispute loss                      │  │
                    │  └─────────────────────────────────────────────────────────────┘  │
                    └───────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
                    ┌───────────────────────────────────────────────────────────────────┐
                    │                    INDEXING & ORACLES                             │
                    │  ┌─────────────────┐    ┌─────────────────┐                     │
                    │  │  The Graph       │    │  Chainlink      │                     │
                    │  │  (Subgraph)      │    │  (Price Feed)   │                     │
                    │  │  - Agent events  │    │  - USDC/AGNT    │                     │
                    │  │  - Mission events│    │    pricing      │                     │
                    │  │  - Reputation    │    │                 │                     │
                    │  └─────────────────┘    └─────────────────┘                     │
                    └───────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Interaction Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    Client    │────▶│  API Layer   │────▶│  Smart       │────▶│  Indexer     │
│  (Creates    │     │  (Validates, │     │  Contracts   │     │  (The Graph) │
│   Mission)   │     │   Routes)    │     │  (Escrow)    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                     │                     │
                            │                     │                     │
                            ▼                     ▼                     ▼
                     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
                     │  Provider    │◀────│  Agent       │◀────│  Reputation  │
                     │  SDK         │     │  Execution   │     │  Updates     │
                     │  (WebSocket) │     │  Environment │     │  (On-chain)  │
                     └──────────────┘     └──────────────┘     └──────────────┘
```

---

## 2. Smart Contract Architecture

### 2.1 Contract Overview

| Contract | Purpose | Lines (est.) |
|----------|---------|--------------|
| `AGNTToken.sol` | ERC-20 utility token with burn mechanism | ~200 |
| `AgentRegistry.sol` | Agent identity + reputation storage | ~300 |
| `MissionEscrow.sol` | Payment flow + state machine | ~400 |
| `ProviderStaking.sol` | Staking + slash mechanism | ~250 |
| `InterAgentHub.sol` | Agent-to-agent hiring | ~200 |

### 2.2 AGNTToken.sol — Full Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title IAGNTToken
 * @dev $AGNT Utility Token - Protocol fee burning, staking, and slashing
 */
interface IAGNTToken {
    // ═══════════════════════════════════════════════════════════════════
    // Events
    // ═══════════════════════════════════════════════════════════════════
    
    event Burned(address indexed from, uint256 amount, uint256 protocolFee);
    event Staked(address indexed provider, uint256 amount);
    event UnstakeRequested(address indexed provider, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed provider, uint256 amount);
    event Slashed(address indexed provider, uint256 amount, string reason);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event MinterUpdated(address indexed minter, bool allowed);

    // ═══════════════════════════════════════════════════════════════════
    // Errors
    // ═══════════════════════════════════════════════════════════════════
    
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error BurnExceedsBalance(uint256 balance, uint256 burnAmount);
    error OnlyProtocol();
    error OnlyStakingContract();
    error FeeTooHigh(uint256 max, uint256 provided);
    error FeeTooLow(uint256 min, uint256 provided);

    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    function PROTOCOL_FEE_BURN() external pure returns (uint256);      // 100 = 1%
    function MIN_PROTOCOL_FEE() external pure returns (uint256);        // 50 = 0.5%
    function MAX_PROTOCOL_FEE() external pure returns (uint256);        // 300 = 3%
    function INITIAL_SUPPLY() external pure returns (uint256);         // 100M * 1e18

    // ═══════════════════════════════════════════════════════════════════
    // View Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function getProtocolFee() external view returns (uint256);
    function getBurnAmount(uint256 amount) external view returns (uint256);
    function totalBurned() external view returns (uint256);
    function isMinter(address account) external view returns (bool);

    // ═══════════════════════════════════════════════════════════════════
    // Admin Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function setProtocolFee(uint256 newFee) external;
    function setMinter(address minter, bool allowed) external;

    // ═══════════════════════════════════════════════════════════════════
    // User Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function burn(uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}
```

### 2.3 AgentRegistry.sol — Full Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IAgentRegistry
 * @dev On-chain agent identity and reputation system
 */
interface IAgentRegistry {
    // ═══════════════════════════════════════════════════════════════════
    // Data Structures
    // ═══════════════════════════════════════════════════════════════════
    
    enum AgentStatus { INACTIVE, ACTIVE, PAUSED, SLASHED }
    enum SkillLevel { NONE, INTERMEDIATE, ADVANCED, EXPERT }

    struct Skill {
        string name;                    // e.g., "kubernetes"
        SkillLevel level;              // 0-3
        string[] frameworks;           // e.g., ["k3s", "eks", "gke"]
    }

    struct AgentCard {
        bytes32 agentId;
        address provider;
        string ipfsMetadataHash;       // IPFS hash for full metadata
        uint256 missionsCompleted;
        uint256 missionsFailed;
        uint256 reputationScore;       // 0-10000 (2 decimal precision)
        uint256 totalClientScore;      // Sum of all client ratings
        uint256 reviewCount;           // Number of reviews received
        uint256 stakedAmount;          // Provider stake
        uint256 createdAt;
        uint256 updatedAt;
        AgentStatus status;
        bool isGenesis;                // Genesis badge
    }

    struct MissionOutcome {
        bytes32 missionId;
        bool success;
        uint8 clientScore;             // 1-10
        uint256 timestamp;
        bytes32 clientAddress;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Events
    // ═══════════════════════════════════════════════════════════════════
    
    event AgentRegistered(
        bytes32 indexed agentId,
        address indexed provider,
        string ipfsHash
    );
    event AgentUpdated(bytes32 indexed agentId, string ipfsHash);
    event AgentStatusChanged(
        bytes32 indexed agentId,
        AgentStatus oldStatus,
        AgentStatus newStatus
    );
    event ReputationUpdated(
        bytes32 indexed agentId,
        uint256 oldScore,
        uint256 newScore,
        string reason
    );
    event MissionRecorded(
        bytes32 indexed agentId,
        bytes32 indexed missionId,
        bool success,
        uint8 clientScore
    );
    event StakeUpdated(bytes32 indexed agentId, uint256 newStake);

    // ═══════════════════════════════════════════════════════════════════
    // Errors
    // ═══════════════════════════════════════════════════════════════════
    
    error AgentNotFound(bytes32 agentId);
    error AgentAlreadyExists(bytes32 agentId);
    error AgentNotActive(bytes32 agentId);
    error UnauthorizedProvider(address expected, address actual);
    error InvalidIPFSHash();
    error InvalidScore(uint256 min, uint256 max, uint256 provided);
    error AgentPaused(bytes32 agentId);

    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    function MIN_STAKE_AMOUNT() external pure returns (uint256);      // 100e18
    function REPUTATION_PRECISION() external pure returns (uint256);   // 100

    // ═══════════════════════════════════════════════════════════════════
    // Core Functions
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Register a new agent on the marketplace
     * @param agentId Unique identifier (keccak256 of name + provider)
     * @param ipfsHash IPFS hash containing full metadata
     * @param initialStake Amount to stake (must be >= MIN_STAKE_AMOUNT)
     */
    function registerAgent(
        bytes32 agentId,
        string calldata ipfsHash,
        uint256 initialStake
    ) external;

    /**
     * @dev Update agent metadata (IPFS hash)
     * @param agentId Agent identifier
     * @param newIpfsHash New IPFS metadata hash
     */
    function updateMetadata(bytes32 agentId, string calldata newIpfsHash) external;

    /**
     * @dev Record mission outcome and update reputation
     * @param agentId Agent identifier
     * @param missionId Mission identifier
     * @param success Whether mission completed successfully
     * @param clientScore Client rating 1-10
     */
    function recordMissionOutcome(
        bytes32 agentId,
        bytes32 missionId,
        bool success,
        uint8 clientScore
    ) external;

    /**
     * @dev Pause agent (provider action)
     */
    function pauseAgent(bytes32 agentId) external;

    /**
     * @dev Reactivate agent
     */
    function activateAgent(bytes32 agentId) external;

    /**
     * @dev Update stake amount (called by ProviderStaking)
     */
    function updateStake(bytes32 agentId, uint256 newStake) external;

    /**
     * @dev Mark agent as genesis (admin)
     */
    function setGenesis(bytes32 agentId, bool isGenesis) external;

    // ═══════════════════════════════════════════════════════════════════
    // View Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function getAgent(bytes32 agentId) external view returns (AgentCard memory);
    function getProviderAgents(address provider) external view returns (bytes32[] memory);
    function getReputation(bytes32 agentId) external view returns (uint256);
    function getMissionHistory(
        bytes32 agentId,
        uint256 limit,
        uint256 offset
    ) external view returns (MissionOutcome[] memory);
    function isProvider(address account) external view returns (bool);
    function agentIdExists(bytes32 agentId) external view returns (bool);
}
```

### 2.4 MissionEscrow.sol — Full Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IMissionEscrow
 * @dev Escrow payment system with 50/50 milestone release
 */
interface IMissionEscrow {
    // ═══════════════════════════════════════════════════════════════════
    // Data Structures
    // ═══════════════════════════════════════════════════════════════════
    
    enum MissionState {
        NONE,
        CREATED,      // Client deposited funds
        ACCEPTED,     // Provider accepted
        IN_PROGRESS,  // Work started
        DELIVERED,    // Provider submitted deliverables
        COMPLETED,    // Client approved (final payment)
        DISPUTED,     // Client opened dispute
        REFUNDED,     // Timeout or dispute won
        CANCELLED     // Pre-acceptance cancellation
    }

    struct Mission {
        bytes32 missionId;
        bytes32 agentId;
        address client;
        address provider;
        uint256 totalAmount;      // Total mission payment
        uint256 upfrontPaid;      // 50% released on accept
        uint256 remainder;        // 50% released on approve
        uint256 deadline;         // Unix timestamp
        uint256 createdAt;
        uint256 deliveredAt;
        MissionState state;
        string deliverableHash;   // IPFS hash of output
        uint8 disputeReason;      // 0=none, 1=quality, 2=timeline, 3=other
    }

    // ═══════════════════════════════════════════════════════════════════
    // Events
    // ═══════════════════════════════════════════════════════════════════
    
    event MissionCreated(
        bytes32 indexed missionId,
        bytes32 indexed agentId,
        address indexed client,
        address provider,
        uint256 amount,
        uint256 deadline
    );
    event MissionAccepted(
        bytes32 indexed missionId,
        address indexed provider
    );
    event MissionStarted(
        bytes32 indexed missionId,
        uint256 upfrontPaid
    );
    event MissionDelivered(
        bytes32 indexed missionId,
        string deliverableHash
    );
    event MissionCompleted(
        bytes32 indexed missionId,
        uint256 totalPaid
    );
    event MissionDisputed(
        bytes32 indexed missionId,
        address indexed client,
        uint8 reason
    );
    event DisputeResolved(
        bytes32 indexed missionId,
        bool clientWins,
        uint256 providerSlash,
        uint256 refundAmount
    );
    event MissionRefunded(
        bytes32 indexed missionId,
        uint256 amount
    );
    event MissionCancelled(
        bytes32 indexed missionId,
        address indexed client
    );

    // ═══════════════════════════════════════════════════════════════════
    // Errors
    // ═══════════════════════════════════════════════════════════════════
    
    error InvalidState(MissionState current, MissionState required);
    error MissionNotFound(bytes32 missionId);
    error Unauthorized(address expected, address actual);
    error ZeroDeadline();
    error DeadlinePassed(uint256 deadline, uint256 current);
    error ZeroAmount();
    error InsufficientPayment(uint256 expected, uint256 provided);
    error NoFundsToRefund();
    error DisputeAlreadyOpen(bytes32 missionId);
    error InvalidDisputeReason(uint8 reason);
    error EscrowPaused();

    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    function UPFONT_PERCENTAGE() external pure returns (uint256);  // 5000 = 50%
    function SLASH_PERCENTAGE() external pure returns (uint256);   // 1000 = 10%
    function DISPUTE_WINDOW() external pure returns (uint256);     // 48 hours

    // ═══════════════════════════════════════════════════════════════════
    // Core Functions
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Create a new mission with escrow deposit
     * @param agentId Agent to hire
     * @param totalAmount Total payment (in $AGNT)
     * @param deadlineTs Unix timestamp for deadline
     * @param missionId Unique mission ID (keccak256 of params)
     */
    function createMission(
        bytes32 agentId,
        uint256 totalAmount,
        uint256 deadlineTs,
        bytes32 missionId
    ) external payable;

    /**
     * @dev Provider accepts the mission
     */
    function acceptMission(bytes32 missionId) external;

    /**
     * @dev Provider delivers the mission
     * @param missionId Mission identifier
     * @param deliverableHash IPFS hash of output
     */
    function deliverMission(bytes32 missionId, string calldata deliverableHash) external;

    /**
     * @dev Client approves and releases remainder payment
     */
    function approveMission(bytes32 missionId) external;

    /**
     * @dev Client opens dispute
     * @param reason Dispute category: 1=quality, 2=timeline, 3=other
     */
    function disputeMission(bytes32 missionId, uint8 reason) external;

    /**
     * @dev Resolve dispute (governance or arbiter)
     * @param clientWins True if client wins (refund), false if provider wins
     */
    function resolveDispute(bytes32 missionId, bool clientWins) external;

    /**
     * @dev Anyone can trigger refund after deadline passes
     */
    function timeoutMission(bytes32 missionId) external;

    /**
     * @dev Client cancels before provider accepts (full refund)
     */
    function cancelMission(bytes32 missionId) external;

    // ═══════════════════════════════════════════════════════════════════
    // View Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function getMission(bytes32 missionId) external view returns (Mission memory);
    function getMissionState(bytes32 missionId) external view returns (MissionState);
    function getEscrowBalance(bytes32 missionId) external view returns (uint256);
    function getProviderMissions(address provider) external view returns (bytes32[] memory);
    function getClientMissions(address client) external view returns (bytes32[] memory);
}
```

### 2.5 ProviderStaking.sol — Full Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IProviderStaking
 * @dev Provider staking with slash mechanism for accountability
 */
interface IProviderStaking {
    // ═══════════════════════════════════════════════════════════════════
    // Data Structures
    // ═══════════════════════════════════════════════════════════════════
    
    struct StakeInfo {
        uint256 totalStaked;
        uint256 available;
        uint256 locked;          // In timelock
        uint256 unlockTime;      // When locked funds become available
        uint256 lastUpdated;
    }

    struct SlashRecord {
        address provider;
        uint256 amount;
        uint256 timestamp;
        bytes32 missionId;
        string reason;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Events
    // ═══════════════════════════════════════════════════════════════════
    
    event Staked(
        address indexed provider,
        bytes32 indexed agentId,
        uint256 amount,
        uint256 totalStake
    );
    event UnstakeRequested(
        address indexed provider,
        bytes32 indexed agentId,
        uint256 amount,
        uint256 unlockTime
    );
    event UnstakeCompleted(
        address indexed provider,
        bytes32 indexed agentId,
        uint256 amount
    );
    event UnstakeCancelled(
        address indexed provider,
        bytes32 indexed agentId
    );
    event Slashed(
        address indexed provider,
        bytes32 indexed agentId,
        uint256 amount,
        bytes32 missionId,
        string reason
    );
    event RewardDistributed(
        address indexed provider,
        uint256 reward,
        string source
    );

    // ═══════════════════════════════════════════════════════════════════
    // Errors
    // ═══════════════════════════════════════════════════════════════════
    
    error ZeroAmount();
    error InsufficientStake(uint256 available, uint256 required);
    error StakeLocked(uint256 unlockTime, uint256 currentTime);
    error UnlockTimeNotReached(uint256 unlockTime, uint256 currentTime);
    error NothingToUnstake();
    error AgentNotRegistered(bytes32 agentId);
    error CallerNotAgentProvider(address expected, address actual);
    error SlashTooHigh(uint256 max, uint256 attempted);
    error TreasuryZero();

    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    function MIN_STAKE_PER_AGENT() external pure returns (uint256);   // 100e18
    function UNSTAKE_TIMELOCK() external pure returns (uint256);      // 7 days
    function SLASH_MAX_PERCENTAGE() external pure returns (uint256);  // 1000 = 10%
    function STAKING_YIELD_APY() external pure returns (uint256);     // 500 = 5%

    // ═══════════════════════════════════════════════════════════════════
    // Core Functions
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Stake tokens for an agent
     * @param agentId Agent to stake for
     * @param amount Amount to stake
     */
    function stake(bytes32 agentId, uint256 amount) external;

    /**
     * @dev Request unstake - starts 7 day timelock
     * @param agentId Agent to unstake from
     * @param amount Amount to unstake
     */
    function requestUnstake(bytes32 agentId, uint256 amount) external;

    /**
     * @dev Execute unstake after timelock
     * @param agentId Agent to complete unstake for
     */
    function executeUnstake(bytes32 agentId) external;

    /**
     * @dev Cancel pending unstake (restakes funds)
     */
    function cancelUnstake(bytes32 agentId) external;

    /**
     * @dev Slash provider (called by MissionEscrow on dispute loss)
     * @param provider Provider address to slash
     * @param agentId Agent involved
     * @param missionId Mission that triggered slash
     * @param percentage Slash percentage (0-1000 = 0-10%)
     */
    function slash(
        address provider,
        bytes32 agentId,
        bytes32 missionId,
        uint256 percentage,
        string calldata reason
    ) external;

    /**
     * @dev Distribute staking rewards (from treasury)
     */
    function distributeReward(address provider, uint256 amount) external;

    // ═══════════════════════════════════════════════════════════════════
    // View Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function getStakeInfo(address provider, bytes32 agentId) 
        external view returns (StakeInfo memory);
    function getTotalStake(address provider) external view returns (uint256);
    function getPendingUnstake(address provider, bytes32 agentId) 
        external view returns (uint256 amount, uint256 unlockTime);
    function getSlashHistory(address provider, uint256 limit) 
        external view returns (SlashRecord[] memory);
    function calculateYield(address provider) external view returns (uint256);
}
```

### 2.6 InterAgentHub.sol — Full Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IInterAgentHub
 * @dev Agent-to-agent hiring with platform discounts
 */
interface IInterAgentHub {
    // ═══════════════════════════════════════════════════════════════════
    // Data Structures
    // ═══════════════════════════════════════════════════════════════════
    
    struct Partner {
        address agentId;          // Partner agent address
        uint256 discountPercent;  // Pre-negotiated discount (0-100)
        uint256 revenueShare;     // Original agent's cut (0-100)
        bool active;
    }

    struct SubMission {
        bytes32 parentMissionId;
        bytes32 subAgentId;
        uint256 budget;
        string requirements;      // IPFS hash
        bool completed;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Events
    // ═══════════════════════════════════════════════════════════════════
    
    event PartnerAdded(
        bytes32 indexed agentId,
        address indexed partner,
        uint256 discount
    );
    event PartnerRemoved(bytes32 indexed agentId, address indexed partner);
    event SubMissionCreated(
        bytes32 indexed parentMissionId,
        bytes32 indexed subMissionId,
        bytes32 subAgentId
    );
    event SubMissionCompleted(
        bytes32 indexed subMissionId,
        uint256 payment
    );
    event InterAgentDiscountApplied(
        bytes32 indexed missionId,
        uint256 originalFee,
        uint256 discountAmount,
        uint256 finalFee
    );

    // ═══════════════════════════════════════════════════════════════════
    // Errors
    // ═══════════════════════════════════════════════════════════════════
    
    error PartnerAlreadyExists();
    error PartnerNotFound();
    error NotAgentProvider();
    error SubMissionNotFound();
    error SubMissionNotComplete();
    error DiscountTooHigh(uint256 max, uint256 provided);

    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    function INTER_AGENT_DISCOUNT() external pure returns (uint256);   // 2000 = 20%

    // ═══════════════════════════════════════════════════════════════════
    // Core Functions
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Add a partner agent to network
     */
    function addPartner(
        bytes32 agentId,
        address partner,
        uint256 discountPercent,
        uint256 revenueShare
    ) external;

    /**
     * @dev Remove a partner
     */
    function removePartner(bytes32 agentId, address partner) external;

    /**
     * @dev Hire a sub-agent (with discount)
     * @param parentMissionId Original mission
     * @param subAgentId Agent to hire
     * @param budget Available budget
     * @param requirementsHash IPFS hash of requirements
     */
    function hireSubAgent(
        bytes32 parentMissionId,
        bytes32 subAgentId,
        uint256 budget,
        string calldata requirementsHash
    ) external payable returns (bytes32 subMissionId);

    /**
     * @dev Complete sub-mission and release payment
     */
    function completeSubMission(bytes32 subMissionId) external;

    // ═══════════════════════════════════════════════════════════════════
    // View Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function getPartners(bytes32 agentId) external view returns (Partner[] memory);
    function isPartner(bytes32 agentId, address potentialPartner) external view returns (bool);
    function getSubMission(bytes32 subMissionId) external view returns (SubMission memory);
    function calculateDiscount(bytes32 agentId, uint256 amount) 
        external view returns (uint256 discount, uint256 finalAmount);
}
```

---

## 3. Data Model

### 3.1 PostgreSQL Schema

```sql
-- ============================================================================
-- Agent Marketplace Database Schema (PostgreSQL)
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE agent_status AS ENUM (
    'inactive', 
    'active', 
    'paused', 
    'slashed'
);

CREATE TYPE mission_state AS ENUM (
    'none',
    'created', 
    'accepted', 
    'in_progress', 
    'delivered', 
    'completed', 
    'disputed', 
    'refunded', 
    'cancelled'
);

CREATE TYPE skill_level AS ENUM (
    'none', 
    'intermediate', 
    'advanced', 
    'expert'
);

CREATE TYPE dispute_reason AS ENUM (
    'none', 
    'quality', 
    'timeline', 
    'other'
);

-- ============================================================================
-- TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- Users / Providers / Clients
-- --------------------------------------------------------------------------

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address         VARCHAR(66) NOT NULL UNIQUE,  -- Ethereum address (0x...)
    address_type    VARCHAR(10) DEFAULT 'EOA',    -- EOA, Contract, TEE
    is_provider     BOOLEAN DEFAULT FALSE,
    is_client      BOOLEAN DEFAULT FALSE,
    is_enterprise  BOOLEAN DEFAULT FALSE,
    enterprise_id  UUID REFERENCES enterprises(id),
    api_key         VARCHAR(64) UNIQUE,           -- For provider API auth
    api_key_hash    BYTEA,                        -- SHA256 hash
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_address CHECK (address ~ '^0x[a-fA-F0-9]{40}$')
);

CREATE INDEX idx_users_address ON users(address);
CREATE INDEX idx_users_provider ON users(is_provider) WHERE is_provider = TRUE;

CREATE TABLE enterprises (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                VARCHAR(255) NOT NULL,
    admin_email         VARCHAR(255) NOT NULL,
    webhook_url         VARCHAR(500),
    webhook_secret      VARCHAR(64),
    rate_limit_monthly  INTEGER DEFAULT 10000,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- Agents
-- --------------------------------------------------------------------------

CREATE TABLE agents (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            VARCHAR(66) NOT NULL UNIQUE,  -- bytes32 on-chain ID
    provider_id         UUID NOT NULL REFERENCES users(id),
    chain_agent_id      BYTEA NOT NULL,                -- bytes32 from contract
    
    -- On-chain sync
    on_chain_address    VARCHAR(42),
    ipfs_metadata_hash  VARCHAR(64),
    
    -- Status
    status              agent_status DEFAULT 'inactive',
    is_genesis          BOOLEAN DEFAULT FALSE,
    visibility          VARCHAR(20) DEFAULT 'public',   -- public, private, unlisted
    
    -- Computed (synced from chain)
    missions_completed  INTEGER DEFAULT 0,
    missions_failed     INTEGER DEFAULT 0,
    reputation_score    DECIMAL(5,2) DEFAULT 0,
    total_client_score  INTEGER DEFAULT 0,
    review_count        INTEGER DEFAULT 0,
    staked_amount       DECIMAL(36,0) DEFAULT 0,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    last_mission_at     TIMESTAMPTZ,
    
    CONSTRAINT valid_agent_id CHECK (agent_id ~ '^0x[a-fA-F0-9]{64}$')
);

CREATE INDEX idx_agents_provider ON agents(provider_id);
CREATE INDEX idx_agents_status ON agents(status);
CREATE INDEX idx_agents_reputation ON agents(reputation_score DESC);

-- --------------------------------------------------------------------------
-- Agent Skills
-- --------------------------------------------------------------------------

CREATE TABLE agent_skills (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    skill_name      VARCHAR(100) NOT NULL,
    level           skill_level DEFAULT 'intermediate',
    frameworks      TEXT[],                             -- Array of strings
    years_exp       INTEGER,
    verified        BOOLEAN DEFAULT FALSE,             -- Verified via credential
    
    UNIQUE(agent_id, skill_name)
);

CREATE INDEX idx_skills_agent ON agent_skills(agent_id);
CREATE INDEX idx_skills_name ON agent_skills(skill_name);

-- GIN index for array search
CREATE INDEX idx_skills_frameworks_gin ON agent_skills USING GIN(frameworks);

-- --------------------------------------------------------------------------
-- Agent Tools & Environment
-- --------------------------------------------------------------------------

CREATE TABLE agent_tools (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    tool_name   VARCHAR(100) NOT NULL,
    tool_type   VARCHAR(50),                         -- cli, api, library, mcp
    version     VARCHAR(50),
    
    UNIQUE(agent_id, tool_name)
);

CREATE TABLE agent_environment (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    runtime         VARCHAR(100),                    -- node:22, python:3.11, etc.
    ram_required    VARCHAR(20),                      -- 4GB, 8GB
    cpu_required    VARCHAR(20),                      -- 2 cores, 4 cores
    gpu_required    BOOLEAN DEFAULT FALSE,
    gpu_spec        VARCHAR(50),                      -- A100, H100, etc.
    
    UNIQUE(agent_id)
);

-- --------------------------------------------------------------------------
-- Agent Pricing
-- --------------------------------------------------------------------------

CREATE TABLE agent_pricing (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    
    -- Pricing in $AGNT
    per_call            DECIMAL(36,0),                -- Per API call
    per_mission_base    DECIMAL(36,0),                -- Base mission price
    per_mission_min     DECIMAL(36,0),                -- Minimum mission price
    per_mission_max     DECIMAL(36,0),                -- Maximum (for estimation)
    
    -- USDC pricing (enterprise)
    per_call_usdc       DECIMAL(18,2),
    per_mission_usdc    DECIMAL(18,2),
    
    -- SLA
    sla_deadline        VARCHAR(20) DEFAULT 'flexible',  -- <2h, <24h, flexible
    avg_response_time   INTEGER,                      -- seconds
    
    -- Dry run
    dry_run_enabled     BOOLEAN DEFAULT TRUE,
    dry_run_price       DECIMAL(36,0) DEFAULT 1,       -- $1 in AGNT
    
    currency            VARCHAR(10) DEFAULT 'AGNT',
    effective_from     TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(agent_id, effective_from)
);

-- --------------------------------------------------------------------------
-- Missions
-- --------------------------------------------------------------------------

CREATE TABLE missions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id          VARCHAR(66) NOT NULL UNIQUE,  -- bytes32 on-chain
    chain_mission_id    BYTEA,                        -- bytes32 from contract
    
    -- Relationships
    agent_id            UUID NOT NULL REFERENCES agents(id),
    client_id           UUID NOT NULL REFERENCES users(id),
    provider_id         UUID REFERENCES users(id),
    
    -- Mission details
    title               VARCHAR(255),
    description         TEXT,
    requirements_hash   VARCHAR(64),                  -- IPFS hash
    deliverable_hash    VARCHAR(64),                   -- IPFS hash of output
    
    -- State (synced from chain)
    state               mission_state DEFAULT 'none',
    state_updated_at    TIMESTAMPTZ,
    
    -- Financial
    total_amount        DECIMAL(36,0) NOT NULL,
    upfront_paid        DECIMAL(36,0) DEFAULT 0,
    remainder_paid      DECIMAL(36,0) DEFAULT 0,
    protocol_fee        DECIMAL(36,0) DEFAULT 0,
    burned_amount       DECIMAL(36,0) DEFAULT 0,
    currency            VARCHAR(10) DEFAULT 'AGNT',
    
    -- Timeline
    deadline            TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    accepted_at         TIMESTAMPTZ,
    started_at          TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    disputed_at         TIMESTAMPTZ,
    resolved_at         TIMESTAMPTZ,
    
    -- Quality
    client_score        INTEGER,                       -- 1-10
    dispute_reason      dispute_reason,
    dispute_resolution  VARCHAR(20),                  -- client_wins, provider_wins
    
    -- Inter-agent
    parent_mission_id   UUID REFERENCES missions(id),
    is_sub_mission      BOOLEAN DEFAULT FALSE,
    coordinator_fee     DECIMAL(36,0),
    
    CONSTRAINT valid_mission_id CHECK (mission_id ~ '^0x[a-fA-F0-9]{64}$')
);

CREATE INDEX idx_missions_agent ON missions(agent_id);
CREATE INDEX idx_missions_client ON missions(client_id);
CREATE INDEX idx_missions_provider ON missions(provider_id);
CREATE INDEX idx_missions_state ON missions(state);
CREATE INDEX idx_missions_created ON missions(created_at DESC);

-- --------------------------------------------------------------------------
-- Mission Artifacts
-- --------------------------------------------------------------------------

CREATE TABLE mission_artifacts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id      UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    artifact_name   VARCHAR(255) NOT NULL,
    artifact_hash   VARCHAR(64) NOT NULL,              -- IPFS hash
    artifact_type   VARCHAR(50),                        -- code, document, image, data
    file_size       BIGINT,
    mime_type       VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- Reputation History
-- --------------------------------------------------------------------------

CREATE TABLE reputation_history (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agents(id),
    mission_id          UUID REFERENCES missions(id),
    
    -- Before/After scores
    score_before        DECIMAL(5,2),
    score_after         DECIMAL(5,2),
    
    -- Factors that contributed
    success_change       DECIMAL(5,2),
    client_score_change  DECIMAL(5,2),
    stake_change         DECIMAL(5,2),
    recency_change       DECIMAL(5,2),
    
    -- Metadata
    reason               VARCHAR(100),
    recorded_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reputation_agent ON reputation_history(agent_id);
CREATE INDEX idx_reputation_mission ON reputation_history(mission_id);

-- --------------------------------------------------------------------------
-- Partner Networks
-- --------------------------------------------------------------------------

CREATE TABLE agent_partners (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agents(id),
    partner_agent_id    UUID NOT NULL REFERENCES agents(id),
    
    discount_percent    INTEGER DEFAULT 0,
    revenue_share       INTEGER DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(agent_id, partner_agent_id)
);

CREATE INDEX idx_partners_agent ON agent_partners(agent_id);

-- --------------------------------------------------------------------------
-- Dry Runs
-- --------------------------------------------------------------------------

CREATE TABLE dry_runs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id      UUID REFERENCES missions(id),
    agent_id        UUID NOT NULL REFERENCES agents(id),
    client_id       UUID NOT NULL REFERENCES users(id),
    
    -- Dry run input
    input_hash      VARCHAR(64),
    input_preview   TEXT,
    
    -- Dry run output
    output_hash     VARCHAR(64),
    output_preview  TEXT,
    quality_score   INTEGER,
    
    -- Financial
    amount_paid     DECIMAL(36,0),
    status          VARCHAR(20) DEFAULT 'pending',     -- pending, completed, failed
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

-- --------------------------------------------------------------------------
-- Staking History
-- --------------------------------------------------------------------------

CREATE TABLE staking_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id     UUID NOT NULL REFERENCES users(id),
    agent_id        UUID REFERENCES agents(id),
    
    action          VARCHAR(20) NOT NULL,              -- stake, unstake_request, unstake, slash
    amount          DECIMAL(36,0) NOT NULL,
    balance_before  DECIMAL(36,0),
    balance_after   DECIMAL(36,0),
    
    tx_hash         VARCHAR(66),
    unlock_time     TIMESTAMPTZ,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_staking_provider ON staking_history(provider_id);
CREATE INDEX idx_staking_agent ON staking_history(agent_id);

-- --------------------------------------------------------------------------
-- Audit Log
-- --------------------------------------------------------------------------

CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    entity_type     VARCHAR(50) NOT NULL,             -- mission, agent, user, etc.
    entity_id       UUID NOT NULL,
    
    action          VARCHAR(50) NOT NULL,             -- created, updated, etc.
    actor_type      VARCHAR(20),                      -- user, contract, system
    actor_id        UUID,
    actor_address   VARCHAR(42),
    
    changes         JSONB,
    metadata        JSONB,
    
    tx_hash         VARCHAR(66),
    block_number    BIGINT,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_actor ON audit_log(actor_type, actor_id);
CREATE INDEX idx_audit_created ON audit_log(created_at DESC);

-- --------------------------------------------------------------------------
-- API Rate Limiting
-- --------------------------------------------------------------------------

CREATE TABLE rate_limits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    api_key         VARCHAR(64) NOT NULL,
    endpoint        VARCHAR(100) NOT NULL,
    
    requests_count  INTEGER DEFAULT 0,
    window_start    TIMESTAMPTZ NOT NULL,
    window_duration INTEGER DEFAULT 3600,              -- seconds
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(api_key, endpoint, window_start)
);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for agents
CREATE TRIGGER agents_updated_at
    BEFORE UPDATE ON agents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Trigger for users
CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Trigger for missions
CREATE TRIGGER missions_updated_at
    BEFORE UPDATE ON missions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Agent with full details
CREATE OR REPLACE VIEW v_agent_details AS
SELECT 
    a.*,
    u.address as provider_address,
    u.email as provider_email,
    json_agg(json_build_object(
        'name', s.skill_name,
        'level', s.level,
        'frameworks', s.frameworks
    )) FILTER (WHERE s.id IS NOT NULL) as skills,
    json_agg(json_build_object(
        'name', t.tool_name,
        'type', t.tool_type
    )) FILTER (WHERE t.id IS NOT NULL) as tools,
    p.per_call,
    p.per_mission_base,
    p.sla_deadline,
    p.avg_response_time
FROM agents a
JOIN users u ON a.provider_id = u.id
LEFT JOIN agent_skills s ON a.id = s.agent_id
LEFT JOIN agent_tools t ON a.id = t.agent_id
LEFT JOIN agent_pricing p ON a.id = p.agent_id AND p.effective_from <= NOW()
GROUP BY a.id, u.address, u.email, p.per_call, p.per_mission_base, p.sla_deadline, p.avg_response_time;

-- Mission with agent details
CREATE OR REPLACE VIEW v_mission_details AS
SELECT 
    m.*,
    ag.name as agent_name,
    ag.agent_id as chain_agent_id,
    c.address as client_address,
    p.address as provider_address
FROM missions m
JOIN agents ag ON m.agent_id = ag.id
JOIN users c ON m.client_id = c.id
LEFT JOIN users p ON m.provider_id = p.id;
```

### 3.2 On-Chain Data Structures Summary

```solidity
// Summary of on-chain storage layout

// AgentRegistry
mapping(bytes32 => AgentCard) public agents;              // agentId -> AgentCard
mapping(address => bytes32[]) public providerAgents;       // provider -> agentIds
mapping(bytes32 => MissionOutcome[]) public missionHistory; // agentId -> outcomes

// MissionEscrow
mapping(bytes32 => Mission) public missions;              // missionId -> Mission
mapping(address => bytes32[]) public providerMissions;    // provider -> missions
mapping(address => bytes32[]) public clientMissions;      // client -> missions

// ProviderStaking
mapping(address => mapping(bytes32 => StakeInfo)) public stakes; // provider -> agentId -> StakeInfo
mapping(address => SlashRecord[]) public slashHistory;   // provider -> slashes

// InterAgentHub
mapping(bytes32 => Partner[]) public partnerNetworks;     // agentId -> partners
mapping(bytes32 => SubMission) public subMissions;      // subMissionId -> SubMission
```

---

## 4. API Design

### 4.1 OpenAPI-Style Endpoints

#### 4.1.1 Authentication

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  AUTHENTICATION METHODS                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  Provider API Key:  Header: X-API-Key: ak_prod_xxxx                         │
│  Client JWT:        Header: Authorization: Bearer <jwt>                     │
│  Enterprise:        Header: X-Enterprise-ID + X-API-Key                     │
│  Web3:              Header: X-Signature: <eth_sign> + X-Address: <addr>     │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1.2 Agent Registry API

```yaml
# GET /api/v1/agents
# List agents with filtering and pagination
parameters:
  - name: status
    in: query
    schema:
      type: string
      enum: [active, paused, inactive]
  - name: skills
    in: query
    schema:
      type: array
      items:
        type: string
  - name: min_reputation
    in: query
    schema:
      type: integer
      minimum: 0
      maximum: 100
  - name: max_price
    in: query
    schema:
      type: integer
  - name: sla
    in: query
    schema:
      type: string
      enum: [<2h, <24h, flexible]
  - name: search
    in: query
    description: Natural language search (embedding-based)
    schema:
      type: string
  - name: page
    in: query
    schema:
      type: integer
      default: 1
  - name: limit
    in: query
    schema:
      type: integer
      default: 20
      maximum: 100

responses:
  200:
    description: Paginated agent list
    content:
      application/json:
        schema:
          type: object
          properties:
            agents:
              type: array
              items:
                $ref: '#/components/schemas/AgentCard'
            pagination:
              $ref: '#/components/schemas/Pagination'

# GET /api/v1/agents/{agentId}
# Get full agent details
responses:
  200:
    description: Agent card with all details
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/AgentFull'

# POST /api/v1/agents
# Register new agent
security:
  - ApiKeyAuth: []
  - JWTAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - name
          - skills
          - pricing
        properties:
          name:
            type: string
            maxLength: 100
          version:
            type: string
          description:
            type: string
            maxLength: 280
          skills:
            type: array
            items:
              $ref: '#/components/schemas/Skill'
          tools:
            type: array
            items:
              type: string
          environment:
            $ref: '#/components/schemas/Environment'
          pricing:
            $ref: '#/components/schemas/Pricing'
          tags:
            type: array
            items:
              type: string
          sla_deadline:
            type: string
            enum: [<2h, <24h, flexible]

responses:
  201:
    description: Agent registered
  400:
    description: Validation error
  409:
    description: Agent name already taken

# PUT /api/v1/agents/{agentId}
# Update agent metadata
security:
  - ApiKeyAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        properties:
          description:
            type: string
          skills:
            type: array
            items:
              $ref: '#/components/schemas/Skill'
          pricing:
            $ref: '#/components/schemas/Pricing'

# GET /api/v1/agents/{agentId}/reputation
# Get reputation details and history
responses:
  200:
    description: Reputation data
    content:
      application/json:
        schema:
          type: object
          properties:
            score:
              type: integer
            breakdown:
              type: object
              properties:
                success_rate:
                  type: number
                client_scores:
                  type: number
                stake_weight:
                  type: number
                recency:
                  type: number
            history:
              type: array
              items:
                $ref: '#/components/schemas/MissionOutcome'
```

#### 4.1.3 Mission API

```yaml
# POST /api/v1/missions
# Create new mission (client)
security:
  - JWTAuth: []
  - Web3Auth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - agent_id
          - description
          - budget
          - deadline
        properties:
          agent_id:
            type: string
            format: uuid
          description:
            type: string
            maxLength: 10000
          requirements:
            type: string
            format: uri
            description: IPFS hash of detailed requirements
          budget:
            type: integer
            minimum: 1
          deadline:
            type: string
            format: date-time
          priority:
            type: string
            enum: [normal, high, urgent]
          dry_run:
            type: boolean
            default: false

responses:
  201:
    description: Mission created, escrow funded
    headers:
      X-Mission-ID:
        schema:
          type: string
          format: uuid
    content:
      application/json:
        schema:
          type: object
          properties:
            mission:
              $ref: '#/components/schemas/Mission'
            escrow:
              type: object
              properties:
                total_amount:
                  type: integer
                upfront:
                  type: integer
                remainder:
                  type: integer
            tx_hash:
              type: string

# GET /api/v1/missions/{missionId}
# Get mission status and details

# POST /api/v1/missions/{missionId}/accept
# Provider accepts mission
security:
  - ApiKeyAuth: []

# POST /api/v1/missions/{missionId}/deliver
# Provider delivers output
security:
  - ApiKeyAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - deliverable_hash
        properties:
          deliverable_hash:
            type: string
          artifacts:
            type: array
            items:
              type: object
              properties:
                name:
                  type: string
                hash:
                  type: string

# POST /api/v1/missions/{missionId}/approve
# Client approves and releases remainder

# POST /api/v1/missions/{missionId}/dispute
# Client opens dispute
security:
  - JWTAuth: []
  - Web3Auth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - reason
        properties:
          reason:
            type: string
            enum: [quality, timeline, other]
          description:
            type: string
          evidence:
            type: array
            items:
              type: string
              format: uri

# GET /api/v1/missions
# List missions (filtered by role)
security:
  - JWTAuth: []
  - ApiKeyAuth: []

parameters:
  - name: role
    in: query
    schema:
      type: string
      enum: [client, provider]
  - name: state
    in: query
    schema:
      type: string
      enum: [created, accepted, in_progress, delivered, completed, disputed, refunded]
```

#### 4.1.4 Provider/Staking API

```yaml
# GET /api/v1/provider/profile
# Get provider profile and stats
security:
  - ApiKeyAuth: []

# GET /api/v1/provider/agents
# List provider's agents
security:
  - ApiKeyAuth: []

# POST /api/v1/provider/stake
# Stake tokens for agent
security:
  - ApiKeyAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - agent_id
          - amount
        properties:
          agent_id:
            type: string
            format: uuid
          amount:
            type: integer
            minimum: 100

# POST /api/v1/provider/unstake
# Request unstake (starts timelock)
security:
  - ApiKeyAuth: []

# GET /api/v1/provider/stake/{agentId}
# Get stake info for agent

# GET /api/v1/provider/earnings
# Get provider earnings history
security:
  - ApiKeyAuth: []
```

#### 4.1.5 Inter-Agent API

```yaml
# POST /api/v1/agents/{agentId}/hire
# Agent hires sub-agent
security:
  - ApiKeyAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - sub_agent_id
          - mission
          - budget
        properties:
          sub_agent_id:
            type: string
            format: uuid
          mission:
            type: string
          budget:
            type: integer
          parent_mission_id:
            type: string
            format: uuid

responses:
  201:
    description: Sub-mission created with discount applied

# GET /api/v1/agents/{agentId}/network
# Get partner network

# POST /api/v1/agents/{agentId}/partners
# Add partner to network
security:
  - ApiKeyAuth: []
```

#### 4.1.6 Enterprise API

```yaml
# POST /api/v1/enterprise/webhooks
# Register webhook for mission events
security:
  - EnterpriseAuth: []

requestBody:
  content:
    application/json:
      schema:
        type: object
        required:
          - url
          - events
        properties:
          url:
            type: string
            format: uri
          events:
            type: array
            items:
              type: string
              enum: [mission.created, mission.completed, mission.disputed, mission.delivered]
          secret:
            type: string

# GET /api/v1/enterprise/audit
# Get audit trail
security:
  - EnterpriseAuth: []

# POST /api/v1/enterprise/bulk
# Bulk mission creation
security:
  - EnterpriseAuth: []
```

### 4.2 WebSocket Events

```typescript
// WebSocket: wss://api.agentmarketplace.io/ws

interface WSMessage {
  type: 'mission' | 'agent' | 'system';
  event: string;
  payload: any;
  timestamp: number;
}

// Mission Events
{
  "type": "mission",
  "event": "mission.created",
  "payload": {
    "missionId": "0x...",
    "agentId": "0x...",
    "client": "0x...",
    "budget": 100
  },
  "timestamp": 1709000000
}

{
  "type": "mission",
  "event": "mission.accepted",
  "payload": { "missionId": "0x...", "provider": "0x..." }
}

{
  "type": "mission",
  "event": "mission.delivered",
  "payload": { 
    "missionId": "0x...",
    "deliverableHash": "Qm..."
  }
}

{
  "type": "mission",
  "event": "mission.completed",
  "payload": { 
    "missionId": "0x...",
    "clientScore": 9,
    "totalPaid": 100
  }
}

{
  "type": "mission",
  "event": "mission.disputed",
  "payload": { 
    "missionId": "0x...",
    "reason": "quality",
    "evidence": ["Qm..."]
  }
}

// Agent Events
{
  "type": "agent",
  "event": "agent.registered",
  "payload": { "agentId": "0x...", "provider": "0x..." }
}

{
  "type": "agent",
  "event": "reputation.updated",
  "payload": { 
    "agentId": "0x...",
    "oldScore": 75,
    "newScore": 78
  }
}
```

---

## 5. Mission State Machine

### 5.1 State Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MISSION STATE MACHINE                              │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────┐
                              │  NONE    │
                              │ (init)   │
                              └────┬─────┘
                                   │ createMission()
                                   ▼
                         ┌────────────────┐
                         │    CREATED     │◄────────────────────────┐
                         │ (escrow funded)│                         │
                         └───────┬────────┘                         │
                                 │                                  │
                    ┌────────────┼────────────┐                     │
                    │            │            │                     │
                    ▼            ▼            ▼                     │
           ┌────────────┐ ┌───────────┐ ┌───────────┐               │
           │ cancel     │ │ timeout   │ │accept     │               │
           │Mission()   │ │Mission()  │ │Mission()  │               │
           └─────┬──────┘ └─────┬─────┘ └─────┬─────┘               │
                 │              │             │                      │
                 ▼              ▼             ▼                      │
         ┌────────────┐ ┌───────────┐ ┌────────────────┐            │
         │ CANCELLED  │ │ REFUNDED  │ │   ACCEPTED     │            │
         └────────────┘ └───────────┘ └───────┬────────┘            │
                                              │                       │
                                              │ startWork()          │
                                              │ (automatic)          │
                                              ▼                       │
                                    ┌──────────────────┐             │
                                    │   IN_PROGRESS    │             │
                                    │   (working...)   │             │
                                    └────────┬─────────┘             │
                                             │                       │
                                    ┌────────┴────────┐              │
                                    │                 │              │
                                    ▼                 ▼              │
                            deliverMission()   timeoutMission()       │
                                    │                 │              │
                                    ▼                 ▼              │
                          ┌────────────────┐  ┌───────────┐         │
                          │   DELIVERED    │  │  REFUNDED │         │
                          │ (output ready) │  │ (expired) │         │
                          └────────┬───────┘  └───────────┘         │
                                   │                                 │
                          ┌────────┴────────┐                        │
                          │                 │                        │
                          ▼                 ▼                        │
                 approveMission()    disputeMission()                │
                          │                 │                        │
                          ▼                 ▼                        │
                 ┌──────────────┐    ┌────────────┐                  │
                 │   COMPLETED  │    │  DISPUTED  │                  │
                 │ (full paid)  │    │            │                  │
                 └──────────────┘    └─────┬──────┘                  │
                                           │                          │
                              ┌────────────┼────────────┐             │
                              │            │            │             │
                              ▼            ▼            ▼             │
                    resolveDispute()                    │             │
                    (client wins)                        │             │
                              │                         │             │
                              ▼                         ▼             │
                    ┌──────────────┐         ┌──────────────────┐   │
                    │   REFUNDED   │         │  ACCEPTED*       │───┘
                    │(partial/full)│         │ (provider wins)  │
                    └──────────────┘         └──────────────────┘
                    
                     * = remainder released, provider keeps upfront
```

### 5.2 State Definitions

| State | Description | Entry Action | Exit Actions |
|-------|-------------|--------------|--------------|
| `NONE` | Initial state | - | createMission() |
| `CREATED` | Mission created, escrow funded | Lock funds in contract | acceptMission(), cancelMission(), timeoutMission() |
| `ACCEPTED` | Provider accepted | Release 50% upfront | startWork() (automatic) |
| `IN_PROGRESS` | Provider working | - | deliverMission(), timeoutMission() |
| `DELIVERED` | Output submitted | - | approveMission(), disputeMission() |
| `COMPLETED` | Client approved | Release 50% remainder | - |
| `DISPUTED` | Client opened dispute | Pause payment | resolveDispute() |
| `REFUNDED` | Funds returned | Return to client | - |
| `CANCELLED` | Pre-acceptance cancel | Full refund | - |

### 5.3 Smart Contract Triggers

```solidity
// MissionEscrow.sol - State transitions trigger these internal functions

// CREATED -> ACCEPTED
function _acceptMission(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Release 50% upfront to provider
    uint256 upfront = (mission.totalAmount * UPFONT_PERCENTAGE) / 10000;
    mission.upfrontPaid = upfront;
    mission.remainder = mission.totalAmount - upfront;
    
    // Transfer to provider
    token.transfer(mission.provider, upfront);
    
    // Update state
    mission.state = MissionState.ACCEPTED;
    mission.acceptedAt = block.timestamp;
    
    emit MissionAccepted(missionId, mission.provider);
    emit MissionStarted(missionId, upfront);
}

// ACCEPTED -> IN_PROGRESS (automatic on acceptance)
function _startWork(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    mission.state = MissionState.IN_PROGRESS;
    mission.startedAt = block.timestamp;
    
    emit MissionStarted(missionId, mission.upfrontPaid);
}

// IN_PROGRESS -> DELIVERED
function _deliverMission(bytes32 missionId, string calldata deliverableHash) internal {
    Mission storage mission = missions[missionId];
    mission.state = MissionState.DELIVERED;
    mission.deliverableHash = deliverableHash;
    mission.deliveredAt = block.timestamp;
    
    emit MissionDelivered(missionId, deliverableHash);
}

// DELIVERED -> COMPLETED
function _approveMission(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Release remainder to provider
    token.transfer(mission.provider, mission.remainder);
    
    uint256 totalPaid = mission.upfrontPaid + mission.remainder;
    mission.state = MissionState.COMPLETED;
    mission.completedAt = block.timestamp;
    
    // Record reputation
    IAgentRegistry(registry).recordMissionOutcome(
        mission.agentId,
        missionId,
        true,
        10  // Default max score for auto-approval
    );
    
    emit MissionCompleted(missionId, totalPaid);
}

// DELIVERED -> DISPUTED
function _disputeMission(bytes32 missionId, uint8 reason) internal {
    Mission storage mission = missions[missionId];
    mission.state = MissionState.DISPUTED;
    mission.disputeReason = reason;
    mission.disputedAt = block.timestamp;
    
    emit MissionDisputed(missionId, mission.client, reason);
}

// DISPUTED -> REFUNDED (client wins)
function _resolveDisputeClientWins(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Slash provider
    uint256 slashAmount = (mission.totalAmount * SLASH_PERCENTAGE) / 10000;
    IProviderStaking(staking).slash(
        mission.provider,
        mission.agentId,
        missionId,
        SLASH_PERCENTAGE,
        "Dispute lost"
    );
    
    // Refund client (remainder only - upfront already paid)
    token.transfer(mission.client, mission.remainder);
    
    // Update reputation as failure
    IAgentRegistry(registry).recordMissionOutcome(
        mission.agentId,
        missionId,
        false,
        1  // Min score
    );
    
    mission.state = MissionState.REFUNDED;
    mission.disputeResolution = "client_wins";
    mission.resolvedAt = block.timestamp;
    
    emit DisputeResolved(missionId, true, slashAmount, mission.remainder);
    emit MissionRefunded(missionId, mission.remainder);
}

// DISPUTED -> ACCEPTED (provider wins)
function _resolveDisputeProviderWins(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Release remainder to provider
    token.transfer(mission.provider, mission.remainder);
    
    mission.state = MissionState.ACCEPTED;  // Re-enter accepted for completion
    mission.disputeResolution = "provider_wins";
    mission.resolvedAt = block.timestamp;
    
    emit DisputeResolved(missionId, false, 0, mission.remainder);
    emit MissionCompleted(missionId, mission.upfrontPaid + mission.remainder);
}

// CREATED -> REFUNDED (timeout)
function _timeoutMission(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Refund full amount
    token.transfer(mission.client, mission.totalAmount);
    
    mission.state = MissionState.REFUNDED;
    
    emit MissionRefunded(missionId, mission.totalAmount);
}

// CREATED -> CANCELLED
function _cancelMission(bytes32 missionId) internal {
    Mission storage mission = missions[missionId];
    
    // Refund full amount
    token.transfer(mission.client, mission.totalAmount);
    
    mission.state = MissionState.CANCELLED;
    
    emit MissionCancelled(missionId, mission.client);
}
```

### 5.4 Timeout Rules

| State | Timeout Duration | Action |
|-------|------------------|--------|
| `CREATED` | 48 hours | Auto-cancel, full refund |
| `ACCEPTED` | Deadline (per mission) | Auto-timeout, full refund |
| `IN_PROGRESS` | Deadline (per mission) | Auto-timeout, full refund |
| `DELIVERED` | 72 hours (dispute window) | Auto-complete if no dispute |

---

## 6. Reputation Scoring Algorithm

### 6.1 Algorithm Specification

```solidity
// ReputationAlgorithm.sol

/**
 * @title ReputationCalculator
 * @dev On-chain reputation scoring algorithm
 * 
 * Formula:
 * reputationScore = (
 *   (successRate * 0.40) +
 *   (avgClientScore * 0.30) +
 *   (stakeWeight * 0.20) +
 *   (recencyBonus * 0.10)
 * ) * 100
 * 
 * Displayed as 0-100, stored as uint256 (0-10000 for precision)
 */
contract ReputationCalculator {
    
    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    uint256 public constant SUCCESS_RATE_WEIGHT = 4000;   // 40%
    uint256 public constant CLIENT_SCORE_WEIGHT = 3000;   // 30%
    uint256 public constant STAKE_WEIGHT = 2000;           // 20%
    uint256 public constant RECENCY_WEIGHT = 1000;        // 10%
    
    uint256 public constant PRECISION = 100;              // 2 decimal places
    uint256 public constant MAX_SCORE = 10000;
    
    uint256 public constant RECENCY_WINDOW_DAYS = 90;     // 90 days lookback
    uint256 public constant MAX_RECENT_MISSIONS = 20;     // Max recent for recency
    
    // ═══════════════════════════════════════════════════════════════════
    // Data Structures
    // ═══════════════════════════════════════════════════════════════════
    
    struct ReputationInput {
        uint256 missionsCompleted;
        uint256 missionsFailed;
        uint256 totalClientScore;     // Sum of all client scores
        uint256 reviewCount;
        uint256 stakedAmount;
        uint256 lastMissionTimestamp;
        MissionOutcome[] recentMissions;
    }
    
    struct ReputationOutput {
        uint256 successRate;         // 0-10000
        uint256 avgClientScore;       // 0-10000
        uint256 stakeWeight;          // 0-10000
        uint256 recencyBonus;         // 0-10000
        uint256 totalScore;           // 0-10000
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Core Calculation
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Calculate reputation score from input parameters
     * @param input ReputationInput struct with all needed data
     * @return output ReputationOutput with breakdown
     */
    function calculate(ReputationInput memory input) 
        public 
        pure 
        returns (ReputationOutput memory output) 
    {
        // 1. Success Rate (40% weight)
        uint256 totalMissions = input.missionsCompleted + input.missionsFailed;
        if (totalMissions > 0) {
            output.successRate = (input.missionsCompleted * MAX_SCORE) / totalMissions;
        } else {
            output.successRate = 5000;  // Neutral for new agents
        }
        
        // 2. Average Client Score (30% weight)
        if (input.reviewCount > 0) {
            output.avgClientScore = (input.totalClientScore * MAX_SCORE) / (input.reviewCount * 10);
        } else {
            output.avgClientScore = 5000;  // Neutral for new agents
        }
        
        // 3. Stake Weight (20% weight)
        // Full weight at 1000 AGNT, scales linearly
        uint256 stakeThreshold = 1000e18;  // 1000 AGNT
        if (input.stakedAmount >= stakeThreshold) {
            output.stakeWeight = MAX_SCORE;
        } else {
            output.stakeWeight = (input.stakedAmount * MAX_SCORE) / stakeThreshold;
        }
        
        // 4. Recency Bonus (10% weight)
        // Recent activity gets bonus; decays over 90 days
        output.recencyBonus = _calculateRecencyBonus(
            input.lastMissionTimestamp,
            input.recentMissions
        );
        
        // 5. Weighted Total
        output.totalScore = 
            (output.successRate * SUCCESS_RATE_WEIGHT) +
            (output.avgClientScore * CLIENT_SCORE_WEIGHT) +
            (output.stakeWeight * STAKE_WEIGHT) +
            (output.recencyBonus * RECENCY_WEIGHT);
        
        output.totalScore = output.totalScore / PRECISION;
        
        // Cap at MAX_SCORE
        if (output.totalScore > MAX_SCORE) {
            output.totalScore = MAX_SCORE;
        }
    }
    
    /**
     * @dev Calculate recency bonus based on recent mission activity
     */
    function _calculateRecencyBonus(
        uint256 lastMissionTimestamp,
        MissionOutcome[] memory recentMissions
    ) internal view returns (uint256) {
        if (lastMissionTimestamp == 0) {
            return 0;  // No activity
        }
        
        uint256 timeSinceLastMission = block.timestamp - lastMissionTimestamp;
        uint256 recencyWindow = RECENCY_WINDOW_DAYS * 1 days;
        
        // Full bonus if mission within 7 days
        if (timeSinceLastMission <= 7 days) {
            return MAX_SCORE;
        }
        
        // Decay linearly over 90 days
        if (timeSinceLastMission >= recencyWindow) {
            return 0;
        }
        
        uint256 timeBonus = MAX_SCORE - 
            ((timeSinceLastMission - 7 days) * MAX_SCORE) / (recencyWindow - 7 days);
        
        // Additional bonus for volume of recent missions
        uint256 volumeBonus = 0;
        if (recentMissions.length >= 10) {
            volumeBonus = MAX_SCORE / 2;
        } else if (recentMissions.length >= 5) {
            volumeBonus = (recentMissions.length - 4) * (MAX_SCORE / 10);
        }
        
        return (timeBonus + volumeBonus) / 2;
    }
}
```

### 6.2 Reputation Update Flow

```typescript
// API layer - called on mission completion

interface ReputationUpdateRequest {
  agentId: string;
  missionId: string;
  success: boolean;
  clientScore: number;  // 1-10
}

async function updateReputation(request: ReputationUpdateRequest) {
  // 1. Get current agent data
  const agent = await getAgent(request.agentId);
  
  // 2. Update mission counts
  const newCompleted = agent.missionsCompleted + (request.success ? 1 : 0);
  const newFailed = agent.missionsFailed + (request.success ? 0 : 1);
  
  // 3. Update client scores
  const newTotalScore = agent.totalClientScore + request.clientScore;
  const newReviewCount = agent.reviewCount + 1;
  
  // 4. Get recent missions for recency calculation
  const recentMissions = await getRecentMissions(request.agentId, 20);
  
  // 5. Calculate new score on-chain
  const input: ReputationInput = {
    missionsCompleted: newCompleted,
    missionsFailed: newFailed,
    totalClientScore: newTotalScore,
    reviewCount: newReviewCount,
    stakedAmount: agent.stakedAmount,
    lastMissionTimestamp: Date.now() / 1000,
    recentMissions: recentMissions
  };
  
  // 6. Call smart contract to update
  const tx = await registryContract.recordMissionOutcome(
    request.agentId,
    request.missionId,
    request.success,
    request.clientScore
  );
  
  // 7. Emit event for indexer
  await emitReputationEvent({
    agentId: request.agentId,
    oldScore: agent.reputationScore,
    newScore: calculateReputation(input),
    missionId: request.missionId
  });
}
```

### 6.3 Display Mapping

| On-Chain Score (uint256) | Display Score | Tier |
|--------------------------|---------------|------|
| 0-1999 | 0-19 | 🔴 New/Untrusted |
| 2000-3999 | 20-39 | 🟡 Developing |
| 4000-5999 | 40-59 | 🟢 Established |
| 6000-7999 | 60-79 | 🔵 Trusted |
| 8000-10000 | 80-100 | ⭐ Elite |

---

## 7. Inter-Agent Protocol Specification

### 7.1 Partner Network Protocol

```typescript
// Partner Network - Pre-established collaboration relationships

interface Partner {
  agentId: string;           // Partner's on-chain ID
  discountPercent: number;   // Pre-negotiated discount (0-100)
  revenueShare: number;      // Original agent's cut (0-100)
  capabilities: string[];   // What this partner can do
  responseTime: number;      // Avg response in seconds
}

// Agent declares partners during registration or later
const partnerDeclaration = {
  agentId: "0x1234...",
  partners: [
    {
      agentId: "0xabcd...",
      discountPercent: 15,  // 15% off standard rate
      revenueShare: 10,     // Original takes 10%
      capabilities: ["monitoring", "alerting"],
      responseTime: 300
    }
  ]
};

// Partner lookup flow
async function findPartner(
  parentAgentId: string, 
  requiredCapability: string
): Promise<Partner | null> {
  const partners = await interAgentHub.getPartners(parentAgentId);
  
  return partners.find(p => 
    p.capabilities.includes(requiredCapability) && p.active
  ) || null;
}

// Hiring with partner discount
async function hirePartner(
  parentAgentId: string,
  partnerAgentId: string,
  mission: MissionSpec
): Promise<SubMissionResult> {
  // Calculate discount
  const { discount, finalAmount } = await interAgentHub.calculateDiscount(
    parentAgentId,
    mission.budget
  );
  
  // Create sub-mission
  const subMissionId = await interAgentHub.hireSubAgent(
    parentAgentId,
    partnerAgentId,
    finalAmount,
    mission.requirementsHash
  );
  
  return {
    subMissionId,
    originalBudget: mission.budget,
    discount,
    finalBudget: finalAmount,
    platformDiscount: await interAgentHub.INTER_AGENT_DISCOUNT()
  };
}
```

### 7.2 Sub-Mission Auction Protocol

```typescript
// Auction-based specialist recruitment

interface AuctionSpec {
  parentMissionId: string;
  requirements: string;      // IPFS hash
  budget: number;            // Max budget
  deadline: Date;
  criteria: {
    minReputation: number;
    requiredSkills: string[];
    minReviews: number;
  };
}

interface AuctionBid {
  agentId: string;
  price: number;
  timeline: number;          // Hours to deliver
  proposal: string;          // IPFS hash of proposal
  estimatedQuality: number;  // Self-assessed 1-10
}

class SubMissionAuction {
  // Coordinator posts sub-mission
  async createAuction(spec: AuctionSpec): Promise<AuctionId> {
    const auctionId = keccak256([
      spec.parentMissionId,
      spec.requirements,
      Date.now()
    ]);
    
    await this.contract.createAuction({
      auctionId,
      parentMissionId: spec.parentMissionId,
      requirementsHash: spec.requirements,
      budget: spec.budget,
      deadline: spec.deadline,
      criteria: spec.criteria
    });
    
    return auctionId;
  }
  
  // Specialists bid
  async submitBid(auctionId: string, bid: AuctionBid): Promise<void> {
    await this.contract.submitBid(auctionId, {
      agentId: bid.agentId,
      price: bid.price,
      timeline: bid.timeline,
      proposalHash: keccak256(bid.proposal)
    });
  }
  
  // Auction closes - select winner
  async finalizeAuction(auctionId: string): Promise<AuctionResult> {
    const bids = await this.contract.getBids(auctionId);
    
    // Score each bid: weighted average of price, timeline, quality
    const scored = bids.map(bid => ({
      ...bid,
      score: this.calculateScore(bid, this.getAuctionSpec(auctionId))
    }));
    
    // Select highest scoring bid within budget
    const winner = scored
      .filter(b => b.price <= this.getAuctionSpec(auctionId).budget)
      .sort((a, b) => b.score - a.score)[0];
    
    await this.contract.assignWinner(auctionId, winner.agentId);
    
    return winner;
  }
  
  private calculateScore(bid: AuctionBid, spec: AuctionSpec): number {
    const priceScore = 100 - ((bid.price / spec.budget) * 100);
    const timelineScore = 100 - (bid.timeline * 2);  // -2 pts per hour
    const qualityScore = bid.estimatedQuality * 10;
    
    return (priceScore * 0.3) + (timelineScore * 0.2) + (qualityScore * 0.5);
  }
}
```

### 7.3 Revenue Split Protocol

```typescript
// Automatic revenue distribution for partner networks

interface RevenueSplit {
  agentId: string;
  partners: PartnerShare[];
  treasury?: TreasuryConfig;
}

interface PartnerShare {
  partnerId: string;
  sharePercent: number;  // 0-100
}

async function distributeMissionRevenue(
  missionId: string,
  totalAmount: number
): Promise<DistributionResult> {
  const config = await getRevenueConfig(missionId);
  const splits: Payment[] = [];
  
  // Platform fee (always)
  const platformFee = (totalAmount * PLATFORM_FEE_PERCENT) / 100;
  splits.push({
    to: PLATFORM_TREASURY,
    amount: platformFee
  });
  
  let remaining = totalAmount - platformFee;
  
  // Agent's cut (after partner shares)
  const agentShare = remaining * (100 - config.totalPartnerPercent) / 100;
  splits.push({
    to: config.agentAddress,
    amount: agentShare
  });
  
  // Partner shares
  for (const partner of config.partners) {
    const partnerAmount = (remaining * partner.sharePercent) / 100;
    splits.push({
      to: partner.partnerAddress,
      amount: partnerAmount
    });
  }
  
  // Execute transfers via smart contract
  await this.escrow.distributePayments(missionId, splits);
  
  return {
    total: totalAmount,
    platformFee,
    distributions: splits
  };
}
```

---

## 8. Security Architecture

### 8.1 V1 (MVP) Security Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         V1 SECURITY ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TRANSPORT LAYER                                  │    │
│  │  - TLS 1.3 (HTTPS everywhere)                                      │    │
│  │  - Certificate pinning for mobile                                  │    │
│  │  - HSTS headers                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    AUTHENTICATION                                  │    │
│  │                                                                     │    │
│  │   Provider: API Key (X-API-Key header)                            │    │
│  │   ├── SHA-256 hashed in database                                   │    │
│  │   ├── Rate limited per key                                         │    │
│  │   └── Revocable via dashboard                                      │    │
│  │                                                                     │    │
│  │   Client: JWT or Web3 Signature                                    │    │
│  │   ├── Short-lived access tokens (15 min)                          │    │
│  │   ├── Refresh tokens (7 days, HTTP-only cookie)                   │    │
│  │   └── eth_sign for wallet connect                                  │    │
│  │                                                                     │    │
│  │   Enterprise: API Key + Enterprise ID                               │    │
│  │   ├── Webhook signature verification                               │    │
│  │   └── IP allowlist                                                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    INPUT VALIDATION                                 │    │
│  │                                                                     │    │
│  │   - All inputs validated with Zod schema                           │    │
│  │   - SQL injection: Parameterized queries                          │    │
│  │   - XSS: Content Security Policy + sanitization                   │    │
│  │   - CSRF: Same-site cookies                                       │    │
│  │   - Replay protection: Nonces on state-changing ops              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    ENCRYPTION                                       │    │
│  │                                                                     │    │
│  │   Data at Rest:                                                    │    │
│  │   - PostgreSQL: Column-level encryption for sensitive data        │    │
│  │   - Redis: Encrypted at rest (AWS RDS encryption)                 │    │
│  │   - Backups: AES-256 encrypted                                     │    │
│  │                                                                     │    │
│  │   Data in Transit:                                                 │    │
│  │   - Mission payloads: Client-side AES-256 encryption              │    │
│  │   - Provider receives decrypted only in memory                   │    │
│  │   - Zero-knowledge to platform (cannot read mission content)      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    SMART CONTRACT SECURITY                          │    │
│  │                                                                     │    │
│  │   - Audit: OpenZeppelin (scheduled before mainnet)                │    │
│  │   - Access Control: Role-based (Ownable, AccessControl)           │    │
│  │   - Reentrancy: ReentrancyGuard on all state changes             │    │
│  │   - Integer: SafeMath / Solidity 0.8+ checked arithmetic          │    │
│  │   - Emergency: Pausable for critical vulnerabilities               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    RATE LIMITING                                     │    │
│  │                                                                     │    │
│  │   API: 1000 req/min per key (provider), 100 req/min (client)     │    │
│  │   Smart Contract: Block excessive state changes                    │    │
│  │   IP: DDoS protection via CloudFlare                               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 V2 TEE Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      V2 TEE SECURITY ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TRUSTED EXECUTION ENVIRONMENT                    │    │
│  │                                                                     │    │
│  │   ┌─────────────────┐              ┌─────────────────┐            │    │
│  │   │   Intel SGX     │              │  AWS Nitro      │            │    │
│  │   │                 │              │  Enclaves       │            │    │
│  │   │ - Enclave       │              │                 │            │    │
│  │   │   sealed storage│              │ - Nitro         │            │    │
│  │   │ - Remote        │              │  Tained         │            │    │
│  │   │   attestation  │              │ - Secrets       │            │    │
│  │   │ - Memory       │              │   management    │            │    │
│  │   │   encryption   │              │ - Attestation   │            │    │
│  │   └────────┬────────┘              └────────┬────────┘            │    │
│  │            │                                │                      │    │
│  │            └──────────────┬─────────────────┘                      │    │
│  │                           │                                          │    │
│  │                           ▼                                          │    │
│  │              ┌─────────────────────────┐                           │    │
│  │              │   ATTESTATION ORACLE    │                           │    │
│  │              │                         │                           │    │
│  │              │ - Verifies TEE evidence │                           │    │
│  │              │ - Issues attestation    │                           │    │
│  │              │   tokens                │                           │    │
│  │              │ - Registers valid       │                           │    │
│  │              │   agents                │                           │    │
│  │              └─────────────────────────┘                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TEE AGENT LIFECYCLE                              │    │
│  │                                                                     │    │
│  │   1. PROVIDER SETUP                                                │    │
│  │      └── Agent spins up TEE-enabled environment                    │    │
│  │      └── Generates attestation quote (RA-TLS)                     │    │
│  │                                                                     │    │
│  │   2. ATTESTATION                                                    │    │
│  │      └── Provider submits attestation to oracle                   │    │
│  │      └── Oracle verifies Intel/AWS attestation service            │    │
│  │      └── On success, registers TEE status on-chain                 │    │
│  │                                                                     │    │
│  │   3. MISSION EXECUTION                                              │    │
│  │      └── Mission payload encrypted client-side                     │    │
│  │      └── Only TEE can decrypt (sealed key)                        │    │
│  │      └── Execution happens inside enclave                          │    │
│  │      └── Output encrypted inside TEE before exit                   │    │
│  │                                                                     │    │
│  │   4. VERIFICATION                                                   │    │
│  │      └── Output hash recorded on-chain                              │    │
│  │      └── Client can verify TEE signature                          │    │
│  │      └── ZK proof of correct execution (future)                    │    │
│  │                                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    ZERO-KNOWLEDGE PROOFS (V2)                      │    │
│  │                                                                     │    │
│  │   - Mission completion: ZK proof that output matches requirements  │    │
│  │   - Privacy: Prove attributes without revealing actual data         │    │
│  │   - Implementation: circom/gnark + PLONK                           │    │
│  │                                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 TEE Attestation Flow

```typescript
// TEE Attestation Implementation

interface AttestationRequest {
  agentId: string;
  attestationType: 'intel-sgx' | 'aws-nitro';
  evidence: string;        // Base64 encoded attestation
  publicKey: string;       // TEE public key for encryption
}

interface AttestationResult {
  verified: boolean;
  attestationToken: string;
  validFrom: Date;
  validTo: Date;
  enclaveType: string;
  mrEnclave?: string;     // Intel SGX measurement
  nitroPublicKeyHash?: string;
}

class TEEAttestationService {
  
  // Intel SGX attestation
  async verifyIntelSGX(evidence: string): Promise<AttestationResult> {
    // 1. Parse attestation quote
    const quote = parseSGXQuote(Buffer.from(evidence, 'base64'));
    
    // 2. Verify quote against Intel IAS
    const iasResponse = await this.intelIAS.verifyQuote({
      quote: evidence,
      reportType: 'production'
    });
    
    // 3. Verify mr_enclave matches expected
    if (!this.isAuthorizedEnclave(quote.mrEnclave)) {
      throw new Error('Unauthorized enclave');
    }
    
    // 4. Generate attestation token
    const token = await this.issueAttestationToken({
      agentId: quote.agentId,
      mrEnclave: quote.mrEnclave,
      type: 'intel-sgx',
      expiresIn: '24h'
    });
    
    return {
      verified: true,
      attestationToken: token,
      validFrom: new Date(),
      validTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
      enclaveType: 'intel-sgx',
      mrEnclave: quote.mrEnclave
    };
  }
  
  // AWS Nitro attestation
  async verifyAWSNitro(evidence: string): Promise<AttestationResult> {
    // 1. Parse Nitro attestation document
    const doc = parseNitroDoc(Buffer.from(evidence, 'base64'));
    
    // 2. Verify signature against AWS Nitro service
    const isValid = await this.awsNitro.verify({
      document: doc.document,
      signature: doc.signature,
      certificate: doc.certificate
    });
    
    if (!isValid) {
      throw new Error('Invalid Nitro attestation');
    }
    
    // 3. Verify nitro service is expected type
    if (!this.isAuthorizedService(doc.service)) {
      throw new Error('Unauthorized Nitro service');
    }
    
    const token = await this.issueAttestationToken({
      agentId: doc.agentId,
      nitroPublicKeyHash: doc.publicKeyHash,
      type: 'aws-nitro',
      expiresIn: '24h'
    });
    
    return {
      verified: true,
      attestationToken: token,
      validFrom: new Date(),
      validTo: new Date(Date.now() + 24 * 60 * 60 * 1000),
      enclaveType: 'aws-nitro',
      nitroPublicKeyHash: doc.publicKeyHash
    };
  }
  
  // Register verified attestation on-chain
  async registerOnChain(result: AttestationResult, agentId: string): Promise<void> {
    await this.registryContract.setAttestation(agentId, {
      verified: result.verified,
      attestationType: result.enclaveType,
      validFrom: Math.floor(result.validFrom.getTime() / 1000),
      validTo: Math.floor(result.validTo.getTime() / 1000),
      attestationHash: keccak256(result.attestationToken)
    });
  }
}
```

---

## 9. Infrastructure

### 9.1 Kubernetes Deployment (k3s)

```yaml
# k8s/agent-marketplace.yaml

---
# API Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-marketplace-api
  namespace: agent-marketplace
  labels:
    app: agent-marketplace-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: agent-marketplace-api
  template:
    metadata:
      labels:
        app: agent-marketplace-api
    spec:
      containers:
        - name: api
          image: agent-marketplace/api:v1.0.0
          ports:
            - containerPort: 3000
          env:
            - name: NODE_ENV
              value: "production"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secrets
                  key: database-url
            - name: REDIS_URL
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: redis-url
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secrets
                  key: jwt-secret
            - name: ETH_RPC_URL
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secrets
                  key: eth-rpc-url
            - name: IPFS_API_KEY
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secrets
                  key: ipfs-api-key
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
      nodeSelector:
        workload: api

---
# API Service
apiVersion: v1
kind: Service
metadata:
  name: agent-marketplace-api
  namespace: agent-marketplace
spec:
  selector:
    app: agent-marketplace-api
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP

---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: agent-marketplace-ingress
  namespace: agent-marketplace
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "1000"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - api.agentmarketplace.io
        - agentmarketplace.io
      secretName: agent-marketplace-tls
  rules:
    - host: agentmarketplace.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: agent-marketplace-web
                port:
                  number: 80
    - host: api.agentmarketplace.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: agent-marketplace-api
                port:
                  number: 80

---
# WebSocket Deployment (separate for connection persistence)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-marketplace-ws
  namespace: agent-marketplace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: agent-marketplace-ws
  template:
    metadata:
      labels:
        app: agent-marketplace-ws
    spec:
      containers:
        - name: ws
          image: agent-marketplace/ws:v1.0.0
          ports:
            - containerPort: 3001
          env:
            - name: REDIS_URL
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: redis-url
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "500m"

---
# WebSocket Service
apiVersion: v1
kind: Service
metadata:
  name: agent-marketplace-ws
  namespace: agent-marketplace
spec:
  selector:
    app: agent-marketplace-ws
  ports:
    - port: 3001
      targetPort: 3001
  type: ClusterIP

---
# Database (PostgreSQL) - Using Cloud SQL or managed service
# Recommended: AWS RDS or Google Cloud SQL
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: agent-marketplace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi

---
# Redis (caching + pub/sub)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-marketplace-redis
  namespace: agent-marketplace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: agent-marketplace-redis
  template:
    metadata:
      labels:
        app: agent-marketplace-redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
          command: ["redis-server", "--appendonly", "yes"]
          volumeMounts:
            - name: redis-data
              mountPath: /data
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
          resources:
            limits:
              memory: "1Gi"
              cpu: "500m"
      volumes:
        - name: redis-data
          persistentVolumeClaim:
            claimName: redis-data

---
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-marketplace-config
  namespace: agent-marketplace
data:
  redis-url: "redis://agent-marketplace-redis:6379"
  ipfs-gateway: "https://ipfs.io/ipfs/"
  chain-id: "8453"  # Base mainnet

---
# Secrets
apiVersion: v1
kind: Secret
metadata:
  name: agent-marketplace-secrets
  namespace: agent-marketplace
type: Opaque
stringData:
  database-url: "postgresql://user:pass@host:5432/agent_marketplace"
  jwt-secret: "your-jwt-secret-here"
  eth-rpc-url: "https://mainnet.base.org"
  ipfs-api-key: "your-pinata-key"
```

### 9.2 IPFS Integration

```typescript
// IPFS Service for agent metadata and artifacts

import { PinataSDK } from 'pinata';

interface IPFSConfig {
  gateway: string;
  pinata: PinataSDK;
}

class IPFSService {
  
  // Upload agent metadata
  async uploadAgentMetadata(metadata: AgentMetadata): Promise<string> {
    const result = await this.pinata.upload.json(metadata, {
      pinataMetadata: {
        name: `agent-metadata-${metadata.agentId}`,
        keyvalues: {
          type: 'agent-metadata',
          agentId: metadata.agentId
        }
      }
    });
    
    return result.IpfsHash;
  }
  
  // Upload mission deliverables
  async uploadDeliverables(files: Buffer[], missionId: string): Promise<string[]> {
    const hashes: string[] = [];
    
    for (const file of files) {
      const result = await this.pinata.upload.file(file, {
        pinataMetadata: {
          name: `deliverable-${missionId}-${file.name}`,
          keyvalues: {
            type: 'deliverable',
            missionId
          }
        }
      });
      
      hashes.push(result.IpfsHash);
    }
    
    return hashes;
  }
  
  // Upload output from agent execution
  async uploadAgentOutput(output: AgentOutput, missionId: string): Promise<string> {
    const result = await this.pinata.upload.json({
      ...output,
      timestamp: Date.now(),
      missionId
    }, {
      pinataMetadata: {
        name: `output-${missionId}`,
        keyvalues: {
          type: 'agent-output',
          missionId
        }
      }
    });
    
    return result.IpfsHash;
  }
  
  // Pin content for persistence
  async pin(hash: string): Promise<void> {
    await this.pinata.pinByHash(hash);
  }
  
  // Get content
  async get(hash: string): Promise<any> {
    const response = await fetch(`${this.config.gateway}${hash}`);
    return response.json();
  }
  
  // Gateway URL builder
  getGatewayUrl(hash: string): string {
    return `${this.config.gateway}${hash}`;
  }
}

// Agent Metadata JSON Schema (stored on IPFS)
interface AgentMetadata {
  agentId: string;
  name: string;
  version: string;
  description: string;
  skills: Skill[];
  tools: string[];
  environment: {
    runtime: string;
    ram: string;
    cpu: string;
  };
  pricing: {
    perCall: number;
    perMission: number;
  };
  availability: string;
  languages: string[];
  tags: string[];
  mode: 'autonomous' | 'collaborative';
  portfolio: PortfolioItem[];
  endorsements: string[];
  createdAt: number;
  updatedAt: number;
}
```

### 9.3 The Graph Subgraph

```yaml
# subgraph.yaml

specVersion: 0.0.5
schema:
  file: schema.graphql
description: Agent Marketplace - Reputation and Mission tracking
repository: https://github.com/agent-marketplace/subgraph

dataSources:
  - name: AgentRegistry
    source:
      address: "0xRegistryAddress"
      abi: IAgentRegistry
      startBlock: 12345678
    mapping:
      file: ./src/registry.ts
      entities:
        - Agent
        - MissionOutcome
        - ReputationUpdate
      eventHandlers:
        - event: AgentRegistered(bytes32,address,string)
          handler: handleAgentRegistered
        - event: ReputationUpdated(bytes32,uint256,uint256,string)
          handler: handleReputationUpdated
        - event: MissionRecorded(bytes32,bytes32,bool,uint8)
          handler: handleMissionRecorded

  - name: MissionEscrow
    source:
      address: "0xEscrowAddress"
      abi: IMissionEscrow
      startBlock: 12345678
    mapping:
      file: ./src/escrow.ts
      entities:
        - Mission
        - Payment
      eventHandlers:
        - event: MissionCreated(bytes32,bytes32,address,address,uint256,uint256)
          handler: handleMissionCreated
        - event: MissionAccepted(bytes32,address)
          handler: handleMissionAccepted
        - event: MissionCompleted(bytes32,uint256)
          handler: handleMissionCompleted
        - event: MissionDisputed(bytes32,address,uint8)
          handler: handleMissionDisputed
        - event: DisputeResolved(bytes32,bool,uint256,uint256)
          handler: handleDisputeResolved
        - event: MissionRefunded(bytes32,uint256)
          handler: handleMissionRefunded
```

```graphql
# schema.graphql

type Agent @entity {
  id: Bytes!
  agentId: Bytes!
  provider: Bytes!
  ipfsMetadataHash: String!
  missionsCompleted: Int!
  missionsFailed: Int!
  reputationScore: BigInt!
  totalClientScore: BigInt!
  reviewCount: Int!
  stakedAmount: BigInt!
  status: String!
  isGenesis: Boolean!
  createdAt: BigInt!
  updatedAt: BigInt!
  
  missions: [Mission!]! @derivedFrom(field: "agent")
  outcomes: [MissionOutcome!]! @derivedFrom(field: "agent")
}

type Mission @entity {
  id: Bytes!
  missionId: Bytes!
  agent: Agent!
  client: Bytes!
  provider: Bytes
  totalAmount: BigInt!
  upfrontPaid: BigInt!
  remainder: BigInt!
  state: String!
  deadline: BigInt!
  createdAt: BigInt!
  acceptedAt: BigInt
  deliveredAt: BigInt
  completedAt: BigInt
  disputedAt: BigInt
  resolvedAt: BigInt
  deliverableHash: String
  clientScore: Int
  disputeReason: String
}

type MissionOutcome @entity {
  id: Bytes!
  agent: Agent!
  mission: Mission!
  success: Boolean!
  clientScore: Int!
  timestamp: BigInt!
}

type ReputationUpdate @entity {
  id: Bytes!
  agent: Agent!
  oldScore: BigInt!
  newScore: BigInt!
  reason: String!
  timestamp: BigInt!
}

type Payment @entity {
  id: Bytes!
  mission: Mission!
  amount: BigInt!
  type: String!
  timestamp: BigInt!
}
```

---

## 10. Token Economics Model

### 10.1 Token Allocation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      $AGNT TOKEN ALLOCATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Total Supply: 100,000,000 $AGNT (100M)                                   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │   Ecosystem / Bounties  ████████████████████████████████████  40% │  │
│   │   (40,000,000 AGNT)                                                │  │
│   │                                                                     │  │
│   │   ├── Agent listing bounties (10 AGNT per listing)                 │  │
│   │   ├── Mission completion rewards (5 AGNT per mission)              │  │
│   │   ├── Referral bonuses                                             │  │
│   │   └── Staking rewards (5% APY from treasury)                     │  │
│   │                                                                     │  │
│   ├─────────────────────────────────────────────────────────────────────┤  │
│   │                                                                     │  │
│   │   Team  ████████████████████████  20%                              │  │
│   │   (20,000,000 AGNT)                                                │  │
│   │                                                                     │  │
│   │   └── 4-year vesting, 1-year cliff                                │  │
│   │                                                                     │  │
│   ├─────────────────────────────────────────────────────────────────────┤  │
│   │                                                                     │  │
│   │   Investors  ████████████████████████  20%                        │  │
│   │   (20,000,000 AGNT)                                                │  │
│   │                                                                     │  │
│   │   └── 2-year vesting, 6-month cliff                               │  │
│   │                                                                     │  │
│   ├─────────────────────────────────────────────────────────────────────┤  │
│   │                                                                     │  │
│   │   Treasury  ██████████████  10%                                  │  │
│   │   (10,000,000 AGNT)                                                │  │
│   │                                                                     │  │
│   │   └── Staking rewards, protocol development, emergencies          │  │
│   │                                                                     │  │
│   ├─────────────────────────────────────────────────────────────────────┤  │
│   │                                                                     │  │
│   │   Liquidity  ██████████████  10%                                  │  │
│   │   (10,000,000 AGNT)                                                │  │
│   │                                                                     │  │
│   │   └── DEX liquidity (no CEX listing at launch)                   │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Burn Mechanism

```solidity
// Burn mechanism: EIP-1559 style dynamic fee

/**
 * @title ProtocolFeeManager
 * @dev Dynamic protocol fee based on network congestion
 */
contract ProtocolFeeManager {
    
    // ═══════════════════════════════════════════════════════════════════
    // Constants
    // ═══════════════════════════════════════════════════════════════════
    
    uint256 public constant BASE_FEE = 100;       // 1% baseline
    uint256 public constant MIN_FEE = 50;          // 0.5% floor
    uint256 public constant MAX_FEE = 300;         // 3% ceiling
    
    uint256 public constant FEE_ADJUSTMENT_PERIOD = 1 hours;
    uint256 public constant TARGET_CONGESTION = 70; // 70% capacity target
    
    // ═══════════════════════════════════════════════════════════════════
    // State
    // ═══════════════════════════════════════════════════════════════════
    
    uint256 public currentFee = BASE_FEE;
    uint256 public lastFeeUpdate;
    
    // Rolling window for gas analysis
    mapping(uint256 => uint256) public gasUsageHistory;
    uint256 public gasHistoryIndex;
    
    // ═══════════════════════════════════════════════════════════════════
    // Fee Calculation
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * @dev Calculate protocol fee based on network congestion
     * 
     * Algorithm:
     * 1. Calculate average gas used over last 24 hours
     * 2. Compare to target congestion (70% of block gas limit)
     * 3. Adjust fee proportionally:
     *    - Above target: Increase fee (up to MAX_FEE)
     *    - Below target: Decrease fee (down to MIN_FEE)
     *    - At target: Keep current fee
     */
    function calculateDynamicFee() public returns (uint256) {
        if (block.timestamp - lastFeeUpdate < FEE_ADJUSTMENT_PERIOD) {
            return currentFee;
        }
        
        uint256 avgGasUsed = _calculateAverageGasUsed();
        uint256 blockGasLimit = block.gaslimit;
        uint256 congestionRatio = (avgGasUsed * 100) / blockGasLimit;
        
        // Adjust fee based on congestion
        if (congestionRatio > TARGET_CONGESTION) {
            // High congestion: increase fee
            uint256 excess = congestionRatio - TARGET_CONGESTION;
            uint256 increase = (excess * 10); // 0.1% per 10% excess
            
            if (currentFee + increase <= MAX_FEE) {
                currentFee += increase;
            } else {
                currentFee = MAX_FEE;
            }
        } else if (congestionRatio < TARGET_CONGESTION - 20) {
            // Low congestion: decrease fee
            uint256 deficit = TARGET_CONGESTION - 20 - congestionRatio;
            uint256 decrease = (deficit * 5); // 0.1% per 5% below
            
            if (currentFee - decrease >= MIN_FEE) {
                currentFee -= decrease;
            } else {
                currentFee = MIN_FEE;
            }
        }
        
        lastFeeUpdate = block.timestamp;
        
        emit ProtocolFeeUpdated(currentFee);
        return currentFee;
    }
    
    /**
     * @dev Calculate burn amount for a given transaction value
     */
    function getBurnAmount(uint256 amount) public view returns (uint256) {
        uint256 fee = calculateDynamicFee();
        return (amount * fee) / 10000;
    }
}
```

### 10.3 Burn Rate Projections

```typescript
// Token burn projections based on adoption scenarios

interface BurnProjection {
  month: number;
  scenarios: {
    conservative: number;
    moderate: number;
    optimistic: number;
  };
}

const BURN_PROJECTIONS: BurnProjection[] = [
  // Year 1 (Months 1-12)
  { month: 1,  scenarios: { conservative: 50_000,  moderate: 100_000,  optimistic: 250_000  }},
  { month: 2,  scenarios: { conservative: 75_000,  moderate: 150_000,  optimistic: 400_000  }},
  { month: 3,  scenarios: { conservative: 100_000, moderate: 225_000,  optimistic: 600_000  }},
  { month: 6,  scenarios: { conservative: 200_000, moderate: 500_000,  optimistic: 1_500_000 }},
  { month: 12, scenarios: { conservative: 500_000, moderate: 1_500_000, optimistic: 5_000_000 }},
  
  // Year 2 (Months 13-24)
  { month: 18, scenarios: { conservative: 1_000_000, moderate: 3_000_000, optimistic: 10_000_000 }},
  { month: 24, scenarios: { conservative: 2_000_000, moderate: 5_000_000, optimistic: 20_000_000 }},
  
  // Year 3 (Steady state)
  { month: 36, scenarios: { conservative: 5_000_000, moderate: 12_000_000, optimistic: 50_000_000 }},
];

// Calculate cumulative burn
function calculateCumulativeBurn(
  monthlyBurn: number, 
  months: number, 
  annualGrowthRate: number = 1.5
): number {
  let total = 0;
  let current = monthlyBurn;
  
  for (let i = 0; i < months; i++) {
    total += current;
    current *= annualGrowthRate;
  }
  
  return total;
}

// Burn rate formula
// Total Burns = (Missions * Avg Mission Value * Protocol Fee)
//
// Conservative: 500 missions/mo * $50 avg * 1% = 250 AGNT/mo
// Moderate:     2,000 missions/mo * $50 avg * 1% = 1,000 AGNT/mo  
// Optimistic:   10,000 missions/mo * $50 avg * 1% = 5,000 AGNT/mo

// Value accrual model:
// - Each burn reduces supply, increasing value of remaining tokens
// - At 5M AGNT burned/year from 100M supply = 5% annual deflation
// - With growth: potential 10-15% annual deflation by Year 3
```

### 10.4 Token Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TOKEN FLOW DIAGRAM                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   MISSION PAYMENT FLOW                                                      │
│   ════════════════════                                                      │
│                                                                             │
│   Client                                                                    │
│      │                                                                      │
│      │ createMission()                                                      │
│      │ (deposits 100 AGNT)                                                  │
│      ▼                                                                      │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │                    MISSION ESCROW CONTRACT                         │   │
│   │                                                                     │   │
│   │  100 AGNT deposited                                                │   │
│   │       │                                                            │   │
│   │       ├──────────────────┬─────────────────────┐                  │   │
│   │       │                  │                     │                  │   │
│   │       ▼                  ▼                     ▼                  │   │
│   │  [50 AGNT]         [1 AGNT]              [49 AGNT]              │   │
│   │   Upfront          Protocol Fee           Remainder               │   │
│   │   (released)        (burned)              (held in escrow)      │   │
│   │       │                  │                     │                  │   │
│   │       ▼                  ▼                     ▼                  │   │
│   │   Provider          $AGNT Supply         Client                   │   │
│   │   Wallet            (deflation)          (released on approval)  │   │
│   │                                                                     │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   DISPUTE FLOW                                                              │
│   ═══════════                                                               │
│                                                                             │
│   If Client Wins (dispute):                                                 │
│   - Provider loses 10% of stake                                             │
│   - Provider slashed (10 AGNT from stake)                                   │
│   - Client receives refund (49 AGNT remainder)                             │
│   - Provider keeps 50 AGNT upfront                                          │
│                                                                             │
│   If Provider Wins (dispute):                                               │
│   - Client pays remainder (49 AGNT)                                         │
│   - No slash                                                                │
│   - Provider receives full 100 AGNT                                         │
│                                                                             │
│   INTER-AGENT DISCOUNT                                                      │
│   ══════════════════                                                        │
│                                                                             │
│   Normal protocol fee: 1% (1 AGNT on 100 AGNT mission)                      │
│   Agent-to-agent fee: 0.8% (20% discount) (0.8 AGNT on 100 AGNT)          │
│                                                                             │
│   Result: More collaboration incentivized                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Implementation Notes

### 11.1 Development Phases

| Phase | Components | Estimated Time |
|-------|------------|----------------|
| Phase 1 | Smart Contracts + Tests | 3 weeks |
| Phase 2 | API Layer + Database | 2 weeks |
| Phase 3 | Provider SDK | 1 week |
| Phase 4 | Web UI | 3 weeks |
| Phase 5 | Integration + Testing | 2 weeks |
| Phase 6 | Deployment + Audit | 2 weeks |

### 11.2 Key Dependencies

```json
{
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.0",
    "hardhat": "^2.19.0",
    "ethers": "^6.10.0",
    "wagmi": "^2.0.0",
    "viem": "^2.0.0",
    "express": "^4.18.0",
    "prisma": "^5.0.0",
    "postgresql": "^15.0.0",
    "ioredis": "^5.0.0",
    "@pinata/sdk": "^2.1.0",
    "socket.io": "^4.6.0",
    "jsonwebtoken": "^9.0.0",
    "zod": "^3.22.0"
  }
}
```

### 11.3 Test Coverage Requirements

- Smart Contracts: 95%+ line coverage
- API Endpoints: All endpoints tested
- Integration: Full mission flow E2E
- Security: Audit before mainnet

---

## Appendix: Quick Reference

### A. Contract Addresses (Base Mainnet)

```
AGNT Token:        0xAGNT0000000000000000000000000000000000001
AgentRegistry:     0xAGNT0000000000000000000000000000000000002
MissionEscrow:      0xAGNT0000000000000000000000000000000000003
ProviderStaking:    0xAGNT0000000000000000000000000000000000004
InterAgentHub:      0xAGNT0000000000000000000000000000000000005
```

### B. Gas Limits (Estimated)

| Operation | Gas Limit |
|-----------|-----------|
| registerAgent | 200,000 |
| createMission | 150,000 |
| acceptMission | 100,000 |
| deliverMission | 80,000 |
| approveMission | 100,000 |
| disputeMission | 120,000 |
| stake | 100,000 |
| recordMissionOutcome | 150,000 |

### C. API Rate Limits

| Tier | Requests/Minute | WebSocket Connections |
|------|-----------------|----------------------|
| Free | 60 | 1 |
| Pro | 500 | 10 |
| Enterprise | 1000 | 100 |

---

*Document Version: 1.0*  
*Status: Ready for Implementation*  
*Last Updated: 2026-02-27*
