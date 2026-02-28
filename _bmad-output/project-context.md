# Agent Marketplace — Project Context for AI Agents

> **Purpose:** Critical rules and context for AI coding agents implementing this project. Read this BEFORE writing any code.
> **Last Updated:** 2026-02-28
> **Status:** Authoritative

---

## 0. TL;DR (Read First)

This is a **Web3 two-sided marketplace** for AI agents on **Base L2 (Ethereum)**. Before coding anything:
1. Payment token = **USDC** (missions). Staking/governance = **$AGNT** (ERC-20).
2. Smart contracts are the source of truth. API mirrors on-chain state — never the reverse.
3. V1 has NO TEE, NO fiat on-ramp (full crypto-native), NO SDK, NO pgvector matching. See scope below.
4. Tests are **non-negotiable** — no PR without passing tests.

---

## 1. Tech Stack (Exact Versions)

### Blockchain
| Tool | Version | Notes |
|------|---------|-------|
| Solidity | ^0.8.20 | UUPS proxy pattern for upgradability |
| Hardhat | latest | Test framework for contracts |
| OpenZeppelin | ^5.x | ERC-20, AccessControl, ReentrancyGuard, UUPS |
| Network | Base L2 (chainId 8453) | Testnet: Base Sepolia (chainId 84532) |
| RPC | Alchemy (primary) / Infura (fallback) | Configure via env |

### Backend
| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 22.x | LTS required |
| TypeScript | ^5.x | Strict mode ON |
| Fastify | ^4.x | NOT Express |
| PostgreSQL | 16 | + pgvector extension |
| Redis | 7.x | Sessions, rate limiting, BullMQ queues |
| BullMQ | latest | Background job processing |
| ethers.js | ^6.x | Blockchain interaction (NOT v5) |
| Prisma | latest | ORM for PostgreSQL |

### Frontend
| Tool | Version | Notes |
|------|---------|-------|
| Next.js | 14 (App Router) | NOT Pages Router |
| React | 18.x | |
| Wagmi | ^2.x | Web3 wallet integration |
| RainbowKit | latest | Wallet connect UI |
| Tailwind CSS | ^3.x | Styling |
| React Query | ^5.x | Server state |
| Zustand | latest | Client state |

### Infrastructure
| Tool | Notes |
|------|-------|
| k3s | Existing homelab cluster on mintrtx (192.168.3.139) |
| ArgoCD | GitOps — changes merged to main auto-deploy |
| Docker | Multi-stage builds, non-root user |
| IPFS / Pinata | Agent metadata, mission deliverables |
| Grafana + Prometheus | Monitoring (already deployed) |

---

## 2. Project Structure

```
agent-marketplace/
├── contracts/          # Hardhat — Solidity smart contracts
│   ├── src/
│   │   ├── AGNTToken.sol
│   │   ├── AgentRegistry.sol
│   │   ├── MissionEscrow.sol
│   │   └── ProviderStaking.sol
│   ├── test/           # Hardhat tests (*.test.ts)
│   ├── scripts/        # Deploy scripts
│   └── hardhat.config.ts
├── api/                # Fastify REST API
│   ├── src/
│   │   ├── routes/     # Route handlers (agents, missions, providers)
│   │   ├── services/   # Business logic
│   │   ├── db/         # Prisma schema + migrations
│   │   ├── indexer/    # Blockchain event listener (ethers.js → BullMQ → DB)
│   │   └── middleware/ # Auth, rate limiting, validation
│   └── test/           # Jest tests
├── web/                # Next.js 14 frontend
│   ├── app/            # App Router pages
│   ├── components/     # React components
│   └── lib/            # Wagmi config, utilities
├── sdk/                # TypeScript provider SDK (V1.5)
└── k8s/                # Kubernetes manifests
```

---

## 3. Smart Contract Rules (CRITICAL)

### 3.1 The Four Contracts

| Contract | Purpose | Key Constraint |
|----------|---------|---------------|
| `AGNTToken.sol` | ERC-20 utility token | 100M supply, 3% burn, burn only callable by protocol |
| `AgentRegistry.sol` | Agent identity + reputation | Only provider can update their agent; escrow can recordOutcome |
| `MissionEscrow.sol` | Payment lifecycle | Pull pattern for payments — never push |
| `ProviderStaking.sol` | Stake + slash mechanics | Only MissionEscrow can slash; 7-day timelock on unstake |

### 3.2 State Machine (MissionEscrow) — NEVER DEVIATE

```
CREATED → ACCEPTED → IN_PROGRESS → DELIVERED → COMPLETED
                                              ↘ DISPUTED → RESOLVED
CREATED → CANCELLED (before ACCEPTED)
ACCEPTED → REFUNDED (provider can't start)
```

**Invalid transitions must REVERT.** No shortcuts.

### 3.3 Fee Breakdown (CANONICAL — never change without DECISIONS.md update)

```
Mission total = 100%
├── Provider:       90%
├── Insurance Pool: 5%
├── AGNT Burn:      3%
└── Treasury:       2%
```

### 3.4 Solidity Rules
- **Reentrancy guard on all state-changing functions** (use OpenZeppelin `ReentrancyGuard`)
- **UUPS proxy pattern** — all contracts must be upgradeable
- **Pull over push** for all payments
- **No `transfer()` or `send()`** — use `call{value:}` with reentrancy guard
- **Event emitted for every state change** — indexer depends on this
- **No floating pragma** — use exact `^0.8.20`

### 3.5 Key Parameters (from DECISIONS.md — canonical)
- Minimum stake: **1,000 AGNT**
- Unstake timelock: **7 days**
- Slash penalty: **10%** of stake
- Auto-approve timeout: **48 hours** after delivery
- Dispute window: **24 hours** after delivery
- Dry run timeout: **5 minutes**
- Insurance payout cap: **2x mission value**

---

## 4. API Rules

### 4.1 Framework: Fastify (NOT Express)
- Use Fastify plugins, not Express middleware
- Schema validation via `fastify-type-provider-zod`
- All routes typed with Zod schemas

### 4.2 Authentication
- **Providers:** API Key (`amk_live_...`) + Wallet Signature (SIWE)
- **Clients:** JWT (1h expiry) issued on wallet sign
- **Never trust unverified wallet addresses**

### 4.3 API Versioning
- All endpoints prefixed `/v1/`
- Breaking changes = new version, old version deprecated with 3-month sunset

### 4.4 Error Handling Pattern
```typescript
// ALWAYS use this pattern
throw fastify.httpErrors.badRequest('Mission not found');
// NEVER return raw errors
```

### 4.5 Blockchain Indexer Architecture
- Service: `api/src/indexer/` — runs as separate process
- Pattern: `ethers.js` listener → validate event → `BullMQ` job → PostgreSQL write
- **Reorg handling:** Track block numbers, rollback up to 12 blocks on reorg detection
- **Retry:** BullMQ exponential backoff (3 retries, max 30s delay)
- **RPC failover:** `ALCHEMY_RPC_URL` primary, `INFURA_RPC_URL` fallback (env-configurable)
- **CRITICAL:** DB state must ALWAYS be derivable from on-chain state — if in doubt, re-index

---

## 5. Database Rules

### 5.1 Naming Conventions
- Tables: `snake_case` plural (`agents`, `missions`, `providers`)
- Columns: `snake_case`
- Enums: `UPPER_CASE` values
- Foreign keys: `{table}_id` format

### 5.2 Mission Status Enum (must match contract state machine exactly)
```sql
CREATE TYPE mission_status AS ENUM (
  'CREATED', 'ACCEPTED', 'IN_PROGRESS', 'DELIVERED',
  'COMPLETED', 'DISPUTED', 'RESOLVED', 'CANCELLED', 'REFUNDED'
);
```

### 5.3 Critical Indexes
```sql
-- Required for matching performance
CREATE INDEX agents_card_embedding_idx ON agents
  USING ivfflat (card_embedding vector_cosine_ops) WITH (lists = 100);

-- Required for mission queries
CREATE INDEX missions_status_idx ON missions(status);
CREATE INDEX missions_agent_id_idx ON missions(agent_id);
```

### 5.4 Migrations
- Use Prisma migrations only — never manual ALTER TABLE in production
- Every migration must be reversible (include down migration)
- Test migrations on staging before production

---

## 6. Frontend Rules

### 6.1 Next.js App Router (NOT Pages Router)
- All pages in `app/` directory
- Server components by default — client components only when needed (`'use client'`)
- Data fetching via React Query for client state, `fetch` in server components

### 6.2 Web3 Integration
- Wagmi v2 for all contract interactions
- RainbowKit for wallet connection UI
- Never store private keys client-side
- Always handle wallet disconnected state gracefully

### 6.3 Performance Requirements
- Agent card renders in `< 500ms`
- Search results within `< 1s`
- Mission creation flow `< 3s` end-to-end

---

## 7. Testing Requirements (NON-NEGOTIABLE)

### 7.1 Smart Contracts (Hardhat)
- **Target: 90% coverage minimum**
- Every function must have happy path + failure path tests
- Required test suites:
  - `AGNTToken.test.ts` — mint, burn, transfer, stake, slash
  - `AgentRegistry.test.ts` — register, update reputation, query
  - `MissionEscrow.test.ts` — full lifecycle (happy path + disputes + timeout + reorg)
  - `ProviderStaking.test.ts` — stake, unstake timelock, slash
  - `Integration.test.ts` — full E2E mission flow on local fork

### 7.2 API (Jest)
- Unit tests for all service functions
- Integration tests for all route handlers
- Mock blockchain calls in unit tests; use test fork for integration

### 7.3 Frontend (Playwright)
- E2E tests for critical paths:
  - Provider onboarding + agent listing
  - Client: search → hire → approve
  - Dispute flow

### 7.4 Test Command
```bash
# Contracts
cd contracts && npx hardhat test

# API
cd api && npm test

# E2E
cd web && npx playwright test

# All
make test
```

**A task is NEVER done until `make test` passes with no failures.**

---

## 8. V1 Scope — What EXISTS vs What DOESN'T

### ✅ V1 (Weeks 1-8)
- 4 smart contracts (AGNTToken, AgentRegistry, MissionEscrow, ProviderStaking)
- REST API: Agent CRUD + Mission lifecycle
- JWT + SIWE auth
- PostgreSQL schema + blockchain indexer (ethers.js → BullMQ)
- Minimal UI: agent listing (tag filter only), mission creation, provider dashboard
- Wallet connect (Wagmi + RainbowKit)

### 🔜 V1.5 (Weeks 9-16)
- TypeScript SDK
- pgvector semantic matching (Mission DNA)
- Dry run feature (10% price, 5-min timeout)
- Basic inter-agent hiring
- WebSocket real-time events
- Webhooks

### 🚫 NOT in V1 — Do Not Implement
- **TEE / Intel SGX / AWS Nitro** — V2 only
- **Fiat on-ramp (Stripe)** — V2 only
- **DAO governance** — V3 only
- **Guild smart contracts** — V2 only
- **Python SDK** — V1.5+
- **Cross-chain bridge** — V2 only
- **Exchange listing** — explicitly excluded
- **ZK proofs** — V2 only

---

## 9. Environment Variables

```bash
# Blockchain
ALCHEMY_RPC_URL=https://base-sepolia.g.alchemy.com/v2/...
INFURA_RPC_URL=https://base-sepolia.infura.io/v3/...
CHAIN_ID=84532  # Base Sepolia testnet

# Contracts (populated after deploy)
AGNT_TOKEN_ADDRESS=
AGENT_REGISTRY_ADDRESS=
MISSION_ESCROW_ADDRESS=
PROVIDER_STAKING_ADDRESS=

# Database
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# IPFS
PINATA_API_KEY=
PINATA_SECRET_KEY=

# Auth
JWT_SECRET=
JWT_EXPIRY=1h

# API
PORT=3000
NODE_ENV=development
```

---

## 10. Git & Deployment Rules

### Branch Strategy
- `main` — production (ArgoCD auto-deploys)
- `develop` — integration branch
- Feature branches: `feat/description`
- Fix branches: `fix/description`

### Commit Messages
```
feat: add mission escrow contract
fix: correct reputation calculation weights
test: add MissionEscrow dispute flow tests
docs: update API endpoint reference
```

### Pre-PR Checklist
- [ ] `make test` passes
- [ ] No TypeScript errors (`tsc --noEmit`)
- [ ] No ESLint errors
- [ ] Smart contract changes include updated tests
- [ ] Migrations are reversible

---

## 11. Key Decisions Reference

| Decision | Value | Source |
|----------|-------|--------|
| Token supply | 100M AGNT | DECISIONS.md |
| Protocol fee | 10% total | DECISIONS.md |
| Burn rate | 3% of fee | DECISIONS.md |
| Insurance pool | 5% of fee | DECISIONS.md |
| Treasury | 2% of fee | DECISIONS.md |
| Min stake | 1,000 AGNT | DECISIONS.md |
| Unstake timelock | 7 days | DECISIONS.md |
| Slash penalty | 10% | DECISIONS.md |
| Auto-approve | 48h | DECISIONS.md |
| Dispute window | 24h | DECISIONS.md |
| Matching model | sentence-transformers/all-MiniLM-L6-v2 (384-dim) | MASTER-v2.md |
| Embedding dims | 384 | MASTER-v2.md |

> **When in doubt:** `DECISIONS.md` > `MASTER-v2.md` > `PRD.md` > everything else.

---

## 12. Contacts & Resources

- **Canonical spec:** `_bmad-output/MASTER-v2.md`
- **PRD:** `_bmad-output/planning-artifacts/PRD.md`
- **Architecture:** `_bmad-output/planning-artifacts/architecture.md`
- **Decisions:** `_bmad-output/DECISIONS.md`
- **Smart contract spec:** `_bmad-output/planning-artifacts/smart-contracts-spec.md`
- **DB schema:** `_bmad-output/planning-artifacts/db-migrations-spec.md`
- **API spec:** `_bmad-output/planning-artifacts/api-sdk-spec.md`
- **Infra:** `_bmad-output/planning-artifacts/infra-spec.md`



---

## 13. Critical Anti-Patterns — Never Do This

### Solidity
- ❌ `transfer()` or `send()` for ETH — use `call{value:}` with reentrancy guard
- ❌ State changes after external calls (reentrancy vulnerability)
- ❌ `block.timestamp` for critical logic — miners can manipulate ±15s
- ❌ Hardcoded addresses — use constructor params + env config
- ❌ `tx.origin` for auth — use `msg.sender`
- ❌ Unbounded loops over arrays — gas limit risk

### TypeScript / Node.js
- ❌ `any` type — use proper types or `unknown`
- ❌ `require()` — use ES module `import`
- ❌ `.then()` chains — use `async/await`
- ❌ Catching errors silently — always log + rethrow or handle
- ❌ Storing secrets in code — always use env vars

### Database
- ❌ Raw SQL strings — use Prisma query builder
- ❌ Missing transaction wrapping on multi-table writes
- ❌ Updating DB before confirming on-chain transaction
- ❌ Not handling race conditions on mission state transitions

### Frontend
- ❌ Fetching in `useEffect` without React Query
- ❌ Client components for server-renderable content
- ❌ Direct contract calls without Wagmi hooks
- ❌ Showing wallet address without truncation

---

## 14. Source of Truth Hierarchy

When documentation conflicts, use this order:

1. `_bmad-output/DECISIONS.md` — **absolute canonical values**
2. `_bmad-output/MASTER-v2.md` — full tech spec
3. `_bmad-output/planning-artifacts/PRD.md` — product requirements
4. `_bmad-output/planning-artifacts/architecture.md` — architecture
5. Specific spec files (`smart-contracts-spec.md`, `api-sdk-spec.md`, etc.)

> If code contradicts DECISIONS.md, the code is wrong.



---

## Usage Guidelines

**For AI Agents:** Read this file BEFORE writing any code. Follow ALL rules exactly. When in doubt, prefer the more restrictive option. The source of truth hierarchy (section 14) resolves all conflicts.

**For Humans:** Keep this lean. Update when stack changes. Remove rules that become obvious over time.

*Last Updated: 2026-02-28 | Status: Complete*
