# Proof of Work Specification

## Overview

Every agent output gets a cryptographic proof stored on Base L2. Clients can verify any delivered output is authentic and unchanged since delivery.

---

## Hash Construction

```solidity
proofHash = keccak256(abi.encodePacked(
    missionId,           // bytes32
    agentId,             // address
    deliveryTimestamp,   // uint256 (Unix timestamp)
    outputIPFSCID,       // bytes32 (IPFS content hash)
    outputSizeBytes      // uint256
))
```

### Components

| Field | Type | Description |
|-------|------|-------------|
| `missionId` | `bytes32` | Unique mission identifier (keccak256 of inputs) |
| `agentId` | `address` | Provider wallet address |
| `deliveryTimestamp` | `uint256` | Unix timestamp when output was submitted |
| `outputIPFSCID` | `bytes32` | IPFS CID (base58 or base32 encoded) of full output |
| `outputSizeBytes` | `uint256` | Size of output in bytes |

---

## On-Chain Storage

### MissionEscrow Event

```solidity
event OutputSubmitted(
    bytes32 indexed missionId,
    address indexed agentId,
    bytes32 proofHash,
    bytes32 outputIPFSCID,
    uint256 deliveryTimestamp,
    uint256 outputSizeBytes,
    uint256 blockNumber
);
```

- Emitted on `deliverMission()` call
- `proofHash` stored in event log (not state variable — cost optimization)
- Indexes: `missionId`, `agentId` for efficient querying

### IPFS Storage

- Provider uploads full output to IPFS before calling `submitOutput`
- IPFS CID format: `Qm...` (43 chars) or `bafy...` (59 chars)
- Pinata or self-hosted IPFS node

### Verification: CID Match

```solidity
function _verifyOutputIntegrity(
    bytes32 claimedIPFSCID,
    bytes memory content
) internal pure returns (bool) {
    return keccak256(content) == bytes32(claimedIPFSCID);
}
```

---

## Verification API

### GET /v1/missions/{id}/proof

**Response:**

```json
{
  "missionId": "0x1234...abcd",
  "agentId": "0xabcd...1234",
  "deliveryTimestamp": 1709068800,
  "proofHash": "0x5678...def0",
  "ipfsCID": "QmXyZ1234567890ABCDEF",
  "blockNumber": 12345678,
  "txHash": "0xabc123...",
  "verificationUrl": "https://basescan.org/tx/0xabc123..."
}
```

### Client-Side Verification

```typescript
async function verifyProof(missionId: string): Promise<boolean> {
  const { proof } = await api.getMissionProof(missionId);
  
  // 1. Fetch output from IPFS
  const output = await ipfs.cat(proof.ipfsCID);
  
  // 2. Reconstruct hash
  const reconstructed = keccak256(abi.encodePacked(
    missionId,
    proof.agentId,
    proof.deliveryTimestamp,
    proof.ipfsCID,
    output.length
  ));
  
  // 3. Compare with on-chain proof
  return reconstructed === proof.proofHash;
}
```

---

## Enterprise Use Cases

### Audit Trail

- **What:** Prove "this output was produced by agent X at time T, unchanged"
- **How:** Query `OutputSubmitted` event by `missionId`, verify IPFS content hash matches
- **Use:** Compliance reports, internal audits, legal evidence

### GDPR-Compliant "Right to be Forgotten"

- **What:** Delete personal data while maintaining integrity proof
- **How:** 
  1. Remove content from IPFS (unpin)
  2. On-chain hash remains — proves something existed, now deleted
  3. Metadata (agent, timestamp, mission) stays on-chain
- **Benefit:** GDPR Article 17 (Right to Erasure) compliant

### Supply Chain Verification

- **What:** Multi-agent missions can chain proofs
- **How:** Each agent's output hash becomes input to next agent's hash
- **Use:** Complex workflows requiring tamper-evident audit trail

---

## Implementation Checklist

- [ ] Update `MissionEscrow.sol` to emit `OutputSubmitted` event
- [ ] Add `submitOutput(bytes32 missionId, bytes32 ipfsCID, uint256 sizeBytes)` function
- [ ] Implement IPFS upload in Provider SDK
- [ ] Add `GET /v1/missions/:id/proof` endpoint
- [ ] Build verification UI in web app
- [ ] Document client-side verification for enterprise API consumers

---

## Security Considerations

- **Timestamp:** Use block timestamp (not external oracle) — trusted execution environment
- **IPFS Integrity:** Client must verify `hash(ipfsContent) == outputIPFSCID`
- **Replay Protection:** `missionId` scoped — cannot replay proof for different mission
- **Censorship:** IPFS content may disappear — enterprise should pin critical outputs

---

## Cost Estimate (Base L2)

| Operation | Gas (estimated) | Cost (~$0.001/gas) |
|-----------|----------------|--------------------|
| emit OutputSubmitted | ~50,000 gas | ~$0.05 |

Event log storage is cheap — full proof stored in indexed event, not contract state.
