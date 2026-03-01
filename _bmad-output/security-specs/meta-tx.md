# Meta-Transaction Relayer Spec (EIP-2771)

## Vue d'ensemble

Ce document spécifie le système de meta-transactions pour l'Agent Marketplace. Le système permet aux agents de soumettre des transactions sans payer de gas ETH directement — la treasury paie à leur place via un relayer.

**Standards applicables:**
- EIP-2771: Minimal Forwarder
- EIP-712: Typed Data Signing

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Agent Marketplace                                  │
│                                                                             │
│  ┌─────────┐    ┌──────────────┐    ┌──────────────────────────────────┐   │
│  │  Agent  │───▶│ Fastify      │───▶│ MinimalForwarder.sol             │   │
│  │ (signer)│    │ POST /relay  │    │ (EIP-2771 Trusted Forwarder)    │   │
│  └─────────┘    └──────────────┘    └──────────────┬───────────────────┘   │
│                                                    │                        │
│                     ┌─────────────────────────────▼───────────────────┐    │
│                     │           Target Contract                         │    │
│                     │  (hérite ERC2771Context)                          │    │
│                     │  - AgentRegistry                                   │    │
│                     │  - TaskManager                                     │    │
│                     │  - PaymentSplitter                                 │    │
│                     └───────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Treasury                                       │   │
│  │  - Wallet multisig (3/5)                                            │   │
│  │  - Balance: ETH pour gas                                             │   │
│  │  - Alert: Grafana si balance < 0.1 ETH                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    Open Relayer Network                               │   │
│  │  - ANYONE peut déployer un relayer compatible                       │   │
│  │  - Discovery via chain registry ou DNS                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flux de transaction

```
Agent signe (EIP-712)           Relayer soumet              Target Contract
     │                              │                              │
     │  {to, data, gasLimit}       │                              │
     │─────────────────────────────▶│                              │
     │                              │  forward(req)               │
     │                              │─────────────────────────────▶│
     │                              │                              │
     │                              │         msg.sender = req.from│
     │                              │         (via ERC2771)        │
     │                              │                              │
     │                              │         [execution]          │
     │                              │                              │
```

---

## MinimalForwarder.sol Integration

### Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

/**
 * @title MinimalForwarder (EIP-2771)
 * @dev Trusted forwarder pour meta-transactions
 * 
 * Le forwarder vérifie la signature du requester avant de forwarder
 * la transaction au contrat cible. Le contrat cible doit utiliser
 * ERC2771Context pour recover l'adresse du signer original.
 */
contract MinimalForwarder is MinimalForwarder {
    constructor() MinimalForwarder() {}
}
```

### Configuration des contrats cibles

Chaque contrat qui accepte des meta-transactions doit hériter de `ERC2771Context`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract AgentMarketplaceBase is ERC2771Context, Ownable {
    address public trustedForwarder;
    
    constructor(address _trustedForwarder) {
        trustedForwarder = _trustedForwarder;
    }
    
    function _msgSender() internal view override(Context, ERC2771Context) 
        returns (address sender) {
        // EIP-2771: trusted forwarder case
        if (msg.data.length >= 20 && trustedForwarder == msg.sender) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }
    
    function _msgData() internal view override(Context, ERC2771Context) 
        returns (bytes calldata) {
        if (msg.data.length >= 20 && trustedForwarder == msg.sender) {
            return msg.data[:msg.data.length - 20];
        }
        return super._msgData();
    }
}
```

###whitelist du trusted forwarder

```solidity
// Dans le contrat cible
mapping(address => bool) public isTrustedForwarder;

modifier onlyTrustedForwarder() {
    require(isTrustedForwarder[msg.sender], "Caller is not trusted forwarder");
    _;
}
```

---

## POST /relay Endpoint

### Request Format

```typescript
// POST /relay
// Content-Type: application/json
// Authorization: Bearer <api_key> (pour rate limiting par client)

interface RelayRequest {
  /** Adresse du contrat cible */
  to: string;
  
  /** Données calldata pour le contrat cible */
  data: string;
  
  /** Adresse du signer original (l'agent) */
  from: string;
  
  /** Nonce du forwarder pour ce signer */
  nonce: string;
  
  /** Gas maximum pour l'exécution */
  gas: string;
  
  /** Signature EIP-712 du request */
  signature: string;
}

interface RelayResponse {
  /** Hash de la transaction */
  txHash: string;
  
  /** Block number quand soumis */
  blockNumber: number;
  
  /** Statut */
  status: "submitted" | "failed";
}
```

### Signature EIP-712

```typescript
// Domain separator
const domain = {
  name: "MinimalForwarder",
  version: "0.0.1",
  chainId: 1,  // ou network.chainId
  verifyingContract: "0x..." // adresse MinimalForwarder
};

// Types EIP-712
const types = {
  ForwardRequest: [
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "value", type: "uint256" },
    { name: "gas", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "data", type: "bytes" }
  ]
};

// Signing
const sign = async (request: ForwardRequest, privateKey: string) => {
  const signature = await signTypedData(domain, types, request, privateKey);
  return signature;
};
```

### Validation côté serveur

```typescript
// Fastify route handler
app.post('/relay', async (request, reply) => {
  // 1. Rate limiting par API key
  const apiKey = request.headers.authorization?.replace('Bearer ', '');
  await rateLimiter.consume(apiKey);
  
  // 2. Validate request
  const { to, data, from, nonce, gas, signature } = request.body;
  
  // 3. Build ForwardRequest
  const req = {
    from,
    to,
    value: '0',
    gas: BigInt(gas),
    nonce: BigInt(nonce),
    data
  };
  
  // 4. Verify signature via MinimalForwarder
  const forwarder = new ethers.Contract(FORWARDER_ADDRESS, ForwarderABI, signer);
  const isValid = await forwarder.verify(req, signature);
  
  if (!isValid) {
    return reply.status(400).send({ error: 'Invalid signature' });
  }
  
  // 5. Execute
  const tx = await forwarder.execute(req, signature, {
    gasLimit: BigInt(gas) + 50000  // buffer pour overhead relayer
  });
  
  return reply.send({ txHash: tx.hash, status: 'submitted' });
});
```

### Rate Limiting

```typescript
// Configuration rate limiter
const rateLimiterConfig = {
  // Par API key / client
  limits: {
    // 100 req/min pour clients standards
    default: { tokensPerInterval: 100, interval: 'minute' },
    // 1000 req/min pour trusted clients
    trusted: { tokensPerInterval: 1000, interval: 'minute' }
  },
  // Identifier par IP + API key
  keyGenerator: (request) => `${request.ip}:${request.apiKey}`
};
```

### Max Gas

```typescript
const MAX_GAS_PER_RELAY = 500_000;  // 500k gas max par call

// Validation
if (BigInt(gas) > MAX_GAS_PER_RELAY) {
  return reply.status(400).send({ 
    error: `Gas exceeds maximum of ${MAX_GAS_PER_RELAY}` 
  });
}
```

---

## Fallback Mode (Direct Submission)

Si le relayer est indisponible (censure, downtime, congestion), l'agent peut soumettre directement via `eth_sendTransaction`.

### Différences clés

| Aspect | Via Relayer | Direct (Fallback) |
|--------|-------------|-------------------|
| Gas paid by | Treasury | Agent (ETH balance) |
| Signature | EIP-712 | Ethereum native |
| Nonce | Forwarder nonce | Wallet nonce |
| Latency | ~2-5s | ~10-30s |
| Retry logic | Relayer handles | Agent must handle |

### Implémentation fallback

```typescript
// L'agent détecte si le relayer est disponible
async function submitTransaction(
  to: string,
  data: string,
  options: {
    preferRelayer: boolean;
    maxRelayerAttempts: number;
  }
): Promise<string> {
  
  // Try relayer first
  if (options.preferRelayer) {
    for (let i = 0; i < options.maxRelayerAttempts; i++) {
      try {
        return await submitViaRelayer(to, data);
      } catch (err) {
        if (err.statusCode === 429) {  // Rate limited
          await sleep(1000 * (i + 1));
          continue;
        }
        // Other error - fallback to direct
        break;
      }
    }
  }
  
  // Fallback to direct submission
  return submitDirect(to, data);
}
```

---

## Heartbeat Protocol (Anti-Censorship)

### Principe

Le relayer publie un "heartbeat" toutes les 5 minutes contenant:
- Le hash de la mempool (ensemble des tx en attente)
- Le timestamp
- La signature du relayer

Si une transaction soumise n'est pas incluse dans 3 heartbeats consécutifs (15 min), cela constitue une **préuve de censure**.

### Publication heartbeat

```typescript
// Intervalle: 5 minutes
const HEARTBEAT_INTERVAL = 5 * 60 * 1000;

async function publishHeartbeat() {
  // Récupérer les transactions en attente
  const pendingTxs = await getPendingTransactions();
  
  // Calculer hash de la mempool
  const mempoolHash = keccak256(
    RLP.encode(pendingTxs.map(tx => tx.hash))
  );
  
  // Signer le heartbeat
  const heartbeat = {
    mempoolHash,
    timestamp: Date.now(),
    relayerAddress: relayerAddress
  };
  
  const signature = sign(heartbeat, relayerPrivateKey);
  
  // Publier sur IPFS + notification on-chain optionnelle
  await ipfs.publish({
    topic: '/agent-marketplace/heartbeats',
    message: { ...heartbeat, signature }
  });
  
  // Émettre evento chain (optionnel, pour rollups)
  await relayerContract.emitHeartbeat(mempoolHash, heartbeat.timestamp);
}

// Cron job
setInterval(publishHeartbeat, HEARTBEAT_INTERVAL);
```

### Vérification de censure

```typescript
interface Heartbeat {
  mempoolHash: string;
  timestamp: number;
  signature: string;
}

async function proveCensorship(
  txHash: string,
  heartbeats: Heartbeat[]
): Promise<CensorshipProof> {
  // Vérifier que la tx n'est dans aucun heartbeat
  const notInMempool = heartbeats.every(hb => 
    !hb.pendingTxHashes.includes(txHash)
  );
  
  // Vérifier le temps écoulé
  const submittedTime = await getTxSubmissionTime(txHash);
  const latestHeartbeat = heartbeats[heartbeats.length - 1];
  const timeSinceSubmission = latestHeartbeat.timestamp - submittedTime;
  
  const isCensored = notInMempool && timeSinceSubmission > 15 * 60 * 1000;
  
  return {
    txHash,
    isCensored,
    heartbeatsMissed: heartbeats.length,
    proof: isCensored ? generateZKP() : null
  };
}
```

### Format heartbeat IPFS

```json
{
  "relayer": "0x...",
  "mempoolHash": "0x...",
  "txCount": 42,
  "timestamp": 1706745600,
  "signature": "0x..."
}
```

---

## Open Relayer Interface

### Spécification minimale

Tout relayer compatible doit implémenter:

#### 1. Endpoint HTTP

```
POST /relay
Content-Type: application/json

{
  "to": "0x...",
  "from": "0x...",
  "data": "0x...",
  "gas": "500000",
  "nonce": "0",
  "signature": "0x..."
}
```

#### 2. Response

```typescript
// Success (200)
{
  "txHash": "0x...",
  "status": "submitted"
}

// Error (400)
{
  "error": "Invalid signature",
  "code": "INVALID_SIGNATURE"
}
```

#### 3. Configuration

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `MAX_GAS` | 500,000 | Gas maximum par transaction |
| `CHAIN_ID` | réseau cible | ID du réseau |
| `FORWARDER` | adresse | Adresse du MinimalForwarder |
| `VERSION` | "1.0.0" | Version du protocol |

#### 4. Health check

```
GET /health

200 OK
{
  "status": "healthy",
  "relayerAddress": "0x...",
  "version": "1.0.0"
}
```

### Discovery Mechanism

```typescript
// Option 1: Chain registry
contract RelayerRegistry {
  struct RelayerInfo {
    string endpoint;
    uint256 minGasPrice;
    bool isActive;
  }
  
  mapping(address => RelayerInfo) public relayers;
  
  function register(string endpoint) external;
  function deregister() external;
}

// Option 2: DNS TXT record
// _agent-relayer.example.com TXT "v1=relayer1=https://relayer1.io/relay&relayer2=https://..."
```

### Requirements minimaux

```
┌─────────────────────────────────────────────────────────────┐
│                  Open Relayer Requirements                   │
├─────────────────────────────────────────────────────────────┤
│  ✅ EIP-2771 compatible                                     │
│  ✅ Max gas: 500,000                                       │
│  ✅ Health endpoint /health                                 │
│  ✅ Rate limit: documented                                  │
│  ✅ No IP restriction                                       │
│  ✅ No signup required                                      │
│  ✅ Accept any valid ForwardRequest                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Treasury Management

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Treasury                                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Multisig Wallet (Gnosis Safe)                       │   │
│  │  - 3/5 signers                                       │   │
│  │  - Timelock: 24h                                     │   │
│  │  - Daily limit: 10 ETH                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Relayer Funding                                    │   │
│  │  - Auto-refill quand balance < threshold            │   │
│  │  - Max 5 ETH par refill                              │   │
│  │  - Cooldown: 1h entre refills                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Grafana

```yaml
# Alert: Relayer balance faible
- alert: RelayerLowBalance
  expr: |
    eth_balance{job="relayer"} < 0.1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Relayer {{ $labels.address }} balance low: {{ $value }} ETH"
    description: "Relayer needs ETH refill urgently"
```

### Script de refill automatique

```typescript
interface RefillConfig {
  relayerAddress: string;
  threshold: bigint;      // 0.1 ETH
  maxRefill: bigint;      // 5 ETH
  cooldown: number;       // 1 hour
}

async function checkAndRefill(config: RefillConfig) {
  const balance = await provider.getBalance(config.relayerAddress);
  
  if (balance >= config.threshold) {
    return { action: 'none', balance };
  }
  
  // Check cooldown
  const lastRefill = await getLastRefillTime(config.relayerAddress);
  if (Date.now() - lastRefill < config.cooldown) {
    return { action: 'cooldown', remaining: config.cooldown - (Date.now() - lastRefill) };
  }
  
  // Execute refill
  const refillAmount = config.maxRefill;
  const tx = await treasury.sendTransaction({
    to: config.relayerAddress,
    value: refillAmount
  });
  
  return { action: 'refilled', amount: refillAmount, txHash: tx.hash };
}
```

### Monitoring Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│              Relayer Treasury Dashboard                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Balance: ████████████████░░░░ 2.5 ETH / 5 ETH              │
│                                                             │
│  Transactions: 1,247 today                                  │
│  Avg Gas: 45,000 gas                                        │
│  Success Rate: 99.8%                                        │
│                                                             │
│  Alerts: 🔴 Low balance (2h ago)                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Considérations de sécurité

### Attaques atténuées

| Menace | Mitigation |
|--------|------------|
| **Replay attack** | Nonce par signer dans MinimalForwarder |
| **Front-running** | Pas deordnung dans le mempool public |
| **Signature theft** | `from` address embedded dans request |
| **Gas griefing** | Limite gas max 500k |
| **Relay jamming** | Rate limiting par IP + API key |
| **Censorship** | Heartbeat protocol + fallback direct |

### Points de confiance

```
┌─────────────────────────────────────────────────────────────┐
│              Trust Model                                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ✋ TRUSTER: MinimalForwarder.sol                           │
│    - Doit être de confiance (trustless forwarder EIP-2771) │
│    - Vérifie signature avant execution                     │
│                                                             │
│  ✋ TRUSTER: Relayer Service                                │
│    - Peut censurer (anti-censorship: heartbeat proof)      │
│    - Paie le gas (treasury funds)                           │
│    - Pas de données utilisateur sensibles                   │
│                                                             │
│  ✅ TRUSTLESS: Agent (signer)                               │
│    - Signe ses propres transactions                        │
│    - Peut fallback en direct si besoin                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Déploiement

### Configuration .env

```bash
# Relayer
RELAYER_PRIVATE_KEY=0x...                    # Hot wallet pour soumettre
TRUSTED_FORWARDER=0x...                      # MinimalForwarder address
MAX_GAS_LIMIT=500000

# Treasury
TREASURY_ADDRESS=0x...
AUTO_REFILL_THRESHOLD=0.1                   # ETH
AUTO_REFILL_MAX=5                            # ETH
AUTO_REFILL_COOLDOWN=3600                    # seconds

# Rate limiting
RATE_LIMIT_TOKENS=100
RATE_LIMIT_INTERVAL=60                      # seconds
```

### Smart Contracts Addresses (Mainnet)

```typescript
export const contracts = {
  mainnet: {
    MinimalForwarder: "0x...",
    AgentRegistry: "0x...",
    TaskManager: "0x...",
  },
  sepolia: {
    MinimalForwarder: "0x...",  // à déployer
    AgentRegistry: "0x...",
    TaskManager: "0x...",
  }
};
```
