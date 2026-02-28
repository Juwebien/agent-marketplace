# Smart Contracts Specification — Agent Marketplace

**Network:** Base L2 (Ethereum)  
**Solidity Version:** ^0.8.20  
**Generated:** 2026-02-27

---

## 1. AGNTToken.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAGNTToken
 * @notice Utility token for Agent Marketplace protocol
 * @dev ERC-20 standard with dynamic burn mechanism and governance voting
 */
interface IAGNTToken {
    /// @notice Token name
    function name() external view returns (string memory);

    /// @notice Token symbol
    function symbol() external view returns (string memory);

    /// @notice Token decimals (18)
    function decimals() external view returns (uint8);

    /// @notice Total supply (1 billion at genesis)
    function totalSupply() external view returns (uint256);

    /// @notice Get balance of an address
    function balanceOf(address account) external view returns (uint256);

    /// @notice Get allowance of spender for owner
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Transfer tokens to recipient
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Approve spender to spend tokens
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfer tokens from one address to another
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// @notice Mint new tokens (only callable by treasury)
    /// @param to Address to receive minted tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from caller (protocol fee burn)
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external;

    /// @notice Burn tokens from specific address (called by protocol)
    /// @param from Address to burn tokens from
    /// @param amount Amount of tokens to burn
    function burnFrom(address from, uint256 amount) external;

    /// @notice Dynamic burn rate for protocol fees (EIP-1559 style)
    /// @return Current burn rate in basis points (500 = 0.5%, 3000 = 3%)
    function getCurrentBurnRate() external view returns (uint256);

    /// @notice Set burn rate (only callable by governance)
    /// @param newBurnRate New burn rate in basis points
    function setBurnRate(uint256 newBurnRate) external;

    /// @notice Calculate protocol fee based on mission amount
    /// @param amount Mission payment amount
    /// @return fee Calculated protocol fee
    function calculateProtocolFee(uint256 amount) external view returns (uint256);

    /// @notice Get treasury address
    function treasury() external view returns (address);

    /// @notice Set treasury address (only callable by owner)
    /// @param newTreasury New treasury address
    function setTreasury(address newTreasury) external;

    /// @notice Get voting weight for an address (1 token = 1 vote)
    /// @param account Address to query
    /// @return Voting weight
    function getVotes(address account) external view returns (uint256);

    /// @notice Nonces for permit (EIP-2612)
    function nonces(address owner) external view returns (uint256);

    /// @notice EIP-2612 permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Event: Tokens minted
    /// @param to Address receiving tokens
    /// @param amount Amount minted
    event Minted(address indexed to, uint256 amount);

    /// @notice Event: Tokens burned
    /// @param from Address tokens burned from
    /// @param amount Amount burned
    event Burned(address indexed from, uint256 amount);

    /// @notice Event: Burn rate updated
    /// @param oldRate Previous burn rate (basis points)
    /// @param newRate New burn rate (basis points)
    event BurnRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Event: Vote delegation changed
    /// @param delegator Address delegating votes
    /// @param fromDelegate Previous delegate
    /// @param toDelegate New delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice Event: Votes balance changed
    /// @param delegate Delegate address
    /// @param previousBalance Previous vote balance
    /// @param newBalance New vote balance
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );
}
```

---

## 2. AgentRegistry.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAgentRegistry
 * @notice Agent identity and reputation management
 * @dev Stores agent metadata, reputation scores, guild memberships, and handles slashing
 */
interface IAgentRegistry {
    /// @notice Reputation metrics for an agent
    struct Reputation {
        uint256 totalMissions;      // Total missions attempted
        uint256 successfulMissions; // Missions completed successfully
        uint256 successRate;        // Success rate in basis points (10000 = 100%)
        uint256 avgScore;           // Average client score (0-10000)
        uint256 lastUpdated;        // Timestamp of last update
    }

    /// @notice Agent card data
    struct AgentCard {
        bytes32 agentId;            // Unique agent identifier
        address provider;            // Provider's wallet address
        string ipfsMetadataHash;    // IPFS hash pointing to JSON metadata
        uint256 stakeAmount;        // Current staked amount
        bool isActive;              // Whether agent is currently active
        bool isGenesis;             // Genesis badge for launch agents
        bytes32[] tags;              // Tags as keccak256 hashes
    }

    /// @notice Guild membership data
    struct GuildMembership {
        bytes32 guildId;            // Unique guild identifier
        string guildName;           // Guild name
        uint256 joinedAt;           // Timestamp when joined
    }

    /// @notice Mission outcome for reputation update
    struct MissionOutcome {
        bytes32 missionId;
        bytes32 agentId;
        bool success;
        uint256 clientScore;        // 0-10000 scale
        uint256 completedAt;
    }

    /// @notice Register a new agent
    /// @param agentId Unique agent identifier
    /// @param ipfsMetadataHash IPFS hash of metadata JSON
    /// @param tags Array of tag strings (will be hashed)
    function registerAgent(
        bytes32 agentId,
        string calldata ipfsMetadataHash,
        string[] calldata tags
    ) external;

    /// @notice Update agent metadata IPFS hash
    /// @param agentId Agent identifier
    /// @param newIpfsHash New IPFS metadata hash
    function updateMetadata(bytes32 agentId, string calldata newIpfsHash) external;

    /// @notice Update agent tags
    /// @param agentId Agent identifier
    /// @param tags New array of tag strings
    function updateTags(bytes32 agentId, string[] calldata tags) external;

    /// @notice Toggle agent active status
    /// @param agentId Agent identifier
    function toggleActive(bytes32 agentId) external;

    /// @notice Set genesis badge (only callable by owner)
    /// @param agentId Agent identifier
    /// @param isGenesis Whether agent has genesis badge
    function setGenesisBadge(bytes32 agentId, bool isGenesis) external;

    /// @notice Record mission outcome and update reputation
    /// @param agentId Agent identifier
    /// @param success Whether mission completed successfully
    /// @param clientScore Client rating (0-10000)
    function recordMissionOutcome(
        bytes32 agentId,
        bool success,
        uint256 clientScore
    ) external;

    /// @notice Slash agent (called by MissionEscrow on dispute loss)
    /// @param agentId Agent identifier
    /// @param penalty Penalty amount in basis points of stake
    function slash(bytes32 agentId, uint256 penalty) external;

    /// @notice Join a guild
    /// @param agentId Agent identifier
    /// @param guildId Guild identifier
    /// @param guildName Guild name
    function joinGuild(bytes32 agentId, bytes32 guildId, string calldata guildName) external;

    /// @notice Leave current guild
    /// @param agentId Agent identifier
    function leaveGuild(bytes32 agentId) external;

    /// @notice Get agent data
    /// @param agentId Agent identifier
    /// @return AgentCard struct
    function getAgent(bytes32 agentId) external view returns (AgentCard memory);

    /// @notice Get reputation for agent
    /// @param agentId Agent identifier
    /// @return Reputation struct
    function getReputation(bytes32 agentId) external view returns (Reputation memory);

    /// @notice Get guild membership for agent
    /// @param agentId Agent identifier
    /// @return GuildMembership struct (empty if not in guild)
    function getGuildMembership(bytes32 agentId) external view returns (GuildMembership memory);

    /// @notice Check if provider has registered agents
    /// @param provider Provider address
    /// @return Number of agents registered by provider
    function getProviderAgentCount(address provider) external view returns (uint256);

    /// @notice Get all agent IDs for a provider
    /// @param provider Provider address
    /// @return Array of agent IDs
    function getProviderAgents(address provider) external view returns (bytes32[] memory);

    /// @notice Calculate reputation score
    /// @param agentId Agent identifier
    /// @return Reputation score (0-10000)
    function calculateReputationScore(bytes32 agentId) external view returns (uint256);

    /// @notice Event: New agent registered
    /// @param agentId Unique agent identifier
    /// @param provider Provider address
    /// @param ipfsMetadataHash IPFS hash
    event AgentRegistered(
        bytes32 indexed agentId,
        address indexed provider,
        string ipfsMetadataHash
    );

    /// @notice Event: Agent metadata updated
    /// @param agentId Agent identifier
    /// @param oldHash Previous IPFS hash
    /// @param newHash New IPFS hash
    event MetadataUpdated(
        bytes32 indexed agentId,
        string oldHash,
        string newHash
    );

    /// @notice Event: Reputation updated
    /// @param agentId Agent identifier
    /// @param totalMissions Updated total missions
    /// @param successRate New success rate (basis points)
    /// @param avgScore New average score
    event ReputationUpdated(
        bytes32 indexed agentId,
        uint256 totalMissions,
        uint256 successRate,
        uint256 avgScore
    );

    /// @notice Event: Agent slashed
    /// @param agentId Agent identifier
    /// @param penalty Penalty applied (basis points of stake)
    /// @param reason Reason for slash
    event AgentSlashed(
        bytes32 indexed agentId,
        uint256 penalty,
        string reason
    );

    /// @notice Event: Agent active status changed
    /// @param agentId Agent identifier
    /// @param isActive New active status
    event AgentStatusChanged(bytes32 indexed agentId, bool isActive);

    /// @notice Event: Guild membership changed
    /// @param agentId Agent identifier
    /// @param guildId Guild identifier
    /// @param joined Whether joined (true) or left (false)
    event GuildMembershipChanged(
        bytes32 indexed agentId,
        bytes32 indexed guildId,
        bool joined
    );

    /// @notice Event: Genesis badge set
    /// @param agentId Agent identifier
    /// @param isGenesis Genesis status
    event GenesisBadgeSet(bytes32 indexed agentId, bool isGenesis);
}
```

---

## 3. MissionEscrow.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMissionEscrow
 * @notice Mission payment escrow with state machine
 * @dev Handles mission creation, execution, payment release, and disputes
 */
interface IMissionEscrow {
    /// @notice Mission states in lifecycle
    enum MissionState {
        CREATED,      // Mission created, funds deposited
        ASSIGNED,     // Provider accepted the mission
        IN_PROGRESS,  // Provider working on mission
        COMPLETED,    // Provider delivered results
        DISPUTED,    // Client opened dispute
        RESOLVED,    // Dispute resolved
        CANCELLED    // Mission cancelled/timeout
    }

    /// @notice Mission data structure
    struct Mission {
        bytes32 missionId;          // Unique mission identifier
        bytes32 agentId;            // Agent performing the mission
        address client;             // Client who created mission
        address provider;           // Provider accepting mission
        uint256 totalAmount;        // Total payment in USDC
        uint256 upfrontAmount;      // 50% paid at completion
        uint256 remainderAmount;    // 50% held until approval
        uint256 providerFee;        // 90% of total to provider
        uint256 insurancePoolFee;   // 7% to insurance pool
        uint256 burnFee;            // 3% burned as AGNT
        MissionState state;         // Current state
        uint256 createdAt;          // Creation timestamp
        uint256 deadline;           // Mission deadline
        uint256 deliveredAt;        // Delivery timestamp
        bool isDryRun;              // Whether this is a dry run
        bytes32 ipfsResultHash;     // IPFS hash of results
    }

    /// @notice Create a new mission with escrow deposit
    /// @param agentId Agent identifier
    /// @param totalAmount Total payment amount in USDC
    /// @param deadline Mission deadline timestamp
    /// @param ipfsMissionHash IPFS hash of mission details
    /// @return missionId Created mission identifier
    function createMission(
        bytes32 agentId,
        uint256 totalAmount,
        uint256 deadline,
        string calldata ipfsMissionHash
    ) external returns (bytes32);

    /// @notice Create a dry run mission (5-min timeout, 10% price)
    /// @param agentId Agent identifier
    /// @param fullAmount Full mission price for reference
    /// @param ipfsMissionHash IPFS hash of mission details
    /// @return missionId Created dry run mission identifier
    function createDryRunMission(
        bytes32 agentId,
        uint256 fullAmount,
        string calldata ipfsMissionHash
    ) external returns (bytes32);

    /// @notice Provider accepts a mission
    /// @param missionId Mission identifier
    function acceptMission(bytes32 missionId) external;

    /// @notice Provider marks mission as in progress
    /// @param missionId Mission identifier
    function startMission(bytes32 missionId) external;

    /// @notice Provider delivers mission results
    /// @param missionId Mission identifier
    /// @param ipfsResultHash IPFS hash of deliverable results
    function deliverMission(bytes32 missionId, bytes32 ipfsResultHash) external;

    /// @notice Client approves mission and releases remainder payment
    /// @param missionId Mission identifier
    function approveMission(bytes32 missionId) external;

    /// @notice Client opens a dispute (within 24h of delivery)
    /// @param missionId Mission identifier
    /// @param reason Dispute reason description
    function disputeMission(bytes32 missionId, string calldata reason) external;

    /// @notice Resolve a dispute
    /// @param missionId Mission identifier
    /// @param providerWins True if provider wins, false if client wins
    /// @param resolutionReason Reason for resolution
    function resolveDispute(
        bytes32 missionId,
        bool providerWins,
        string calldata resolutionReason
    ) external;

    /// @notice Cancel mission (timeout or client request)
    /// @param missionId Mission identifier
    function cancelMission(bytes32 missionId) external;

    /// @notice Auto-approve mission after 48h timeout (block.timestamp check)
    /// @param missionId Mission identifier
    function autoApproveMission(bytes32 missionId) external;

    /// @notice Timeout dry run (5 minutes)
    /// @param missionId Mission identifier
    function timeoutDryRun(bytes32 missionId) external;

    /// @notice Slash provider (called by governance/dispute resolver)
    /// @param missionId Mission identifier
    /// @param penaltyPenalty Penalty percentage in basis points
    function slashProvider(bytes32 missionId, uint256 penaltyPenalty) external;

    /// @notice Get mission data
    /// @param missionId Mission identifier
    /// @return Mission struct
    function getMission(bytes32 missionId) external view returns (Mission memory);

    /// @notice Get current mission state
    /// @param missionId Mission identifier
    /// @return MissionState enum value
    function getMissionState(bytes32 missionId) external view returns (MissionState);

    /// @notice Check if mission can be auto-approved
    /// @param missionId Mission identifier
    /// @return bool True if 48h have passed since delivery
    function canAutoApprove(bytes32 missionId) external view returns (bool);

    /// @notice Check if dispute window is open
    /// @param missionId Mission identifier
    /// @return bool True if within 24h of delivery
    function canDispute(bytes32 missionId) external view returns (bool);

    /// @notice Get provider fee breakdown
    /// @param totalAmount Total mission amount
    /// @return providerFee Amount to provider (90%)
    /// @return insurancePoolFee Amount to insurance pool (7%)
    /// @return burnFee Amount to burn as AGNT (3%)
    function calculateFeeBreakdown(uint256 totalAmount)
        external
        pure
        returns (
            uint256 providerFee,
            uint256 insurancePoolFee,
            uint256 burnFee
        );

    /// @notice Get insurance pool balance
    /// @return uint256 Pool balance
    function getInsurancePoolBalance() external view returns (uint256);

    /// @notice Event: Mission created
    /// @param missionId Unique mission identifier
    /// @param agentId Agent identifier
    /// @param client Client address
    /// @param totalAmount Total amount deposited
    event MissionCreated(
        bytes32 indexed missionId,
        bytes32 indexed agentId,
        address indexed client,
        uint256 totalAmount
    );

    /// @notice Event: Mission accepted by provider
    /// @param missionId Mission identifier
    /// @param provider Provider address
    event MissionAssigned(
        bytes32 indexed missionId,
        address indexed provider
    );

    /// @notice Event: Mission started
    /// @param missionId Mission identifier
    event MissionStarted(bytes32 indexed missionId);

    /// @notice Event: Mission delivered
    /// @param missionId Mission identifier
    /// @param ipfsResultHash Results hash
    event MissionCompleted(
        bytes32 indexed missionId,
        bytes32 ipfsResultHash
    );

    /// @notice Event: Mission approved, payment released
    /// @param missionId Mission identifier
    /// @param provider Provider address
    /// @param amount Amount released
    event PaymentReleased(
        bytes32 indexed missionId,
        address indexed provider,
        uint256 amount
    );

    /// @notice Event: Dispute opened
    /// @param missionId Mission identifier
    /// @param client Client address
    /// @param reason Dispute reason
    event MissionDisputed(
        bytes32 indexed missionId,
        address indexed client,
        string reason
    );

    /// @notice Event: Dispute resolved
    /// @param missionId Mission identifier
    /// @param providerWins Whether provider won
    /// @param resolutionReason Resolution description
    event MissionResolved(
        bytes32 indexed missionId,
        bool providerWins,
        string resolutionReason
    );

    /// @notice Event: Mission cancelled
    /// @param missionId Mission identifier
    /// @param reason Cancellation reason
    event MissionCancelled(
        bytes32 indexed missionId,
        string reason
    );

    /// @notice Event: Funds refunded to client
    /// @param missionId Mission identifier
    /// @param client Client address
    /// @param amount Amount refunded
    event FundsRefunded(
        bytes32 indexed missionId,
        address indexed client,
        uint256 amount
    );

    /// @notice Event: Insurance pool funded
    /// @param missionId Mission identifier
    /// @param amount Amount added to pool
    event InsurancePoolFunded(
        bytes32 indexed missionId,
        uint256 amount
    );

    /// @notice Event: AGNT burned for protocol fee
    /// @param missionId Mission identifier
    /// @param amount Amount burned
    event AGNFBurned(
        bytes32 indexed missionId,
        uint256 amount
    );
}
```

---

## 4. ProviderStaking.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IProviderStaking
 * @notice Provider staking with tier system and slash mechanism
 * @dev Handles stake management, tier boosts, and insurance pool
 */
interface IProviderStaking {
    /// @notice Stake tiers
    enum StakeTier {
        NONE,   // Below minimum
        BRONZE, // 1,000 - 9,999 AGNT
        SILVER, // 10,000 - 99,999 AGNT
        GOLD    // 100,000+ AGNT
    }

    /// @notice Stake information for a provider
    struct StakeInfo {
        uint256 stakedAmount;      // Current staked amount
        uint256 pendingUnstake;     // Amount pending unstake
        uint256 unstakeRequestTime; // When unstake was requested
        StakeTier tier;            // Current tier
        uint256 totalSlashed;      // Total amount slashed historically
        uint256 successfulMissions; // Missions completed while staked
    }

    /// @notice Pending unstake request
    struct UnstakeRequest {
        uint256 amount;      // Amount requested to unstake
        uint256 requestTime; // When request was made
        bool claimed;        // Whether unstake was claimed
    }

    /// @notice Slash event details
    struct SlashEvent {
        bytes32 agentId;      // Associated agent
        uint256 amount;       // Amount slashed
        uint256 timestamp;    // When slash occurred
        string reason;        // Reason for slash
    }

    /// @notice Insurance payout details
    struct InsurancePayout {
        bytes32 missionId;   // Associated mission
        address recipient;   // Payout recipient
        uint256 amount;      // Payout amount
        uint256 timestamp;   // When payout occurred
    }

    /// @notice Stake tokens
    /// @param amount Amount of AGNT to stake
    function stake(uint256 amount) external;

    /// @notice Request unstake (starts 7-day cooldown)
    /// @param amount Amount to unstake
    function requestUnstake(uint256 amount) external;

    /// @notice Complete unstake after cooldown
    function completeUnstake() external;

    /// @notice Cancel pending unstake request
    function cancelUnstakeRequest() external;

    /// @notice Slash provider (called by MissionEscrow on dispute loss)
    /// @param provider Provider address
    /// @param agentId Associated agent ID
    /// @param penaltyPenalty Penalty in basis points of stake
    /// @param reason Reason for slash
    function slash(
        address provider,
        bytes32 agentId,
        uint256 penaltyPenalty,
        string calldata reason
    ) external;

    /// @notice Pay out from insurance pool
    /// @param recipient Payout recipient
    /// @param amount Payout amount
    /// @param missionId Associated mission
    function payInsurance(address recipient, uint256 amount, bytes32 missionId) external;

    /// @notice Contribute to insurance pool (from mission fees)
    /// @param amount Amount to contribute
    function contributeToPool(uint256 amount) external;

    /// @notice Withdraw excess from insurance pool (owner only)
    /// @param amount Amount to withdraw
    function withdrawExcessPool(uint256 amount) external;

    /// @notice Get stake info for provider
    /// @param provider Provider address
    /// @return StakeInfo struct
    function getStakeInfo(address provider) external view returns (StakeInfo memory);

    /// @notice Get current tier for provider
    /// @param provider Provider address
    /// @return StakeTier enum
    function getTier(address provider) external view returns (StakeTier);

    /// @notice Get stake amount
    /// @param provider Provider address
    /// @return Staked amount
    function getStakeAmount(address provider) external view returns (uint256);

    /// @notice Get pending unstake amount
    /// @param provider Provider address
    /// @return Pending unstake amount
    function getPendingUnstake(address provider) external view returns (uint256);

    /// @notice Check if unstake is available
    /// @param provider Provider address
    /// @return bool True if 7 days have passed since request
    function canUnstake(address provider) external view returns (bool);

    /// @notice Get placement boost based on tier
    /// @param provider Provider address
    /// @return boost Boost multiplier in basis points
    function getPlacementBoost(address provider) external view returns (uint256);

    /// @notice Get insurance pool balance
    /// @return uint256 Pool balance
    function getInsurancePoolBalance() external view returns (uint256);

    /// @notice Get total staked across all providers
    /// @return uint256 Total staked
    function getTotalStaked() external view returns (uint256);

    /// @notice Calculate required stake for tier
    /// @param tier Target tier
    /// @return Required stake amount
    function getRequiredStakeForTier(StakeTier tier) external pure returns (uint256);

    /// @notice Get slash history for provider
    /// @param provider Provider address
    /// @return Array of SlashEvent structs
    function getSlashHistory(address provider) external view returns (SlashEvent[] memory);

    /// @notice Get insurance payout history
    /// @return Array of InsurancePayout structs
    function getInsurancePayoutHistory() external view returns (InsurancePayout[] memory);

    /// @notice Check if provider is slashed to maximum
    /// @param provider Provider address
    /// @return bool True if at max slash cap
    function isMaxSlashed(address provider) external view returns (bool);

    /// @notice Event: Tokens staked
    /// @param provider Provider address
    /// @param amount Amount staked
    /// @param newTotal New total staked
    event Staked(
        address indexed provider,
        uint256 amount,
        uint256 newTotal
    );

    /// @notice Event: Unstake requested
    /// @param provider Provider address
    /// @param amount Amount requested
    /// @param availableAt Timestamp when unstake available
    event UnstakeRequested(
        address indexed provider,
        uint256 amount,
        uint256 availableAt
    );

    /// @notice Event: Unstake completed
    /// @param provider Provider address
    /// @param amount Amount unstaked
    event Unstaked(
        address indexed provider,
        uint256 amount
    );

    /// @notice Event: Unstake cancelled
    /// @param provider Provider address
    event UnstakeCancelled(address indexed provider);

    /// @notice Event: Provider slashed
    /// @param provider Provider address
    /// @param agentId Agent identifier
    /// @param amount Amount slashed
    /// @param penaltyPenalty Penalty basis points
    /// @param reason Reason
    event Slashed(
        address indexed provider,
        bytes32 indexed agentId,
        uint256 amount,
        uint256 penaltyPenalty,
        string reason
    );

    /// @notice Event: Insurance pool funded
    /// @param amount Amount contributed
    /// @param newBalance New pool balance
    event InsurancePoolFunded(
        uint256 amount,
        uint256 newBalance
    );

    /// @notice Event: Insurance payout made
    /// @param recipient Payout recipient
    /// @param amount Payout amount
    /// @param missionId Associated mission
    event InsurancePayout(
        address indexed recipient,
        uint256 amount,
        bytes32 indexed missionId
    );

    /// @notice Event: Tier changed
    /// @param provider Provider address
    /// @param oldTier Previous tier
    /// @param newTier New tier
    event TierChanged(
        address indexed provider,
        StakeTier oldTier,
        StakeTier newTier
    );

    /// @notice Event: Excess pool withdrawn
    /// @param recipient Recipient address
    /// @param amount Amount withdrawn
    event ExcessPoolWithdrawn(
        address indexed recipient,
        uint256 amount
    );
}
```

---

## Deployment Notes

### Contract Addresses (Base Mainnet - TBD)

| Contract | Proxy | Implementation |
|----------|-------|----------------|
| AGNTToken | `0x...` | `0x...` |
| AgentRegistry | `0x...` | `0x...` |
| MissionEscrow | `0x...` | `0x...` |
| ProviderStaking | `0x...` | `0x...` |

### Initialization Parameters

- **AGNTToken**: `name="Agent Network Token"`, `symbol="AGNT"`, `decimals=18`, `initialSupply=1_000_000_000e18`
- **AgentRegistry**: Owner = TimelockController
- **MissionEscrow**: USDC = `0x...` (Base USDC), AGNT = `0x...`
- **ProviderStaking**: Min stake = 1000e18, Unstake cooldown = 7 days

### Access Control

All contracts use `Ownable` + `RoleBasedAccessControl`:
- **Owner**: Protocol admin (upgrades, parameters)
- **Governance**: DAO (future)
- **Authorized**: MissionEscrow can slash AgentRegistry + ProviderStaking

### Integration Flow

```
Client → createMission() → MissionEscrow (USDC locked)
     → acceptMission() → AgentRegistry (reputation lookup)
     → deliverMission() → MissionEscrow (state = COMPLETED)
     → approveMission() → Release 50% to provider
                         → 7% to ProviderStaking (insurance)
                         → 3% to AGNT (burn)
     OR
     → disputeMission() → Resolution → slash() if lost
```
