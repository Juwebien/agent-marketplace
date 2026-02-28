# Token Distribution Contract Specification

## Overview

This document specifies the smart contract architecture for distributing the 100M AGNT token supply across all stakeholders, including vesting schedules, multisig wallets, and milestone-based release mechanisms.

---

## Canonical Distribution (100M Total)

| Category | Amount | Percentage | Release Schedule |
|----------|--------|------------|-----------------|
| Team + Advisors | 15M | 15% | 4-year vesting, 1-year cliff |
| Genesis Agents Fund | 20M | 20% | 6-month linear unlock, distributed by governance |
| Hackathon/Bounties | 15M | 15% | 12-month program budget, milestone-based |
| Protocol Treasury | 25M | 25% | Multi-sig 3/5, operations + insurance backstop |
| Community/Ecosystem | 25M | 25% | Airdrop + liquidity mining |
| **Total** | **100M** | **100%** | |

---

## Vesting Contract Interface

### TokenVesting.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting is Ownable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 cliffDuration;      // seconds
        uint256 vestingDuration;     // seconds total
        uint256 startTime;
        uint256 released;
        bool revocable;
        bool revoked;
    }

    bytes32[] public vestingScheduleIds;
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    IERC20 public token;

    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 cliffDuration,
        uint256 vestingDuration
    );
    event TokensReleased(bytes32 indexed scheduleId, uint256 amount);
    event VestingRevoked(bytes32 indexed scheduleId);

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliff,
        uint256 duration,
        bool revocable
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be > 0");
        require(duration > 0, "Duration must be > 0");

        bytes32 scheduleId = keccak256(
            abi.encodePacked(beneficiary, block.timestamp, vestingScheduleIds.length)
        );

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            cliffDuration: cliff,
            vestingDuration: duration,
            startTime: block.timestamp,
            released: 0,
            revocable: revocable,
            revoked: false
        });

        vestingScheduleIds.push(scheduleId);
        emit VestingScheduleCreated(scheduleId, beneficiary, amount, cliff, duration);
    }

    function release(bytes32 vestingScheduleId) external {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        require(schedule.beneficiary == msg.sender, "Not beneficiary");
        require(!schedule.revoked, "Vesting revoked");

        uint256 releasable = getVestedAmount(vestingScheduleId) - schedule.released;
        require(releasable > 0, "No tokens to release");

        schedule.released += releasable;
        token.safeTransfer(schedule.beneficiary, releasable);
        emit TokensReleased(vestingScheduleId, releasable);
    }

    function revoke(bytes32 vestingScheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasable = getVestedAmount(vestingScheduleId) - schedule.released;
        schedule.revoked = true;

        if (releasable > 0) {
            schedule.released += releasable;
            token.safeTransfer(schedule.beneficiary, releasable);
        }

        uint256 remaining = schedule.totalAmount - schedule.released;
        if (remaining > 0) {
            token.safeTransfer(owner(), remaining);
        }

        emit VestingRevoked(vestingScheduleId);
    }

    function getVestedAmount(bytes32 vestingScheduleId) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function getVestingScheduleCount() external view returns (uint256) {
        return vestingScheduleIds.length;
    }
}
```

---

## Multisig Setup

All significant wallets use Gnosis Safe with 3/5 threshold (any 3 of 5 signatures required).

### Signers (5 Core Team Members)
- TBD - CEO
- TBD - CTO
- TBD - Lead Engineer
- TBD - Product Lead
- TBD - Operations Lead

### Timelock Configuration
- **Treasury transactions >100k AGNT**: 24-hour delay
- **Treasury transactions ≤100k AGNT**: Immediate execution
- **Genesis Fund distributions**: Governance-approved (no timelock for efficiency)
- **Hackathon releases**: Milestone-based (see HackathonManager)

---

## Deployment Sequence

### Step 1: Deploy AGNTToken
- Mint 100M tokens to deployer address
- Transfer ownership to TimelockController (for future governance)

### Step 2: Deploy TokenVesting
- Pass AGNT token address in constructor
- Grant TokenVesting role to deployer

### Step 3: Transfer Allocations

#### Team Allocation (15M)
```
Transfer: 15M AGNT → TokenVesting contract
Action: Create individual vesting schedules per team member
- Cliff: 1 year (31,536,000 seconds)
- Duration: 4 years (12,614,400 seconds)
- Revocable: false (standard)
```

#### Genesis Agents Fund (20M)
```
Transfer: 20M AGNT → GenesisFund (Gnosis Safe 3/5)
Schedule: 6-month linear unlock from launch
Distribution: Governance vote required for each tranche
```

#### Hackathon/Bounties (15M)
```
Transfer: 15M AGNT → HackathonManager contract
Schedule: 12-month program budget
Release: Milestone-based (per hackathon/bounty event)
```

**HackathonManager.sol Interface:**
```solidity
contract HackathonManager is Ownable {
    struct Milestone {
        string name;
        uint256 allocation;
        bool released;
        bool approved;
    }

    mapping(uint256 => Milestone[]) public hackathonMilestones;
    uint256 public hackathonCount;

    function createHackathon(string calldata name, Milestone[] calldata milestones) external onlyOwner;
    function approveMilestone(uint256 hackathonId, uint256 milestoneIndex) external onlyOwner;
    function releaseMilestone(uint256 hackathonId, uint256 milestoneIndex) external onlyOwner;
    function getMilestoneCount(uint256 hackathonId) external view returns (uint256);
}
```

#### Protocol Treasury (25M)
```
Transfer: 25M AGNT → Treasury (Gnosis Safe 3/5)
Purpose: Operations + insurance backstop
Restrictions: >100k requires 24h timelock
```

#### Community/Ecosystem (25M)
```
Split:
- 10M AGNT → AirdropDistributor
- 15M AGNT → LiquidityMining contract
```

**AirdropDistributor.sol:**
```solidity
contract AirdropDistributor is Ownable {
    mapping(address => bool) public claimed;
    uint256 public airdropAmountPerUser;

    function setAirdropAmount(uint256 amount) external onlyOwner;
    function addToAirdrop(address[] calldata recipients) external onlyOwner;
    function claim() external;
    function batchClaim(address[] calldata recipients) external onlyOwner;
}
```

**LiquidityMining.sol:**
```solidity
contract LiquidityMining is Ownable {
    struct RewardPeriod {
        uint256 startTime;
        uint256 duration;
        uint256 rewardAmount;
    }

    RewardPeriod[] public rewardPeriods;
    mapping(address => uint256) public rewards;

    function addRewardPeriod(uint256 duration, uint256 rewardAmount) external onlyOwner;
    function claimRewards() external;
    function getRewardAmount(address user) external view returns (uint256);
}
```

---

## Security Considerations

1. **Access Control**: Only owner can create vesting schedules and initiate transfers
2. **Revocation**: Team vesting is not revocable; Hackathon milestones can be revoked by owner
3. **Pull over Push**: All releases use SafeERC20 to prevent reentrancy
4. **Timelock**: Treasury transactions >100k require 24h delay
5. **Monitoring**: All large transfers should trigger alerts

---

## Verification Checklist

- [ ] AGNTToken deployed with 100M supply
- [ ] TokenVesting deployed and configured
- [ ] All 5 team vesting schedules created
- [ ] GenesisFund Gnosis Safe deployed and funded
- [ ] HackathonManager deployed and funded
- [ ] Treasury Gnosis Safe deployed and funded
- [ ] AirdropDistributor deployed (10M)
- [ ] LiquidityMining deployed (15M)
- [ ] All multisig signers configured
- [ ] Timelock delays tested on staging
