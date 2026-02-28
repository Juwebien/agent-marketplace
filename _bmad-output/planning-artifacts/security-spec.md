---
title: 'Security Architecture — Agent Marketplace'
slug: 'security-architecture'
created: '2026-02-27'
status: 'draft'
---

# Security Architecture — Agent Marketplace

**Version:** 1.0  
**Date:** 2026-02-27  
**Author:** Security Architecture  
**Status:** Draft — Pre-Audit

---

## 1. Executive Summary

This document defines the complete security architecture for Agent Marketplace V1 MVP, with V2 TEE roadmap. The architecture follows a **zero-trust model** where no component is implicitly trusted — every interaction is authenticated, authorized, and encrypted.

**Security Principles:**
1. **Defense in Depth** — Multiple layers of security controls
2. **Least Privilege** — Minimal permissions for every actor
3. **Trust but Verify** — On-chain verification for all critical actions
4. **Fail Secure** — Safe defaults, graceful degradation

---

## 2. Threat Model

### Top 5 Attack Vectors + Mitigations

| # | Attack Vector | Likelihood | Impact | Mitigation |
|---|--------------|------------|--------|------------|
| 1 | **Smart Contract Reentrancy** | High | Critical | `ReentrancyGuard` on all state-changing functions |
| 2 | **Provider Reputation Fraud** | Medium | High | On-chain reputation immutable, stake slash on fraud |
| 3 | **API Rate Limit Exhaustion** | High | Medium | Per-endpoint rate limiting + minimum stake barrier |
| 4 | **Mission Output Tampering** | Medium | High | Cryptographic hashing + IPFS + signed outputs |
| 5 | **Treasury Key Compromise** | Low | Critical | Multi-sig (3/5) + timelock |

### Additional Threats Considered

- **Front-Running:** Mission creation can be front-run by monitoring mempool → Use commit-reveal for sensitive missions (V1.5)
- **Oracle Manipulation:** If price feeds used → Use TWAP with staleness checks
- **Flash Loan Attacks:** Not applicable (no governance voting in V1)
- **Social Engineering:** Provider impersonation → Provider address verified on-chain, agent card links to wallet

---

## 3. Smart Contract Security

### 3.1 Reentrancy Guards

**Pattern:** Apply `ReentrancyGuard` to all state-changing functions that transfer value or modify critical state.

```solidity
// MissionEscrow.sol
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract MissionEscrow is ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
    bytes32 public constant ORACLE_ROLE = keccak256('ORACLE_ROLE');
    
    function createMission(bytes32 agentId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        // Implementation
    }
    
    function deliverMission(bytes32 missionId) 
        external 
        nonReentrant 
        onlyRole(ORACLE_ROLE) // Provider must be verified
    {
        // Implementation
    }
}
```

**All functions requiring guards:**
- `createMission()` — deposits funds
- `acceptMission()` — begins work
- `deliverMission()` — submits output
- `approveMission()` — releases 50%
- `disputeMission()` — initiates arbitration
- `slashProvider()` — penalizes provider

### 3.2 Access Control Roles

**Role Definition:**

| Role | Capability | Holders |
|------|------------|---------|
| `ADMIN` | Pause/unpause, upgrade proxy, role assignment | Multi-sig (3/5) |
| `ORACLE` | Record mission outcomes, trigger timeouts | Protocol (contract) |
| `PROVIDER` | Register agents, accept missions, deliver | Wallet addresses |
| `CLIENT` | Create missions, approve/dispute | Wallet addresses |

```solidity
// Role assignments in initialize()
function initialize() public initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, MULTISIG_ADDRESS);
    _grantRole(ORACLE_ROLE, address(this)); // SelfOracle
}
```

**Critical:** `DEFAULT_ADMIN_ROLE` should be revoked from deployer after setup.

### 3.3 Upgrade Strategy: UUPS Proxy Pattern

**Decision:** UUPS (Universal Upgradeable Proxy Standard) over immutable + migration.

**Rationale:**
- UUPS allows gas-efficient upgrades (single implementation slot)
- Enables bug fixes without migration overhead
- V1 will launch with upgradeable contracts, target immutability V2

```solidity
// Base contract for upgradeability
import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';

abstract contract MissionEscrow is 
    Initializable, 
    UUPSUpgradeable, 
    ReentrancyGuard, 
    Pausable, 
    AccessControl 
{
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(ADMIN_ROLE) 
    {}
}
```

**Upgrade Governance:**
- Upgrade requires `ADMIN_ROLE` (3/5 multi-sig)
- 48-hour timelock on upgrades
- Transparent proxy with upgrade admin = timelock controller

### 3.4 Emergency Pause Mechanism

**Pause Scope:**

| Function | Paused Behavior |
|----------|-----------------|
| `createMission()` | New missions blocked |
| `acceptMission()` | No new accepts |
| `deliverMission()` | Submissions blocked |
| `approveMission()` | No approvals (funds locked) |
| `disputeMission()` | Disputes still allowed (user protection) |

**Who Can Pause:**
- `ADMIN_ROLE` (3/5 multi-sig) — immediate pause
- Automated circuit breaker (future V1.5): >5 disputes in 1 hour

**Unpause:** Requires `ADMIN_ROLE` after manual review.

```solidity
function pause() external onlyRole(ADMIN_ROLE) {
    _pause();
}

function unpause() external onlyRole(ADMIN_ROLE) {
    _unpause();
}
```

### 3.5 On-Chain Rate Limiting

**Implementation:** Per-provider mission rate limit to prevent spam.

```solidity
mapping(address => uint256) public providerMissionsThisBlock;
uint256 public constant MAX_MISSIONS_PER_BLOCK = 10;

modifier withinRateLimit(address provider) {
    // Reset counter if block number changed
    // (simplified — in production use sliding window)
    require(
        providerMissionsThisBlock[provider] < MAX_MISSIONS_PER_BLOCK,
        'Rate limit exceeded'
    );
    _;
    providerMissionsThisBlock[provider]++;
}
```

**Parameters:**
- Max missions per block per provider: 10
- Adjustable via governance (future)

### 3.6 Audit Checklist (Top 10 Vectors)

Pre-mainnet audit must verify:

| # | Check | OWASP Reference | Severity |
|---|-------|-----------------|----------|
| 1 | Reentrancy guards on all value transfers | SC05 | Critical |
| 2 | Access control on administrative functions | SC01 | Critical |
| 3 | Integer overflow/underflow (use Solidity 0.8+) | SC08 | High |
| 4 | Unchecked external calls | SC06 | High |
| 5 | Input validation on all public functions | SC04 | High |
| 6 | Front-run protection on mission creation | SC03 | Medium |
| 7 | Denial of Service vectors | SC10 | Medium |
| 8 | Upgrade mechanism security | SC01 | High |
| 9 | Proxy initialization (initializer modifier) | SC01 | Critical |
| 10 | Access control upgrades | SC01 | Critical |

**Audit Partners:** Trail of Bits, OpenZeppelin, or Certora (budget-dependent)

---

## 4. API Security

### 4.1 Authentication: JWT + Wallet Signature (SIWE)

**Dual Authentication Model:**

```
┌─────────────────────────────────────────────────────────┐
│                    Client Authentication                │
├─────────────────────────────────────────────────────────┤
│  Standard Users: JWT (session) + Wallet Signature        │
│  Providers:    API Key + Wallet Signature (mission ops) │
└─────────────────────────────────────────────────────────┘
```

**Implementation:**

```typescript
// SIWE (Sign In With Ethereum) message
const SIWE_MESSAGE = (
  domain: string,
  address: string,
  nonce: string,
  statement: string
) => `${domain} wants you to sign in with your Ethereum account:
${address}

${statement}

URI: ${domain}
Version: 1
Chain ID: 8453 (Base)
Nonce: ${nonce}
Issued At: ${new Date().toISOString()}`;
```

**Authentication Flow:**

1. **User logs in with wallet**
2. **Backend generates SIWE message + nonce**
3. **User signs with wallet (EIP-191)**
4. **Backend verifies signature, issues JWT (1h expiry)**
5. **JWT contains: `{ sub: address, role: 'client' | 'provider', permissions }`**

**Provider API Key Flow:**

```typescript
// Provider operations require API key + signature
interface ProviderAuth {
  apiKey: string;           // Identifies provider
  signature: string;        // Signs mission operation
  missionId: bytes32;       // Scope to specific mission
  timestamp: number;        // Replay protection (5min window)
}

// Middleware verification
async function verifyProviderAuth(req: Request): Promise<boolean> {
  const { apiKey, signature, missionId, timestamp } = req.headers;
  
  // 1. Validate API key exists and is active
  const provider = await getProviderByApiKey(apiKey);
  if (!provider || !provider.active) return false;
  
  // 2. Check timestamp not expired
  if (Date.now() - timestamp > 5 * 60 * 1000) return false;
  
  // 3. Verify signature
  const message = `mission:${missionId}:${timestamp}`;
  const recovered = recoverAddress(hashMessage(message), signature);
  return recovered === provider.walletAddress;
}
```

### 4.2 Rate Limiting Per Endpoint

**Rate Limit Configuration:**

| Endpoint | Limit (requests/min) | Burst |
|----------|---------------------|-------|
| `GET /api/agents` | 60 | 100 |
| `POST /api/missions` | 10 | 20 |
| `POST /api/missions/:id/deliver` | 30 | 50 |
| `GET /api/missions/:id` | 120 | 200 |

**Implementation (Redis-based):**

```typescript
// Using express-rate-limit with Redis store
const rateLimiter = rateLimit({
  store: new RedisStore({
    prefix: 'rl:',
    client: redisClient
  }),
  keyGenerator: (req) => {
    // Rate limit by wallet address or API key
    return req.walletAddress || req.apiKey;
  },
  windowMs: 60 * 1000,
  max: (req) => ENDPOINT_LIMITS[req.path] || 60,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({ error: 'Rate limit exceeded' });
  }
});
```

### 4.3 Anti-Spam Mechanisms

**Minimum Stake to Create Agents:**
- Minimum: 100 $AGNT per agent listed
- Stake stored in `ProviderStaking.sol`
- Unstake requires 7-day timelock

**Minimum Deposit to Create Missions:**
- Minimum mission value: 10 $AGNT
- Discourages spam missions

**Implementation:**

```solidity
uint256 public constant MIN_STAKE_PER_AGENT = 100e18;  // 100 $AGNT
uint256 public constant MIN_MISSION_VALUE = 10e18;        // 10 $AGNT

function registerAgent(bytes32 agentId, string calldata ipfsHash) 
    external 
{
    uint256 stake = stakingContract.getStake(msg.sender);
    require(stake >= MIN_STAKE_PER_AGENT, 'Insufficient stake');
    // Register agent...
}

function createMission(bytes32 agentId) external payable {
    require(msg.value >= MIN_MISSION_VALUE, 'Mission value too low');
    // Create mission...
}
```

### 4.4 DDoS Protection Strategy

**Layered Defense:**

1. **Cloudflare / Edge Protection**
   - Rate limiting at edge
   - Bot detection + JavaScript challenge
   - IP reputation filtering

2. **API Gateway Layer**
   - Request validation + sanitization
   - Schema validation (Zod)
   - Request size limits (1MB max)

3. **Application Layer**
   - JWT expiry (1 hour)
   - Nonce-based request deduplication
   - Costlier operations (mission creation) have stricter limits

---

## 5. Mission Output Security (Proof of Work)

### 5.1 Output Hashing Scheme

**Hash Algorithm:** `keccak256(abi.encode(missionId, output, timestamp))`

```solidity
struct MissionOutput {
    bytes32 missionId;
    string outputCid;       // IPFS CID of full output
    bytes32 outputHash;     // keccak256 of actual output
    uint256 timestamp;
    address provider;
    bytes signature;        // Provider signature
}

function submitOutput(
    bytes32 missionId,
    string calldata outputCid,
    bytes32 outputHash,
    uint256 timestamp,
    bytes calldata signature
) external {
    // Verify provider signed the output
    bytes32 messageHash = keccak256(
        abi.encode(missionId, outputCid, outputHash, timestamp)
    );
    require(
        _verifySignature(messageHash, signature, provider),
        'Invalid signature'
    );
    
    // Store output reference
    outputs[missionId] = MissionOutput({
        missionId: missionId,
        outputCid: outputCid,
        outputHash: outputHash,
        timestamp: timestamp,
        provider: provider,
        signature: signature
    });
    
    emit OutputSubmitted(missionId, outputCid, outputHash);
}
```

### 5.2 Storage Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Output Storage                         │
├─────────────────────────────────────────────────────────┤
│  On-Chain:     MissionOutput (missionId, cid, hash)    │
│  Off-Chain:    Full output in IPFS (content-addressed) │
│  Client:       Downloads from IPFS, verifies hash      │
└─────────────────────────────────────────────────────────┘
```

**Why IPFS:**
- Content-addressed (integrity by default)
- Deduplication (cost efficiency)
- CDN-like delivery via Pinata/Filecoin

**Client Verification Flow:**

```typescript
async function verifyOutput(missionId: string, cid: string): Promise<boolean> {
  // 1. Fetch on-chain output record
  const onChainRecord = await escrowContract.getOutput(missionId);
  
  // 2. Download from IPFS
  const output = await ipfs.cat(cid);
  
  // 3. Verify hash matches
  const computedHash = keccak256(output);
  return computedHash === onChainRecord.outputHash;
}
```

### 5.3 Dispute Evidence

**Evidence Submission:**

```solidity
struct DisputeEvidence {
    bytes32 missionId;
    address submitter;  // Client or Provider
    string evidenceCid; // IPFS CID of evidence JSON
    uint256 timestamp;
}

function submitEvidence(bytes32 missionId, string calldata evidenceCid) 
    external 
{
    Mission storage mission = missions[missionId];
    require(
        msg.sender == mission.client || msg.sender == mission.provider,
        'Not authorized'
    );
    require(mission.state == MissionState.DISPUTED, 'Not disputed');
    
    evidence[missionId].push(DisputeEvidence({
        missionId: missionId,
        submitter: msg.sender,
        evidenceCid: evidenceCid,
        timestamp: block.timestamp
    }));
    
    emit EvidenceSubmitted(missionId, msg.sender, evidenceCid);
}
```

**Evidence JSON Schema:**

```json
{
  "missionId": "0x...",
  "type": "client_complaint | provider_defense",
  "description": "Detailed explanation",
  "artifacts": [
    {
      "name": "screenshot.png",
      "cid": "Qm..."
    }
  ],
  "timestamp": 1700000000
}
```

### 5.4 Tamper-Proof Delivery

**End-to-End Encryption Flow:**

```
Client                          Platform                       Provider
  │                                │                               │
  │──── 1. Generate AES key ────────>│                               │
  │                                │──── 2. Encrypt mission ───────>│
  │                                │                               │ (execute)
  │                                │<─── 3. Encrypt output ───────│
  │<─── 4. Decrypt output ────────│                               │
  │                                │                               │
```

**Implementation:**

```typescript
// Client-side encryption (Web Crypto API)
async function encryptMissionData(data: string, providerPublicKey: string) {
  // Generate ephemeral AES-256 key
  const aesKey = await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt', 'decrypt']
  );
  
  // Encrypt mission data with AES
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encryptedData = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    aesKey,
    new TextEncoder().encode(data)
  );
  
  // Encrypt AES key with provider's public key (ECDH)
  const providerKey = await crypto.subtle.importKey(
    'spki',
    hexToBytes(providerPublicKey),
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    []
  );
  
  const ephemeralKeyPair = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  );
  
  const sharedBits = await crypto.subtle.deriveBits(
    { name: 'ECDH', public: providerKey },
    ephemeralKeyPair.privateKey,
    256
  );
  
  const aesKeyBits = await crypto.subtle.exportKey('raw', aesKey);
  const encryptedKey = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: crypto.getRandomValues(new Uint8Array(12)) },
    await crypto.subtle.importKey('raw', sharedBits, 'AES-GCM', false, ['encrypt']),
    aesKeyBits
  );
  
  return {
    encryptedData: bytesToBase64(encryptedData),
    encryptedKey: bytesToBase64(encryptedKey),
    ephemeralPublicKey: bytesToBase64(await crypto.subtle.exportKey('spki', ephemeralKeyPair.publicKey)),
    iv: bytesToBase64(iv)
  };
}
```

---

## 6. V2 TEE Roadmap (Informational)

### 6.1 Which Agents Benefit from TEE

| Agent Type | TEE Benefit | Priority |
|------------|--------------|----------|
| **Data Processing** | Protect sensitive input data | High |
| **Financial Agents** | Protect API keys, credentials | Critical |
| **Enterprise Agents** | Client proprietary data | High |
| **Code Generation** | Protect prompts/IP | Medium |

### 6.2 Attestation Model

**Architecture:**

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Client    │────>│  Platform    │────>│    TEE       │
│              │     │  (Relay)     │     │  (Agent)     │
└──────────────┘     └──────────────┘     └──────────────┘
                           │                    │
                           │<── Attestation ─────┤
                           │     (Quote)        │
```

**Attestation Flow:**

1. **Agent Enclave Starts** → Generates signing keypair inside TEE
2. **Enclave Requests Attestation** → Intel SGX quote or Nitro report
3. **Platform Verifies Attestation** → Against trusted root certificates
4. **Platform Issues Session Token** → Only to verified enclaves
5. **All Agent Communication** → Signed by enclave key, verifiable

**AWS Nitro Enclaves (Recommended for V2):**

```typescript
// Nitro attestation verification
async function verifyNitroAttestation(attestationDoc: Buffer): Promise<boolean> {
  // 1. Parse Nitro attestation document
  const attestation = parseNitroAttestation(attestationDoc);
  
  // 2. Verify AWS Nitro certificate chain
  const rootCert = await fetchAWSNitroRootCert();
  if (!verifyCertificateChain(attestation.certificate, rootCert)) {
    return false;
  }
  
  // 3. Verify measurement matches expected agent hash
  const expectedMeasurement = getExpectedAgentMeasurement(attestation.agentId);
  if (attestation.measurement !== expectedMeasurement) {
    return false;
  }
  
  return true;
}
```

### 6.3 Transition Path: V1 → V2

| Phase | Timeline | Changes |
|-------|----------|---------|
| **V1** | Week 20 | Standard execution, no TEE |
| **V1.5** | Week 30 | Optional TEE for premium agents |
| **V2** | Week 40 | TEE required for all agents |

**Migration Strategy:**

1. **Parallel Operation** — TEE and non-TEE agents coexist
2. **Gradual Requirement** — New agents require TEE, existing agents have 6-month migration
3. **Verification Required** — Clients can filter for TEE-only agents

---

## 7. Operational Security

### 7.1 Key Management

**Treasury Multi-Sig Configuration:**

| Parameter | Value |
|-----------|-------|
| Threshold | 3 of 5 |
| Signers | CEO, CTO, 3 independent (or Gnosis Safe) |
| Timelock | 48 hours on all transactions |
| Maximum Transfer | 50,000 $AGNT / day |

**Key Hierarchy:**

```
┌─────────────────────────────────────────────────────────┐
│                    Key Management                        │
├─────────────────────────────────────────────────────────┤
│  Level 1: Hardware Wallets (Ledger)                    │
│    ├── Treasury (3/5 Gnosis Safe)                       │
│    └── Protocol Admin (3/5)                            │
│                                                          │
│  Level 2: Secrets Manager (AWS Secrets Manager)         │
│    ├── API Keys                                         │
│    ├── Database credentials                             │
│    └── Third-party integrations                         │
│                                                          │
│  Level 3: Environment Variables                        │
│    ├── Node env (non-secret config)                     │
│    └── Deploy credentials (CI/CD)                      │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Monitoring + Alerting

**On-Chain Events to Watch:**

| Event | Alert Threshold | Action |
|-------|----------------|--------|
| `ProviderSlashed` | Any | Page on-call |
| `MissionDisputed` | >5/hour | Investigate |
| `LargeWithdrawal` | >10,000 $AGNT | Verify manually |
| `RoleGranted` | ADMIN_ROLE | Audit log |
| `Paused` | Any | Page immediately |

**Dashboard Configuration (Grafana):**

```
- Mission volume (24h)
- Dispute rate (24h)
- Provider stake utilization
- Failed transaction rate
- API error rate by endpoint
- Latency (p50, p95, p99)
```

### 7.3 Incident Response Playbook

**Scenario: Smart Contract Bug Discovered**

| Step | Time | Action |
|------|------|--------|
| 1 | 0 min | Confirm bug severity |
| 2 | 5 min | Pause affected contracts (ADMIN_ROLE) |
| 3 | 15 min | Notify users (Twitter, Discord, email) |
| 4 | 1 hr | Assess fund exposure |
| 5 | 24 hr | Deploy fix (testnet → mainnet with timelock) |
| 6 | 48 hr | Unpause, resume operations |
| 7 | 72 hr | Post-mortem published |

**Emergency Contacts:**

- On-call: PagerDuty rotation
- Audit partner: 24-hour emergency line
- Legal: Critical vulnerability disclosure

### 7.4 Provider Reputation Fraud Detection

**Fraud Patterns:**

| Pattern | Detection |
|----------|-----------|
| **Self-mission farming** | Client/provider address correlation |
| **Fake mission completion** | Output hash + IPFS content verification |
| **Sybil attacks** | Minimum stake barrier, velocity checks |
| **Reputation wash trading** | Unusual provider-client pairs |

**Detection Implementation:**

```typescript
// Real-time fraud detection
async function detectFraud(mission: Mission): Promise<FraudAlert | null> {
  const clientHistory = await getMissionsByClient(mission.client);
  const providerHistory = await getMissionsByProvider(mission.provider);
  
  // Pattern 1: Same wallet for client/provider
  if (mission.client === mission.provider) {
    return { type: 'SAME_ADDRESS', severity: 'HIGH' };
  }
  
  // Pattern 2: Unusual completion speed
  if (mission.completionTime < 30 seconds) {
    return { type: 'FAST_COMPLETION', severity: 'MEDIUM' };
  }
  
  // Pattern 3: Repetitive client/provider
  const pairCount = clientHistory.filter(m => m.provider === mission.provider).length;
  if (pairCount > 10) {
    return { type: 'REPETITIVE_PAIR', severity: 'LOW' };
  }
  
  return null;
}
```

---

## 8. Compliance & Privacy

### 8.1 GDPR: On-Chain vs Off-Chain Data

**On-Chain (Immutable, Non-Deletable):**

| Data | Justification |
|------|---------------|
| Mission ID | Escrow state machine |
| Agent reputation scores | Protocol integrity |
| Provider stake amounts | Slashing mechanism |
| Transaction hashes | Financial record |

**Off-Chain (Deletable under GDPR):**

| Data | Storage | Retention |
|------|---------|-----------|
| Mission brief content | PostgreSQL | Mission + 90 days |
| Agent metadata (IPFS hash only on-chain) | IPFS + PostgreSQL | Provider deletes |
| Client email/contact | PostgreSQL | User requests deletion |
| API logs | Separate PII-free logs | 30 days |

**GDPR Implementation:**

```typescript
// Data export (Article 15)
async function exportUserData(address: string): Promise<UserDataPackage> {
  return {
    missions: await getMissionsByUser(address),
    agentListings: await getAgentsByProvider(address),
    // Excludes on-chain data (by design)
  };
}

// Data deletion (Article 17)
async function deleteUserData(address: string): Promise<void> {
  // Soft-delete in PostgreSQL (mark as deleted)
  await db.users.update(
    { address },
    { deleted: true, deletedAt: new Date() }
  );
  
  // Note: On-chain data cannot be deleted (by design)
  // This is disclosed in privacy policy
}
```

### 8.2 Mission Content Privacy

**Design Principle:** Client brief never stored on-chain, only hash.

```
Client Browser
     │
     │ 1. Hash brief locally: keccak256(brief)
     │ 2. Submit hash + encrypted brief to API
     ▼
Platform API (stores encrypted brief)
     │
     │ 3. Store brief in PostgreSQL (encrypted at rest)
     │ 4. Submit hash to blockchain
     ▼
Blockchain
     │ (only hash stored on-chain)
```

**Implementation:**

```typescript
// Client-side: hash mission brief before submission
const briefHash = keccak256(plaintextBrief);
// Send to contract: createMission(agentId, briefHash, encryptedBrief)
// Platform stores: { missionId, encryptedBrief, plaintextHash }
// On-chain stores: { missionId, briefHash }
```

### 8.3 KYC Requirements

| Version | KYC Requirement | Implementation |
|---------|-----------------|----------------|
| **V1** | None | Self-custody wallet only |
| **V1.5** | Optional for providers | Integration with Polygon ID or BrightID |
| **V2** | Optional enterprise | Dedicated enterprise onboarding flow |

**Rationale:**
- V1: Maximum decentralization, no friction
- V1.5: Lightweight identity for dispute resolution
- V2: Enterprise customers who require it

---

## 9. Security Summary

### Security Controls Matrix

| Layer | Control | Implementation |
|-------|---------|----------------|
| **Smart Contracts** | Reentrancy guards | OpenZeppelin ReentrancyGuard |
| | Access control | OpenZeppelin AccessControl |
| | Upgradeability | UUPS proxy pattern |
| | Pause mechanism | OpenZeppelin Pausable |
| | Rate limiting | Per-provider on-chain counter |
| **API** | Authentication | JWT + SIWE + API keys |
| | Rate limiting | Redis-based per-endpoint |
| | DDoS protection | Cloudflare + API Gateway |
| | Input validation | Zod schema validation |
| **Data** | Encryption in transit | TLS 1.3 |
| | Encryption at rest | AES-256 |
| | Mission data | Client-side E2E encryption |
| | Output verification | IPFS + hash + signature |
| **Operational** | Key management | 3/5 multi-sig |
| | Monitoring | Grafana + PagerDuty |
| | Incident response | 4-step playbook |

### V1 vs V2 Security Comparison

| Feature | V1 | V2 |
|---------|----|----|
| Agent execution | Standard VM | TEE (Nitro/SGX) |
| Mission data encryption | Client-side | TEE-encrypted |
| Identity | Wallet-only | Wallet + optional KYC |
| Treasury | 3/5 multi-sig | DAO governance |
| Compliance | Privacy policy | SOC2 Type II |

---

## 10. Open Questions & Recommendations

### Questions for Team

1. **Treasury threshold:** Is 3/5 optimal, or should we require 4/5?
2. **Pause automation:** Should disputes trigger auto-pause circuit breaker?
3. **TEE vendor:** Intel SGX or AWS Nitro for V2? (Nitro simpler for cloud providers)
4. **Dispute resolution:** Platform team (V1) or arbitration marketplace (V2)?

### Recommendations

1. **Pre-mainnet:** Complete at least one external audit (budget $15-30K)
2. **Bug bounty:** Launch with $50K bug bounty program (Immunefi or Hacken)
3. **Insurance:** Consider smart contract insurance (Nexus Mutual) for launch
4. **Monitoring:** 24/7 on-call rotation from day 1

---

## Appendix A: Contract Function Access Matrix

| Function | Role Required | Pause-Sensitive | Reentrancy Guard |
|----------|---------------|-----------------|------------------|
| `createMission` | CLIENT | Yes | Yes |
| `acceptMission` | PROVIDER | Yes | Yes |
| `deliverMission` | PROVIDER | Yes | Yes |
| `approveMission` | CLIENT | Yes | Yes |
| `disputeMission` | CLIENT | No | Yes |
| `timeoutMission` | ANY | No | Yes |
| `slashProvider` | ORACLE | No | Yes |
| `pause` | ADMIN | N/A | No |
| `unpause` | ADMIN | N/A | No |

---

## Appendix B: Security Test Cases

| ID | Test | Expected Result |
|----|------|-----------------|
| SEC-01 | Call `deliverMission` twice | Second call reverts (nonReentrant) |
| SEC-02 | Non-provider calls `acceptMission` | Reverts with AccessControl |
| SEC-03 | Create mission below minimum | Reverts with "Mission value too low" |
| SEC-04 | Submit output with invalid signature | Reverts with "Invalid signature" |
| SEC-05 | Front-run mission creation | Hash on-chain, content encrypted |
| SEC-06 | Pause then create mission | Reverts with "Pausable: paused" |

---

*Document Status: Draft — Review pending before audit engagement*
