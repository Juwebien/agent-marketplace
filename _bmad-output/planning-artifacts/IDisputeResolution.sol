// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDisputeResolution
 * @notice Dispute resolution interface for Agent Marketplace V1
 * @dev All resolution is objective and code-driven; no external arbiter in V1
 */
interface IDisputeResolution {
    // ============================================
    // Enums
    // ============================================

    enum DisputeWinner {
        NONE,
        CLIENT,
        PROVIDER,
        SPLIT
    }

    enum MissionStatus {
        CREATED,
        ACCEPTED,
        IN_PROGRESS,
        DELIVERED,
        DISPUTED,
        COMPLETED,
        CANCELLED
    }

    // ============================================
    // Core Functions
    // ============================================

    /**
     * @notice Opens a dispute for a mission
     * @dev Caller must be client or provider of the mission
     * @param missionId The ID of the mission to dispute
     *
     * Client triggers: within 24h of delivery
     * Provider triggers: if client silent 48h after delivery
     */
    function openDispute(uint256 missionId) external;

    /**
     * @notice Submits evidence as IPFS CID
     * @dev Evidence stored as event log only (gas optimization)
     *      Each party (client/provider) can submit once
     * @param missionId The ID of the mission
     * @param evidenceCID IPFS content hash of evidence ZIP
     */
    function submitEvidence(uint256 missionId, bytes32 evidenceCID) external;

    /**
     * @notice Resolves a disputed mission via multi-sig
     * @dev Only callable by multi-sig wallet (3/5 threshold)
     * @param missionId The ID of the mission
     * @param winner The winning party: CLIENT, PROVIDER, or SPLIT
     * @param reason Human-readable resolution reason
     */
    function resolveDispute(
        uint256 missionId,
        DisputeWinner winner,
        string calldata reason
    ) external;

    // ============================================
    // Query Functions
    // ============================================

    /**
     * @notice Returns the current dispute state for a mission
     * @param missionId The ID of the mission
     * @return disputed Whether the mission is disputed
     * @return disputeOpener Address that opened the dispute
     * @return disputeTimestamp When the dispute was opened
     * @return clientEvidenceCID Evidence submitted by client (bytes32(0) if none)
     * @return providerEvidenceCID Evidence submitted by provider (bytes32(0) if none)
     */
    function getDisputeState(uint256 missionId)
        external
        view
        returns (
            bool disputed,
            address disputeOpener,
            uint256 disputeTimestamp,
            bytes32 clientEvidenceCID,
            bytes32 providerEvidenceCID
        );

    /**
     * @notice Returns the deadline for multi-sig resolution
     * @param missionId The ID of the mission
     * @return Resolution deadline timestamp (7 days from dispute open)
     */
    function getDisputeDeadline(uint256 missionId) external view returns (uint256);

    // ============================================
    // Events
    // ============================================

    /**
     * @notice Emitted when a dispute is opened
     * @param missionId The ID of the disputed mission
     * @param opener Address that opened the dispute (client or provider)
     * @param timestamp Block timestamp when dispute was opened
     * @param reason Dispute trigger reason (e.g., "CLIENT_24H_WINDOW", "PROVIDER_48H_SILENCE")
     */
    event DisputeOpened(
        uint256 indexed missionId,
        address indexed opener,
        uint256 timestamp,
        string reason
    );

    /**
     * @notice Emitted when evidence is submitted
     * @param missionId The ID of the mission
     * @param submitter Address submitting evidence (client or provider)
     * @param evidenceCID IPFS content hash
     * @param timestamp Block timestamp of submission
     */
    event EvidenceSubmitted(
        uint256 indexed missionId,
        address indexed submitter,
        bytes32 evidenceCID,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a dispute is resolved
     * @param missionId The ID of the resolved mission
     * @param winner The winning party (CLIENT, PROVIDER, or SPLIT)
     * @param reason Human-readable resolution reason
     * @param timestamp Block timestamp of resolution
     */
    event DisputeResolved(
        uint256 indexed missionId,
        DisputeWinner winner,
        string reason,
        uint256 timestamp
    );

    /**
     * @notice Emitted when auto-resolution occurs
     * @param missionId The ID of the mission
     * @param resolver Auto-resolution rule triggered (e.g., "SLA_DEADLINE", "CLIENT_SILENCE")
     * @param winner The winning party
     */
    event DisputeAutoResolved(
        uint256 indexed missionId,
        string resolver,
        DisputeWinner winner
    );

    /**
     * @notice Emitted when insurance pool is claimed
     * @param missionId The ID of the mission
     * @param provider Address of provider who lost
     * @param claimAmount Amount claimed from insurance pool
     * @param remainingPool Balance of insurance pool after claim
     */
    event InsuranceClaimed(
        uint256 indexed missionId,
        address provider,
        uint256 claimAmount,
        uint256 remainingPool
    );

    /**
     * @notice Emitted when reputation is updated
     * @param provider Address of the provider
     * @param missionId The ID of the related mission
     * @param oldScore Previous reputation score
     * @param newScore New reputation score
     * @param reason Reason for update (e.g., "DISPUTE_WON", "DISPUTE_LOST", "SPLIT")
     */
    event ReputationUpdated(
        address indexed provider,
        uint256 indexed missionId,
        uint256 oldScore,
        uint256 newScore,
        string reason
    );
}

// ============================================
// Addition to MissionEscrow.sol
// ============================================

/*
Add these to your existing MissionEscrow.sol:

// --- Storage Additions ---
mapping(uint256 => bool) public missionDisputed;
mapping(uint256 => address) public disputeOpeners;
mapping(uint256 => uint256) public disputeTimestamps;
mapping(uint256 => bytes32) public clientEvidenceCIDs;
mapping(uint256 => bytes32) public providerEvidenceCIDs;

// --- Modifiers ---
modifier onlyDisputeWindow(uint256 missionId) {
    require(missionDisputed[missionId], "Mission not disputed");
    _;
}

modifier onlyMultiSig() {
    require(isMultiSig[msg.sender], "Caller not multi-sig");
    _;
}

// --- Function Implementations ---

function openDispute(uint256 missionId) external override {
    // Verify caller is client or provider
    // Check mission status is DELIVERED
    // Verify time window (client: 24h, provider: 48h silence)
    // Set missionDisputed[missionId] = true
    // Set disputeOpeners[missionId] = msg.sender
    // Set disputeTimestamps[missionId] = block.timestamp
    // Emit DisputeOpened(...)
}

function submitEvidence(uint256 missionId, bytes32 evidenceCID) external override {
    // Verify caller is client or provider
    // Verify mission is in DISPUTED state
    // Store CID in event log only (emit EvidenceSubmitted)
    // Map to clientEvidenceCIDs or providerEvidenceCIDs for lookup
}

function resolveDispute(
    uint256 missionId,
    DisputeWinner winner,
    string calldata reason
) external override onlyMultiSig {
    // Verify mission is disputed
    // Verify 7-day window not passed
    // Apply resolution based on winner:
    //   CLIENT: refund client, slash provider 10%, -15% rep
    //   PROVIDER: pay provider, +5% rep to provider, -1 rep to client
    //   SPLIT: 50/50 split, -5% rep to provider (no slash)
    // Emit DisputeResolved(...)
    // Update mission status to COMPLETED
}

function getDisputeState(uint256 missionId)
    external
    view
    override
    returns (
        bool disputed,
        address disputeOpener,
        uint256 disputeTimestamp,
        bytes32 clientEvidenceCID,
        bytes32 providerEvidenceCID
    )
{
    disputed = missionDisputed[missionId];
    disputeOpener = disputeOpeners[missionId];
    disputeTimestamp = disputeTimestamps[missionId];
    clientEvidenceCID = clientEvidenceCIDs[missionId];
    providerEvidenceCID = providerEvidenceCIDs[missionId];
}

function getDisputeDeadline(uint256 missionId) external view override returns (uint256) {
    return disputeTimestamps[missionId] + 7 days;
}

// --- Auto-Resolution Hooks ---
// Call these from your existing delivery/status functions:

function _checkAutoResolve(uint256 missionId) internal {
    // Rule 1: Provider doesn't deliver by SLA → auto client wins
    if (block.timestamp > slaDeadline[missionId] && missionStatus[missionId] == MissionStatus.IN_PROGRESS) {
        _autoResolveClientWins(missionId, "SLA_DEADLINE");
        return;
    }

    // Rule 2: Client silent 48h after delivery → auto provider wins
    if (missionStatus[missionId] == MissionStatus.DELIVERED && !missionDisputed[missionId]) {
        if (block.timestamp > deliveryTimestamps[missionId] + 48 hours) {
            _autoResolveProviderWins(missionId, "CLIENT_SILENCE");
            return;
        }
    }
}

function _autoResolveClientWins(uint256 missionId, string memory resolver) internal {
    // Full refund to client
    // Provider: -15% reputation, -10% stake slashed
    // Emit DisputeAutoResolved(missionId, resolver, DisputeWinner.CLIENT)
}

function _autoResolveProviderWins(uint256 missionId, string memory resolver) internal {
    // Full payment to provider
    // Provider: +5% reputation
    // Client: -1 reputation
    // Emit DisputeAutoResolved(missionId, resolver, DisputeWinner.PROVIDER)
}
*/
