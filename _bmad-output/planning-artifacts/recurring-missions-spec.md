# Recurring Missions Specification

**Version:** 1.0  
**Date:** 2026-02-27  
**Status:** Draft  
**Feature:** F12 — Cron-style Scheduled Agent Calls

---

## 1. Overview

### 1.1 Purpose

Recurring missions transform the Agent Marketplace from a reactive on-demand service into proactive team infrastructure. Clients schedule automated agent calls at defined intervals, enabling:

- **CI/CD integration** — scheduled security audits, code reviews
- **Operational monitoring** — daily log analysis, anomaly detection  
- **Periodic reporting** — weekly summaries, changelog generation
- **Compliance automation** — scheduled compliance checks

### 1.2 Relationship to Core Product

Recurring missions build upon existing V1 MVP infrastructure:

- **MissionEscrow.sol** — payment handling (extended with pre-authorization)
- **Agent Registry** — agent selection and reputation
- **Mission state machine** — each run creates a standalone mission with full escrow lifecycle
- **USDC payments** — stablecoin for predictable budgeting

### 1.3 Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Scheduler latency | <60 seconds (cron precision) |
| Run history retention | 90 days |
| Max active recurring missions per client | 50 |
| Template variables supported | 10+ |
| Retry attempts | 3 |
| Max retry delay | 1 hour |

---

## 2. Data Model

### 2.1 Core Tables

```sql
-- Main recurring mission configuration
CREATE TABLE recurring_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    agent_id UUID NOT NULL REFERENCES agents(id),
    
    -- Mission template (the brief that gets executed each run)
    mission_template JSONB NOT NULL,
    
    -- Scheduling configuration
    cron_expression TEXT NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    
    -- Budget and limits
    budget_per_run_usdc NUMERIC(18,6) NOT NULL,
    max_runs INTEGER, -- null = unlimited
    estimated_total_runs INTEGER, -- for pre-auth calculation
    
    -- Execution tracking
    runs_completed INTEGER NOT NULL DEFAULT 0,
    runs_failed INTEGER NOT NULL DEFAULT 0,
    
    -- State
    active BOOLEAN NOT NULL DEFAULT true,
    pause_reason TEXT, -- 'USER_REQUESTED', 'BUDGET_DEPLETED', 'AGENT_UNAVAILABLE', 'FAILURE_THRESHOLD'
    next_run_at TIMESTAMPTZ,
    last_run_at TIMESTAMPTZ,
    
    -- Pre-authorization
    preauthorized BOOLEAN NOT NULL DEFAULT false,
    preauthorization_id TEXT, -- escrow pre-auth reference
    
    -- Metadata
    name TEXT NOT NULL, -- "Weekly security audit"
    description TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Individual execution records
CREATE TABLE recurring_mission_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_mission_id UUID NOT NULL REFERENCES recurring_missions(id) ON DELETE CASCADE,
    
    -- The actual mission created for this run
    mission_id UUID REFERENCES missions(id),
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL,
    triggered_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Status
    status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING, TRIGGERED, RUNNING, COMPLETED, FAILED, SKIPPED
    failure_reason TEXT, -- AGENT_UNAVAILABLE, BUDGET_DEPLETED, TIMEOUT, ESCROW_FAILED
    
    -- Retry tracking
    retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    
    -- Output (IPFS reference after completion)
    output_cid TEXT,
    output_size_bytes INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pre-authorization for recurring payments
CREATE TABLE recurring_mission_preauthorizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    
    -- Smart contract reference
    transaction_hash TEXT NOT NULL,
    block_number BIGINT NOT NULL,
    
    -- Authorization details
    max_total_usdc NUMERIC(18,6) NOT NULL,
    per_run_limit_usdc NUMERIC(18,6) NOT NULL,
    agent_id UUID NOT NULL REFERENCES agents(id),
    
    -- Tracking
    amount_used_usdc NUMERIC(18,6) NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Template variables configuration
CREATE TABLE recurring_mission_variables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_mission_id UUID NOT NULL REFERENCES recurring_missions(id) ON DELETE CASCADE,
    
    variable_name TEXT NOT NULL, -- 'repo', 'branch', 'environment'
    variable_type TEXT NOT NULL, -- 'static', 'dynamic', 'env_var'
    value TEXT NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 2.2 Indexes

```sql
-- Scheduler queries
CREATE INDEX idx_recurring_missions_next_run 
ON recurring_missions(next_run_at) 
WHERE active = true;

CREATE INDEX idx_recurring_mission_runs_recurring_mission 
ON recurring_mission_runs(recurring_mission_id, scheduled_at DESC);

CREATE INDEX idx_recurring_mission_runs_status 
ON recurring_mission_runs(status) 
WHERE status IN ('PENDING', 'TRIGGERED', 'RUNNING');

-- Client queries
CREATE INDEX idx_recurring_missions_client 
ON recurring_missions(client_id, created_at DESC);
```

### 2.3 Mission Template Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["title", "description"],
  "properties": {
    "title": {
      "type": "string",
      "maxLength": 200
    },
    "description": {
      "type": "string",
      "maxLength": 5000
    },
    "context": {
      "type": "object",
      "properties": {
        "repoUrl": { "type": "string", "format": "uri" },
        "branch": { "type": "string" },
        "environment": { "type": "string" },
        "customContext": { "type": "object" }
      }
    },
    "requirements": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "maxItems": 20
    },
    "attachments": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "cid": { "type": "string" },
          "mimeType": { "type": "string" }
        }
      }
    },
    " sla": {
      "type": "object",
      "properties": {
        "deadlineMinutes": { "type": "integer", "minimum": 5 },
        "priority": { "type": "string", "enum": ["LOW", "NORMAL", "HIGH", "URGENT"] }
      }
    }
  }
}
```

---

## 3. API Endpoints

### 3.1 Create Recurring Mission

```
POST /api/v1/missions/recurring
Authorization: Bearer <client_jwt>
```

**Request Body:**

```json
{
  "name": "Weekly security audit",
  "agentId": "550e8400-e29b-41d4-a716-446655440000",
  "missionTemplate": {
    "title": "Security audit for {{repo}}",
    "description": "Review {{repo}} for vulnerabilities. Week {{week}} of {{year}}.",
    "context": {
      "repoUrl": "https://github.com/acme/webapp"
    },
    "requirements": [
      "Check for known CVEs in dependencies",
      "Review PR security patterns",
      "Report findings in JSON format"
    ],
    "sla": {
      "deadlineMinutes": 120,
      "priority": "HIGH"
    }
  },
  "cronExpression": "0 9 * * 1",
  "timezone": "America/New_York",
  "budgetPerRunUsdc": 25.00,
  "maxRuns": 52,
  "preauthorize": true
}
```

**Response (201 Created):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "clientId": "770e8400-e29b-41d4-a716-446655440000",
  "agentId": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Weekly security audit",
  "missionTemplate": { ... },
  "cronExpression": "0 9 * * 1",
  "timezone": "America/New_York",
  "budgetPerRunUsdc": "25.00",
  "maxRuns": 52,
  "runsCompleted": 0,
  "runsFailed": 0,
  "active": true,
  "nextRunAt": "2026-03-02T14:00:00Z",
  "preauthorized": false,
  "createdAt": "2026-02-27T23:45:00Z"
}
```

**Validation Rules:**

| Field | Rule |
|-------|------|
| `cronExpression` | Must be valid cron (5 fields), max interval 1 minute, min interval 1 hour |
| `budgetPerRunUsdc` | Min $1, max $10,000 per run |
| `maxRuns` | Optional, max 365 for yearly, null = unlimited |
| `name` | Max 100 chars, unique per client |
| `missionTemplate` | Must pass JSON schema validation |

### 3.2 List Client's Recurring Missions

```
GET /api/v1/missions/recurring
Authorization: Bearer <client_jwt>
```

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `limit` | integer | 20 | Items per page (max 50) |
| `active` | boolean | null | Filter by active status |
| `agentId` | uuid | null | Filter by agent |

**Response (200 OK):**

```json
{
  "data": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "Weekly security audit",
      "agentId": "550e8400-e29b-41d4-a716-446655440000",
      "agentName": "SecurityExpert-v2",
      "cronExpression": "0 9 * * 1",
      "timezone": "America/New_York",
      "budgetPerRunUsdc": "25.00",
      "runsCompleted": 4,
      "runsFailed": 0,
      "active": true,
      "nextRunAt": "2026-03-02T14:00:00Z",
      "lastRunAt": "2026-02-23T14:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 3,
    "totalPages": 1
  }
}
```

### 3.3 Get Recurring Mission Details

```
GET /api/v1/missions/recurring/:id
Authorization: Bearer <client_jwt>
```

**Response (200 OK):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "clientId": "770e8400-e29b-41d4-a716-446655440000",
  "agentId": "550e8400-e29b-41d4-a716-446655440000",
  "agentName": "SecurityExpert-v2",
  "name": "Weekly security audit",
  "missionTemplate": { ... },
  "cronExpression": "0 9 * * 1",
  "timezone": "America/New_York",
  "timezoneOffset": "-05:00",
  "budgetPerRunUsdc": "25.00",
  "maxRuns": 52,
  "estimatedTotalBudgetUsdc": "1300.00",
  "runsCompleted": 4,
  "runsFailed": 0,
  "active": true,
  "pauseReason": null,
  "nextRunAt": "2026-03-02T14:00:00Z",
  "lastRunAt": "2026-02-23T14:00:00Z",
  "preauthorized": false,
  "preauthorizationId": null,
  "createdAt": "2026-02-27T23:45:00Z",
  "updatedAt": "2026-02-27T23:45:00Z",
  "nextFiveRuns": [
    "2026-03-02T14:00:00Z",
    "2026-03-09T14:00:00Z",
    "2026-03-16T14:00:00Z",
    "2026-03-23T14:00:00Z",
    "2026-03-30T14:00:00Z"
  ]
}
```

### 3.4 Update Recurring Mission

```
PUT /api/v1/missions/recurring/:id
Authorization: Bearer <client_jwt>
```

**Request Body (partial updates supported):**

```json
{
  "name": "Weekly security audit (expanded)",
  "cronExpression": "0 8 * * 1",
  "timezone": "America/Los_Angeles",
  "budgetPerRunUsdc": 30.00,
  "missionTemplate": {
    "title": "Expanded security audit"
  }
}
```

**Special Actions:**

```json
{
  "action": "pause",
  "reason": "USER_REQUESTED"
}
```

```json
{
  "action": "resume"
}
```

```json
{
  "action": "trigger_now"
}
```

**Response (200 OK):**

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "updatedAt": "2026-02-27T23:50:00Z",
  "message": "Recurring mission updated"
}
```

### 3.5 Delete/Cancel Recurring Mission

```
DELETE /api/v1/missions/recurring/:id
Authorization: Bearer <client_jwt>
```

**Response (204 No Content)**

Cancels the recurring mission. In-flight runs complete normally. Pre-authorization remains until explicitly revoked.

### 3.6 Get Run History

```
GET /api/v1/missions/recurring/:id/runs
Authorization: Bearer <client_jwt>
```

**Query Parameters:**

| Param | Type | Default |
|-------|------|---------|
| `page` | integer | 1 |
| `limit` | integer | 20 |
| `status` | string | null (all) |

**Response (200 OK):**

```json
{
  "data": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440001",
      "recurringMissionId": "660e8400-e29b-41d4-a716-446655440001",
      "missionId": "990e8400-e29b-41d4-a716-446655440001",
      "scheduledAt": "2026-02-23T14:00:00Z",
      "triggeredAt": "2026-02-23T14:00:00.012Z",
      "startedAt": "2026-02-23T14:00:01Z",
      "completedAt": "2026-02-23T14:15:00Z",
      "status": "COMPLETED",
      "retryCount": 0,
      "outputCid": "QmHash...",
      "outputSizeBytes": 15360
    }
  ],
  "pagination": { ... }
}
```

### 3.7 Get Run Output

```
GET /api/v1/missions/recurring/:id/runs/:runId/output
Authorization: Bearer <client_jwt>
```

Returns the IPFS-stored output content. Supports range requests for large outputs.

### 3.8 Pre-authorize Budget

```
POST /api/v1/missions/recurring/:id/preauthorize
Authorization: Bearer <client_jwt>
```

**Request Body:**

```json
{
  "maxTotalUsdc": 500.00,
  "perRunLimitUsdc": 25.00
}
```

**Response (200 OK):**

```json
{
  "preauthorizationId": "preauth_1234567890",
  "transactionHash": "0x...",
  "maxTotalUsdc": "500.00",
  "perRunLimitUsdc": "25.00",
  "status": "PENDING_CONFIRMATION"
}
```

Client must complete the on-chain transaction. Webhook notifies when confirmed.

---

## 4. Scheduler Service

### 4.1 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Scheduler Service                     │
│                  (Node.js + Bull Queue)                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │ Cron Scanner │───▶│ Run Creator  │───▶│ Notifier  │ │
│  │ (every 30s)  │    │              │    │           │ │
│  └──────────────┘    └──────────────┘    └───────────┘ │
│         │                   │                   │        │
│         ▼                   ▼                   ▼        │
│  ┌─────────────────────────────────────────────────────┐│
│  │              PostgreSQL Database                    ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│               Mission Execution Pipeline                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐ │
│  │  Escrow  │───▶│  Agent   │───▶│ Output + Scoring │ │
│  │  Create  │    │  Execute │    │                  │ │
│  └──────────┘    └──────────┘    └──────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Scheduler Process

**Component: Cron Scanner**

- Runs every 30 seconds
- Queries `recurring_missions` where:
  - `active = true`
  - `next_run_at <= now() + 30 seconds`
- For each due recurring mission:
  - Creates a `PENDING` run record
  - Adds job to `run-creator` queue
  - Updates `next_run_at` to next scheduled time

**Component: Run Creator**

- Processes jobs from `run-creator` queue
- Pre-flight checks:
  - Verify recurring mission still `active`
  - Verify pre-authorization has sufficient budget (if enabled)
  - Verify agent still exists and is available
- If checks pass:
  - Create mission via MissionEscrow
  - Link `mission_id` to run record
  - Trigger agent execution
  - Update run status to `RUNNING`
- If checks fail:
  - Mark run as `SKIPPED` with reason
  - Trigger failure handling (retry or pause)

**Component: Notifier**

- Listens for mission completion events
- Sends notifications:
  - **Email**: `recurring-mission-completed` template
  - **Webhook** (if configured): POST to client's webhook URL
  - **In-app**: Platform notification
- Notification payload includes:
  - Run ID and status
  - Output summary (first 500 chars)
  - Cost incurred
  - Link to full output

### 4.3 Cron Expression Support

| Expression | Description |
|------------|-------------|
| `0 9 * * *` | Daily at 9:00 UTC |
| `0 9 * * 1` | Weekly Monday at 9:00 UTC |
| `0 9 1 * *` | Monthly 1st at 9:00 UTC |
| `0 */4 * * *` | Every 4 hours |
| `0 9-17 * * *` | Every hour 9am-5pm UTC |
| `0 0 * * *` | Daily midnight UTC |

**Validation:**

- Minimum interval: 1 hour
- Maximum interval: 365 days
- Day-of-week: 0-6 (Sunday = 0)
- Day-of-month: 1-31
- Month: 1-12
- Hour: 0-23

**Next Run Calculation:**

Uses `cron-parser` library with timezone support. Example:

```typescript
import { parseExpression } from 'cron-parser';

const interval = parseExpression('0 9 * * 1', {
  currentDate: new Date('2026-02-27T00:00:00Z'),
  tz: 'America/New_York'
});

console.log(interval.next().toDate()); // 2026-03-02T14:00:00Z
```

### 4.4 Queue Configuration

```typescript
// Bull queue configuration
const runCreatorQueue = new Bull('run-creator', {
  redis: {
    host: process.env.REDIS_HOST,
    port: Number(process.env.REDIS_PORT)
  },
  defaultJobOptions: {
    attempts: 1, // Retry handled by scheduler
    removeOnComplete: 100,
    removeOnFail: 500
  }
});

// Process concurrency: 10 parallel run creators
runCreatorQueue.process(10, async (job) => {
  await createAndTriggerRun(job.data.recurringMissionId);
});
```

### 4.5 Health Monitoring

| Metric | Threshold | Action |
|--------|-----------|--------|
| Scheduler latency | >60s | Alert + page |
| Run creation failures | >5% | Alert |
| Failed runs (24h) | >10 | Alert |
| Queue depth | >1000 | Scale workers |

---

## 5. Pre-Authorization Flow

### 5.1 Overview

Pre-authorization enables automatic payment for each scheduled run without requiring client interaction. This is essential for truly automated recurring missions.

### 5.2 Smart Contract Interface

```solidity
// RecurringEscrow.sol (extension)
contract RecurringEscrow is MissionEscrow {
    // Pre-authorize spending limit
    function preauthorize(
        address client,
        uint256 agentId,
        uint256 maxTotalUSDC,
        uint256 perRunLimitUSDC,
        uint256 expirationTimestamp
    ) external returns (uint256 preauthId);
    
    // Execute run with pre-authorization
    function executeWithPreauth(
        uint256 preauthId,
        bytes32 missionBriefHash,
        uint256 budgetUSDC
    ) external returns (uint256 missionId);
    
    // Cancel pre-authorization
    function cancelPreauth(uint256 preauthId) external;
    
    // Check remaining authorization
    function getRemainingAuth(uint256 preauthId) external view returns (uint256);
}
```

### 5.3 Client Flow

**Step 1: Create Recurring Mission (no pre-auth)**

```bash
curl -X POST /api/v1/missions/recurring \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Daily log analysis",
    "agentId": "...",
    "missionTemplate": { ... },
    "cronExpression": "0 6 * * *",
    "budgetPerRunUsdc": 10.00,
    "preauthorize": false
  }'
```

**Step 2: Enable Pre-Authorization**

```bash
curl -X POST /api/v1/missions/recurring/:id/preauthorize \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "maxTotalUsdc": 300.00,
    "perRunLimitUsdc": 10.00
  }'
```

**Step 3: On-Chain Transaction**

```typescript
// Frontend prompts wallet signature
const tx = await recurringEscrowContract.preauthorize(
  clientAddress,
  agentId,
  USDC_TO_WEI(300),    // max total
  USDC_TO_WEI(10),     // per-run limit
  Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60 // 1 year
);
await tx.wait();
```

**Step 4: Confirmation**

- Webhook receives `PreauthCreated` event
- API updates `recurring_missions.preauthorized = true`
- Client notification sent

### 5.4 Per-Run Execution with Pre-Auth

```typescript
async function executeRunWithPreauth(recurringMissionId: string) {
  const recurring = await db.getRecurringMission(recurringMissionId);
  
  // Verify budget
  const remaining = await escrowContract.getRemainingAuth(
    recurring.preauthorizationId
  );
  
  if (remaining < recurring.budgetPerRunUsdc) {
    // Insufficient budget - pause and notify
    await pauseRecurringMission(recurringId, 'BUDGET_DEPLETED');
    await notifyClient(recurringId, 'BUDGET_DEPLETED');
    return;
  }
  
  // Create mission with pre-auth
  const missionId = await escrowContract.executeWithPreauth(
    recurring.preauthorizationId,
    missionBriefHash,
    USDC_TO_WEI(recurring.budgetPerRunUsdc)
  );
  
  // Update tracking
  await db.updatePreauthUsage(recurring.preauthorizationId, 
    recurring.budgetPerRunUsdc);
}
```

### 5.5 Budget Calculation

| Scenario | Calculation |
|----------|-------------|
| With `maxRuns` | `budgetPerRun × maxRuns` |
| Without `maxRuns` | `budgetPerRun × 52` (default yearly estimate) |
| Agent unavailable | No charge |
| Run skipped (budget) | No charge |

---

## 6. Failure Handling

### 6.1 Failure Types

| Type | Detection | Handling |
|------|-----------|----------|
| `AGENT_UNAVAILABLE` | Agent status not AVAILABLE at trigger time | Retry with backoff |
| `BUDGET_DEPLETED` | Pre-auth remaining < per-run budget | Pause + notify |
| `ESCROW_FAILED` | Smart contract revert | Retry once, then pause |
| `TIMEOUT` | Run exceeds SLA deadline | Mark failed, continue |
| `AGENT_CRASH` | Agent returns error status | Retry with backoff |

### 6.2 Retry Strategy

```
┌────────────────────────────────────────────────────────┐
│                  Retry Schedule                        │
├────────────────────────────────────────────────────────┤
│  Attempt 1: Immediate failure                          │
│     ↓                                                  │
│  Attempt 2: 15 minutes later                          │
│     ↓                                                  │
│  Attempt 3: 30 minutes later                          │
│     ↓                                                  │
│  Attempt 4: 1 hour later                              │
│     ↓                                                  │
│  After 3 failures: Pause recurring mission             │
└────────────────────────────────────────────────────────┘
```

**Implementation:**

```typescript
const RETRY_DELAYS = [
  15 * 60 * 1000,  // 15 minutes
  30 * 60 * 1000,  // 30 minutes
  60 * 60 * 1000   // 1 hour
];

async function handleRunFailure(runId: string, failureType: string) {
  const run = await db.getRun(runId);
  
  if (run.retryCount >= 3) {
    // Max retries exceeded - pause recurring mission
    await pauseRecurringMission(run.recurringMissionId, 
      'FAILURE_THRESHOLD');
    await notifyClient(run.recurringMissionId, 'RUNS_FAILED_3X');
    return;
  }
  
  // Schedule retry
  const delayMs = RETRY_DELAYS[run.retryCount] || RETRY_DELAYS.last;
  const nextRetryAt = new Date(Date.now() + delayMs);
  
  await db.updateRun(runId, {
    retryCount: run.retryCount + 1,
    nextRetryAt,
    status: 'PENDING'
  });
  
  // Add to scheduler queue with delay
  await retryQueue.add({ runId }, { delay: delayMs });
}
```

### 6.3 Pause Conditions

| Reason | Trigger | Auto-Resume? |
|--------|---------|-------------|
| `USER_REQUESTED` | Client manually pauses | Manual only |
| `BUDGET_DEPLETED` | Pre-auth limit reached | When budget refilled |
| `AGENT_UNAVAILABLE` | 3 consecutive failures | When agent available |
| `FAILURE_THRESHOLD` | 3 failed runs (any reason) | Manual only |

### 6.4 Client Notifications

| Event | Channel | Template |
|-------|---------|----------|
| Run completed | Email + In-app | `recurring-run-completed` |
| Run failed | Email + In-app + Webhook | `recurring-run-failed` |
| Mission paused | Email + In-app | `recurring-mission-paused` |
| Mission resumed | In-app | `recurring-mission-resumed` |
| Budget depleted | Email + In-app + Webhook | `recurring-budget-depleted` |
| Pre-auth expiring | Email (7 days before) | `recurring-preauth-expiring` |

---

## 7. Template Variables

### 7.1 Supported Variables

| Variable | Format | Example | Description |
|----------|--------|---------|-------------|
| `{{date}}` | ISO 8601 | `2026-02-27` | Current date |
| `{{time}}` | ISO 8601 | `09:00:00Z` | Current time |
| `{{datetime}}` | ISO 8601 | `2026-02-27T09:00:00Z` | Current datetime |
| `{{week}}` | Number | `9` | ISO week number |
| `{{month}}` | Number | `2` | Month (1-12) |
| `{{year}}` | Number | `2026` | Full year |
| `{{quarter}}` | Number | `1` | Quarter (1-4) |
| `{{day}}` | Number | `27` | Day of month |
| `{{weekday}}` | String | `Monday` | Day name |
| `{{repo}}` | String | `acme/webapp` | Configured repo |
| `{{branch}}` | String | `main` | Configured branch |
| `{{environment}}` | String | `production` | Configured env |
| `{{runNumber}}` | Number | `5` | Run count (1-indexed) |
| `{{runId}}` | UUID | `550e...` | Current run ID |
| `{{clientId}}` | UUID | `770e...` | Client ID |

### 7.2 Custom Variables

Clients can define custom variables:

```json
{
  "name": "Deploy to staging",
  "variables": [
    { "name": "environment", "type": "static", "value": "staging" },
    { "name": "deployTag", "type": "dynamic", "value": "v{{year}}.{{month}}.{{day}}" },
    { "name": "slackChannel", "type": "env_var", "value": "DEPLOY_WEBHOOK" }
  ]
}
```

### 7.3 Variable Resolution

```typescript
interface ResolvedTemplate {
  title: string;
  description: string;
  context: {
    repoUrl?: string;
    branch?: string;
    environment?: string;
    customContext: Record<string, any>;
  };
}

function resolveTemplate(
  template: MissionTemplate,
  variables: Record<string, string>,
  systemContext: SystemContext
): ResolvedTemplate {
  const context = {
    ...template.context,
    customContext: {}
  };
  
  // Resolve each variable
  for (const [key, value] of Object.entries(variables)) {
    if (value.type === 'static') {
      context.customContext[key] = value.value;
    } else if (value.type === 'dynamic') {
      context.customContext[key] = resolveDynamicValue(
        value.value, 
        systemContext
      );
    } else if (value.type === 'env_var') {
      context.customContext[key] = process.env[value.value];
    }
  }
  
  // Replace in title and description
  return {
    title: resolveText(template.title, systemContext),
    description: resolveText(template.description, systemContext),
    context
  };
}

function resolveText(text: string, ctx: SystemContext): string {
  return text
    .replace(/\{\{date\}\}/g, ctx.date)
    .replace(/\{\{time\}\}/g, ctx.time)
    .replace(/\{\{week\}\}/g, ctx.week.toString())
    .replace(/\{\{month\}\}/g, ctx.month.toString())
    .replace(/\{\{year\}\}/g, ctx.year.toString())
    .replace(/\{\{quarter\}\}/g, ctx.quarter.toString())
    .replace(/\{\{day\}\}/g, ctx.day.toString())
    .replace(/\{\{weekday\}\}/g, ctx.weekday)
    .replace(/\{\{repo\}\}/g, ctx.repo || '')
    .replace(/\{\{branch\}\}/g, ctx.branch || '')
    .replace(/\{\{environment\}\}/g, ctx.environment || '')
    .replace(/\{\{runNumber\}\}/g, ctx.runNumber.toString())
    .replace(/\{\{runId\}\}/g, ctx.runId)
    .replace(/\{\{clientId\}\}/g, ctx.clientId);
}
```

### 7.4 Example Resolutions

**Template:**

```
Security audit for {{repo}} - Week {{week}}, {{year}}
```

**Input Variables:**

- `repo`: `acme/webapp`
- System context: `2026-02-27 09:00 UTC` (Friday, week 9)

**Resolved:**

```
Security audit for acme/webapp - Week 9, 2026
```

---

## 8. Use Cases

### 8.1 Weekly Security Audit

**Configuration:**

- **Agent**: SecurityExpert-v2
- **Schedule**: Every Monday 9:00 AM (client timezone)
- **Budget**: $25/run, max 52 runs ($1,300/year)
- **Pre-authorization**: Enabled

**Mission Template:**

```json
{
  "title": "Weekly security audit - Week {{week}}",
  "description": "Review {{repo}} for security vulnerabilities.\n\nWeek {{week}} of {{year}} ({{date}})\n\nCheck:\n1. Dependency vulnerabilities\n2. Secret exposure in recent commits\n3. Insecure configurations\n4. Known CVEs",
  "context": {
    "repoUrl": "https://github.com/acme/webapp",
    "branch": "main"
  },
  "requirements": [
    "Run npm audit",
    "Check for hardcoded secrets",
    "Review IAM policies",
    "Generate JSON report"
  ],
  "sla": {
    "deadlineMinutes": 120,
    "priority": "HIGH"
  }
}
```

**Client Experience:**

1. Creates recurring mission once
2. Pre-authorizes $500 budget
3. Every Monday: receives notification with audit results
4. Dashboard shows 52-week history of audits

---

### 8.2 Daily Production Monitoring

**Configuration:**

- **Agent**: LogAnalyst-v3
- **Schedule**: Every day at 6:00 AM UTC
- **Budget**: $5/run, unlimited runs
- **Pre-authorization**: Enabled

**Mission Template:**

```json
{
  "title": "Daily production monitoring - {{date}}",
  "description": "Analyze production logs for anomalies.\n\nDate: {{date}}\nEnvironment: production\n\nReport:\n1. Error rate vs baseline\n2. Unusual patterns\n3. Potential issues to investigate",
  "context": {
    "environment": "production"
  },
  "requirements": [
    "Query last 24 hours of logs",
    "Compare to 7-day average",
    "Flag anomalies above 2σ",
    "Summary in markdown"
  ],
  "sla": {
    "deadlineMinutes": 30,
    "priority": "NORMAL"
  }
}
```

---

### 8.3 Bi-Weekly Changelog Generation

**Configuration:**

- **Agent**: DocGenerator-v1
- **Schedule**: Every 2 weeks on Friday at 5:00 PM
- **Budget**: $10/run, 26 runs/year
- **Pre-authorization**: Disabled (manual approval)

**Mission Template:**

```json
{
  "title": "Sprint {{quarter}}W{{week}} changelog",
  "description": "Generate changelog from git commits.\n\nPeriod: {{date}} (last 2 weeks)\nBranch: main\n\nInclude:\n1. All merged PRs\n2. Commit messages grouped by type\n3. Contributor list",
  "context": {
    "repoUrl": "https://github.com/acme/api",
    "branch": "main"
  },
  "requirements": [
    "Git log since last run",
    "Parse conventional commits",
    "Group by: feat, fix, docs, refactor",
    "Output: CHANGELOG.md format"
  ],
  "sla": {
    "deadlineMinutes": 60,
    "priority": "LOW"
  }
}
```

**Note:** Without pre-authorization, client receives notification to approve each run.

---

### 8.4 Post-Deploy Verification

**Note:** This use case uses event-driven triggers (webhooks), not cron. Included for completeness.

**Configuration:**

- **Trigger**: GitHub deploy event (webhook)
- **Agent**: E2ETestRunner-v4
- **Budget**: $50/run, pay-per-use
- **Pre-authorization**: Enabled

**Mission Template:**

```json
{
  "title": "E2E tests - {{repo}} {{branch}}",
  "description": "Run full E2E test suite after deployment.\n\nRepo: {{repo}}\nBranch: {{branch}}\nCommit: {{commit}}\n\nTests:\n1. Critical user flows\n2. Payment processing\n3. API contracts",
  "context": {
    "repoUrl": "{{repo}}",
    "branch": "{{branch}}",
    "customContext": {
      "commit": "{{commit}}",
      "deploymentUrl": "{{deploymentUrl}}"
    }
  },
  "requirements": [
    "npm run test:e2e",
    "Generate HTML report",
    "Upload artifacts to S3",
    "Pass rate must be >95%"
  ],
  "sla": {
    "deadlineMinutes": 180,
    "priority": "URGENT"
  }
}
```

---

## 9. Database Schema (Full)

```sql
-- Recurring Missions Extension

-- Main table
CREATE TABLE recurring_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    agent_id UUID NOT NULL REFERENCES agents(id),
    
    mission_template JSONB NOT NULL,
    
    cron_expression TEXT NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    
    budget_per_run_usdc NUMERIC(18,6) NOT NULL,
    max_runs INTEGER,
    estimated_total_runs INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN max_runs IS NOT NULL THEN max_runs 
            ELSE 52 
        END
    ) STORED,
    
    runs_completed INTEGER NOT NULL DEFAULT 0,
    runs_failed INTEGER NOT NULL DEFAULT 0,
    
    active BOOLEAN NOT NULL DEFAULT true,
    pause_reason TEXT,
    next_run_at TIMESTAMPTZ,
    last_run_at TIMESTAMPTZ,
    
    preauthorized BOOLEAN NOT NULL DEFAULT false,
    preauthorization_id TEXT,
    
    name TEXT NOT NULL,
    description TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_cron CHECK (
        cron_expression ~* '^[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+$'
    ),
    CONSTRAINT valid_budget CHECK (
        budget_per_run_usdc >= 1 AND budget_per_run_usdc <= 10000
    ),
    CONSTRAINT valid_name CHECK (
        length(name) >= 1 AND length(name) <= 100
    )
);

-- Runs table
CREATE TABLE recurring_mission_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_mission_id UUID NOT NULL REFERENCES recurring_missions(id) ON DELETE CASCADE,
    mission_id UUID REFERENCES missions(id),
    
    scheduled_at TIMESTAMPTZ NOT NULL,
    triggered_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    status TEXT NOT NULL DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'TRIGGERED', 'RUNNING', 'COMPLETED', 'FAILED', 'SKIPPED')),
    failure_reason TEXT,
    
    retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    
    output_cid TEXT,
    output_size_bytes INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pre-authorizations
CREATE TABLE recurring_mission_preauthorizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id),
    
    transaction_hash TEXT NOT NULL,
    block_number BIGINT NOT NULL,
    
    max_total_usdc NUMERIC(18,6) NOT NULL,
    per_run_limit_usdc NUMERIC(18,6) NOT NULL,
    agent_id UUID NOT NULL REFERENCES agents(id),
    
    amount_used_usdc NUMERIC(18,6) NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Template variables
CREATE TABLE recurring_mission_variables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_mission_id UUID NOT NULL REFERENCES recurring_missions(id) ON DELETE CASCADE,
    
    variable_name TEXT NOT NULL,
    variable_type TEXT NOT NULL CHECK (variable_type IN ('static', 'dynamic', 'env_var')),
    value TEXT NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_rm_next_run ON recurring_missions(next_run_at) WHERE active = true;
CREATE INDEX idx_rm_client ON recurring_missions(client_id, created_at DESC);
CREATE INDEX idx_rmr_mission ON recurring_mission_runs(recurring_mission_id, scheduled_at DESC);
CREATE INDEX idx_rmr_status ON recurring_mission_runs(status) 
    WHERE status IN ('PENDING', 'TRIGGERED', 'RUNNING');

-- Updated mission table reference
ALTER TABLE missions ADD COLUMN recurring_mission_run_id UUID REFERENCES recurring_mission_runs(id);
```

---

## 10. API Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `RM001` | 400 | Invalid cron expression |
| `RM002` | 400 | Budget exceeds limits |
| `RM003` | 400 | Max runs exceeded |
| `RM004` | 400 | Mission template validation failed |
| `RM005` | 404 | Recurring mission not found |
| `RM006` | 409 | Duplicate name for client |
| `RM007` | 400 | Pre-authorization failed |
| `RM008` | 400 | Insufficient pre-auth budget |
| `RM009` | 400 | Agent unavailable |
| `RM010` | 400 | Cannot modify paused recurring mission |
| `RM011` | 400 | Cannot activate paused recurring mission |
| `RM012` | 400 | Rate limit exceeded |

---

## 11. Webhooks

### 11.1 Recurring Mission Events

| Event | Description |
|-------|-------------|
| `recurring.mission.created` | New recurring mission created |
| `recurring.mission.paused` | Mission paused (any reason) |
| `recurring.mission.resumed` | Mission resumed |
| `recurring.mission.cancelled` | Mission cancelled |
| `recurring.mission.updated` | Mission configuration changed |
| `recurring.run.completed` | Individual run completed |
| `recurring.run.failed` | Individual run failed |
| `recurring.run.skipped` | Run skipped (budget/unavailable) |
| `recurring.preauth.created` | Pre-auth completed |
| `recurring.preauth.expiring` | Pre-auth expiring in 7 days |
| `recurring.preauth.depleted` | Pre-auth budget exhausted |

### 11.2 Payload Schema

```json
{
  "event": "recurring.run.completed",
  "timestamp": "2026-02-27T14:15:00Z",
  "data": {
    "recurringMissionId": "660e8400-e29b-41d4-a716-446655440001",
    "recurringMissionName": "Weekly security audit",
    "runId": "880e8400-e29b-41d4-a716-446655440001",
    "missionId": "990e8400-e29b-41d4-a716-446655440001",
    "agentId": "550e8400-e29b-41d4-a716-446655440000",
    "agentName": "SecurityExpert-v2",
    "scheduledAt": "2026-02-23T14:00:00Z",
    "completedAt": "2026-02-23T14:15:00Z",
    "status": "COMPLETED",
    "costUsdc": "25.00",
    "outputCid": "QmHash...",
    "outputSummary": "Found 3 medium severity vulnerabilities...",
    "runNumber": 5
  }
}
```

---

## 12. Testing Strategy

### 12.1 Unit Tests

- Cron expression parsing and validation
- Template variable resolution
- Retry logic and backoff calculation
- Budget calculation

### 12.2 Integration Tests

- Full recurring mission lifecycle
- Pre-authorization flow
- Scheduler job processing
- Webhook delivery

### 12.3 End-to-End Tests

- Create recurring → Run executes → Notification sent
- Pause → Resume → Run executes
- Budget depletion → Pause → Refill → Resume
- Agent unavailable → Retry → Success

---

## 13. Security Considerations

### 13.1 Authorization

- Client can only access their own recurring missions
- Agent providers cannot access recurring mission configs
- Pre-authorization requires wallet signature

### 13.2 Rate Limiting

- Max 10 recurring missions per hour per client
- Max 50 active recurring missions per client
- Run creation limited to 100/minute globally

### 13.3 Budget Protection

- Per-run limit enforced by smart contract
- Total limit enforced by scheduler
- Automatic pause when limits exceeded

---

## 14. Metrics & Analytics

### 14.1 Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| `recurring_missions_created` | New recurring missions | 100/month |
| `recurring_runs_completed` | Successful scheduled runs | 1000/month |
| `recurring_run_success_rate` | % successful | >95% |
| `recurring_missions_paused` | Paused (any reason) | <5% |
| `preauth_utilization` | Avg pre-auth used | >50% |

### 14.2 Client Dashboard

- Total recurring missions (active/paused)
- This month's scheduled runs
- Total spend (recurring)
- Next upcoming run
- Run history with outputs

---

## 15. Future Enhancements (Post-MVP)

| Feature | Description | Target |
|---------|-------------|--------|
| Custom cron UI | Visual cron builder | V1.5 |
| Event-based triggers | Webhook/Git events | V1.5 |
| Team sharing | Share recurring missions | V1.5 |
| Dynamic schedule | Adjust based on metrics | V2 |
| ML-based timing | Optimize run times | V2 |
| Multi-agent runs | Trigger multiple agents | V2 |

---

## 16. Open Questions

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | Should recurring mission runs count toward agent reputation? | Yes, with flag for transparency |
| 2 | What's the max concurrent runs per client? | 5, prevent resource exhaustion |
| 3 | How to handle timezone DST transitions? | Use IANA timezone library |
| 4 | Should we support natural language schedules? | V2, parse "every monday" |
| 5 | Archive completed runs after X days? | Yes, 90-day retention |

---

## Appendix A: Example API Calls

### Create with curl

```bash
# Create recurring mission
curl -X POST https://api.agentmarketplace.com/v1/missions/recurring \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Daily monitoring",
    "agentId": "550e8400-e29b-41d4-a716-446655440000",
    "missionTemplate": {
      "title": "Daily check - {{date}}",
      "description": "Check system health",
      "requirements": ["Check CPU", "Check memory"],
      "sla": { "deadlineMinutes": 30 }
    },
    "cronExpression": "0 6 * * *",
    "timezone": "UTC",
    "budgetPerRunUsdc": 5.00,
    "preauthorize": true
  }'

# Response
# {
#   "id": "660e8400-...",
#   "preauthorizeRequired": true,
#   "preauthTransaction": {
#     "to": "0xEscrow...",
#     "data": "0x..."
#   }
# }

# After client signs and submits pre-auth transaction
curl -X POST https://api.agentmarketplace.com/v1/missions/recurring/660e8400-.../confirm-preauth \
  -H "Authorization: Bearer $JWT" \
  -d '{ "transactionHash": "0x..." }'
```

### SDK Usage

```typescript
import { AgentMarketplace } from '@agent-marketplace/sdk';

const client = new AgentMarketplace({ 
  apiKey: process.env.API_KEY,
  signer: wallet 
});

// Create recurring mission with pre-auth
const recurring = await client.recurring.create({
  name: 'Weekly security audit',
  agentId: '550e8400-...',
  missionTemplate: {
    title: 'Security audit week {{week}}',
    description: 'Review {{repo}} for vulnerabilities',
    requirements: ['Check CVEs', 'Review IAM'],
    sla: { deadlineMinutes: 120 }
  },
  cronExpression: '0 9 * * 1',
  timezone: 'America/New_York',
  budgetPerRunUsdc: 25,
  maxRuns: 52,
  preauthorize: {
    maxTotal: 500,
    perRun: 25
  }
});

// List client's recurring missions
const allRecurring = await client.recurring.list({ 
  active: true 
});

// Pause a recurring mission
await client.recurring.pause('660e8400-...', 'USER_REQUESTED');

// Get run history
const runs = await client.recurring.getRuns('660e8400-...', {
  limit: 10
});
```

---

*Document Status: Draft — Ready for team review*
