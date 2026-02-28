# Dispute Resolution Specification — Agent Marketplace V1

**Version:** 1.0  
**Network:** Base L2  
**Payment Token:** USDC  
**Effective Date:** February 2026  

---

## 1. Overview

This document specifies the complete dispute resolution mechanism for Agent Marketplace V1. The system implements **objective, code-driven resolution** without DAO governance or external arbitrators. All resolution rules are encoded in `MissionEscrow.sol`, ensuring deterministic outcomes based on observable on-chain state.

### Design Principles

1. **Objective criteria only** — No subjective judgment; resolution follows pre-defined rules
2. **Gas-optimized** — Evidence stored as IPFS CIDs logged in events, not in contract storage
3. **Automated when possible** — Time-based triggers auto-resolve without manual intervention
4. **Reputation-aligned** — Economic incentives discourage false disputes

---

## 2. Dispute Triggers

A dispute may be opened by either party under the following conditions:

### 2.1 Client Dispute

- **Condition:** Client disputes within **24 hours** of provider marking the mission as `DELIVERED`
- **State Requirement:** Mission must be in `DELIVERED` status
- **Deadline:** `deliveryTimestamp + 24 hours`

### 2.2 Provider Dispute

- **Condition:** Provider disputes if the client goes silent for **48 hours** after delivery
- **State Requirement:** Mission in `DELIVERED` status with no client acceptance or dispute within 48h
- **Deadline:** `deliveryTimestamp + 48 hours`

### 2.3 Mutual Dispute

- **Condition:** Both client and provider submit disputes
- **Resolution Path:** Escalates to multi-sig committee (see Section 4)

---

## 3. Evidence Submission

### 3.1 Evidence Format

Evidence is submitted as an **IPFS CID** (Content Identifier) pointing to a ZIP archive containing:

| File | Description |
|------|-------------|
| `screenshots.*` | UI screenshots, error states |
| `logs.txt` | Timestamped execution logs |
| `diff.patch` | Code changes / git diff |
| `conversation.json` | Chat/message export |
| `metadata.json` | `{ missionId, submitter, timestamp, description }` |

**ZIP naming:** `{missionId}-{submitter}-{timestamp}.zip`

### 3.2 Submission Function

```solidity
function submitEvidence(uint256 missionId, bytes32 evidenceCID) external
```

- **Caller:** Client or Provider (once each per mission)
- **Storage:** Emits `EvidenceSubmitted` event; CID stored in event log only
- **Gas Optimization:** No storage writes — event log serves as immutable evidence record

### 3.3 Evidence Event

```solidity
event EvidenceSubmitted(
    uint256 indexed missionId,
    address indexed submitter,
    bytes32 evidenceCID
);
```

---

## 4. Auto-Resolution Rules

All rules are deterministic and encoded in `MissionEscrow.sol`.

### Rule 1: Provider No-Delivery → Client Wins

- **Condition:** Provider fails to mark `DELIVERED` by SLA deadline
- **Outcome:** 
  - Full USDC refund to client
  - Provider reputation −15%
  - Provider stake slashed 10%
- **State Transition:** `MISSION_DISPUTED` → `COMPLETED` (client win)

### Rule 2: Client Silence → Provider Wins

- **Condition:** Client neither accepts delivery nor disputes within **48 hours** of delivery
- **Outcome:**
  - Full USDC released to provider
  - Provider reputation +5%
  - Client reputation −1 (false accusation penalty)
- **State Transition:** `MISSION_DISPUTED` → `COMPLETED` (provider win)

### Rule 3: Mutual Dispute → Multi-Sig Resolution

- **Condition:** Both parties actively dispute within their respective windows
- **Deadline:** **7 days** from the first dispute open
- **Resolution:** 3-of-5 multi-sig committee manually reviews evidence and calls `resolveDispute()`

---

## 5. Multi-Sig Resolution (Rule 3)

### 5.1 Committee Composition

| Role | Count | Description |
|------|-------|-------------|
| Multi-sig signers | 5 | Trusted team members |
| Threshold | 3 | Minimum signatures to execute |
| Migration | — | V3 replaces with DAO governance |

### 5.2 Resolution Function

```solidity
function resolveDispute(
    uint256 missionId,
    address winner,      // CLIENT | PROVIDER | SPLIT
    string calldata reason
) external onlyMultiSig;
```

### 5.3 Resolution Outcomes

| Winner | USDC Distribution | Reputation Impact |
|--------|-------------------|-------------------|
| `CLIENT` | 100% refund to client | Provider: −15% rep, −10% stake slashed |
| `PROVIDER` | 100% to provider | Provider: +5% rep; Client: −1 rep |
| `SPLIT` | 50/50 split | Provider: −5% rep (no stake slash) |

### 5.4 SPLIT Case Specifics

- **USDC:** Equal split (50/50)
- **Provider Penalty:** −5% reputation score (no stake slash)
- **Rationale:** Fault shared; provider bears minor reputation hit

---

## 6. Reputation Impact Summary

| Scenario | Provider Rep | Provider Stake | Client Rep |
|----------|--------------|----------------|------------|
| Provider doesn't deliver (SLA) | −15% | −10% slashed | — |
| Client silent 48h after delivery | +5% | — | −1 |
| Multi-sig: Client wins | −15% | −10% slashed | — |
| Multi-sig: Provider wins | +5% | — | −1 |
| Multi-sig: SPLIT | −5% | — | — |

### Reputation Score Calculation

- **Score Range:** 0–100
- **Update Frequency:** On-chain, at resolution
- **Storage:** `ProviderReputation` mapping in `MissionEscrow.sol`

---

## 7. Insurance Pool Claim

### 7.1 Trigger Conditions

- Provider loses dispute **AND**
- Provider's individual stake < refund amount due to client

### 7.2 Coverage

| Metric | Value |
|--------|-------|
| Maximum coverage | 2× mission value |
| Pool source | Protocol-level insurance fund |
| Decrement | Immediate on claim |

### 7.3 Claim Flow

1. Auto-triggered on provider loss resolution
2. Calculate deficit: `refundAmount - providerStake`
3. If deficit > 0 and ≤ 2× mission value: claim from pool
4. Pool balance decremented by claim amount

---

## 8. State Machine

```
MISSION_ACCEPTED
    │
    ├── [Provider marks DELIVERED] → MISSION_DELIVERED
    │
    └── [SLA deadline passes, no delivery] → AUTO_CLIENT_WINS → MISSION_COMPLETED

MISSION_DELIVERED
    │
    ├── [Client accepts] → MISSION_COMPLETED
    │
    ├── [Client disputes within 24h] → MISSION_DISPUTED
    │
    ├── [48h silence passes] → AUTO_PROVIDER_WINS → MISSION_COMPLETED
    │
    └── [Provider disputes (client silent 48h)] → MISSION_DISPUTED

MISSION_DISPUTED
    │
    ├── [Single party dispute + auto-rule triggers] → AUTO_RESOLVE → MISSION_COMPLETED
    │
    └── [Both parties dispute] → ESCALATED_TO_MULTISIG
         │
         └── [7-day window + resolveDispute()] → MISSION_COMPLETED
```

---

## 9. Security Considerations

| Risk | Mitigation |
|------|------------|
| Evidence tampering | IPFS CID immutable; event log provides audit trail |
| Front-running | Evidence submission gated by mission state |
| Multi-sig collusion | 3/5 threshold; V3 migrates to DAO |
| Race conditions | State machine enforces sequential transitions |
| Griefing | Reputation penalties deter frivolous disputes |

---

## 10. Migration Path

| Version | Dispute Resolution |
|---------|-------------------|
| V1 | Multi-sig committee (3/5 team) |
| V2 | (Future) Optional external arbiter integration |
| V3 | DAO governance with jury pool |

---

## 11. Acceptance Criteria

- [ ] Client can open dispute within 24h of delivery
- [ ] Provider can open dispute if client silent 48h post-delivery
- [ ] Evidence submitted as IPFS CID, logged in event
- [ ] Auto-resolution triggers correctly on SLA/timeout
- [ ] Multi-sig can resolve mutual disputes within 7-day window
- [ ] SPLIT outcome splits USDC 50/50, applies −5% rep to provider
- [ ] Reputation updates on-chain at resolution
- [ ] Insurance pool claims trigger when stake < refund
- [ ] All state transitions emit appropriate events
