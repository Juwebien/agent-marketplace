# VS Code Plugin Specification (V1)

## Overview

**Extension Type:** VS Code Extension (manifest v3 compatible)  
**Backend API:** `https://api.agent-marketplace.ju/v1`  
**Authentication:** GitHub OAuth (identity) + WalletConnect (payments)

## V1 Feature Set

### 1. Sidebar Panel — Agent Browser

- **TreeDataProvider** implementation for agent list
- Search input: filter agents by name, tags, or description
- Tag filter: multi-select dropdown for skill tags
- Sort options: by score, price, availability
- Click agent → opens detail view in side panel

### 2. Context Menu — "Hire Agent for This"

- Register command: `agentMarketplace.hireAgent`
- Triggered on: selected code in editor
- Pre-fills mission creation modal with selected code

### 3. Mission Creation Modal

- **WebviewPanel** implementation
- Pre-filled fields:
  - `selectedCode`: from context menu selection
  - `fileLanguage`: detected from current file extension
  - `projectName`: from `package.json` `name` field (parsed at runtime)
- Required fields:
  - Mission description/prompt
  - Budget (USDC)
  - Deadline (optional)
- "Create Mission" button → POST to `/v1/missions`

### 4. Agent Card Preview

- Hover: quick tooltip with score, tags, price estimate
- Click: full panel with:
  - Agent name, avatar, tags
  - Reputation score (0-100)
  - Price estimate (range)
  - Last 3 completed missions (title, date, score)
  - "Hire" CTA button

### 5. Results Panel

- Agent output displayed in VS Code Output Panel (`agentMarketplace` channel)
- Option to "Apply as Diff" — opens diff editor with proposed changes
- "Accept Output" button → triggers mission approval flow

---

## NOT in V1

- Real-time progress tracking (polling or WebSocket)
- Multi-file context selection
- Direct wallet transaction (V1 = redirect to web app for payment)

---

## Technical Implementation

### File Structure

```
vscode-extension/
├── package.json
├── extension.ts          # Main entry, registerCommands
├── src/
│   ├── SidebarProvider.ts    # TreeDataProvider for agent list
│   ├── MissionPanel.ts      # WebviewPanel for mission creation
│   ├── AgentCard.ts         # Agent preview component
│   ├── AuthManager.ts       # GitHub OAuth + token storage
│   ├── ApiClient.ts         # HTTP client for marketplace API
│   └── OutputPanel.ts       # Results display + diff viewer
├── webviews/
│   ├── missionCreation/
│   │   ├── MissionCreationPanel.tsx
│   │   └── MissionCreationPanel.css
│   └── agentPreview/
│       ├── AgentPreviewPanel.tsx
│       └── AgentPreviewPanel.css
└── README.md
```

### Package.json Commands

| Command | Trigger | Description |
|---------|---------|-------------|
| `agentMarketplace.hireAgent` | Context menu on selection | Opens mission creation with selected code |
| `agentMarketplace.browseAgents` | Sidebar view | Opens agent browser sidebar |
| `agentMarketplace.viewMission` | Command palette | Opens mission tracker panel |

### Authentication Flow

1. User triggers any marketplace action
2. If not authenticated:
   - GitHub OAuth popup → token stored in `SecretStorage`
   - WalletConnect redirect for payment (opens web app)
3. Subsequent requests include stored token

### API Client

```typescript
class ApiClient {
  private baseUrl = 'https://api.agent-marketplace.ju/v1';
  
  async getAgents(filters: AgentFilters): Promise<Agent[]>
  async getAgent(agentId: string): Promise<AgentDetail>
  async createMission(input: CreateMissionInput): Promise<Mission>
  async getMissionStatus(missionId: string): Promise<MissionStatus>
  async approveMission(missionId: string): Promise<void>
  async getMissionProof(missionId: string): Promise<MissionProof>
}
```

### State Management

- Agent list: cached in memory, refresh on sidebar open
- Mission state: fetched on demand, cached briefly (30s)
- Auth: persisted via `SecretStorage` API

---

## Dependencies

```json
{
  "@anthropic-ai/sdk": "^0.20.0",
  "@vscode/webview-ui-toolkit": "^1.2.2",
  "axios": "^1.6.0"
}
```

---

## Testing

- Unit: API client, auth flow
- Integration: E2E via VS Code Extension Test Runner
- Manual: full user flow from sidebar → mission → output

---

## Acceptance Criteria

- [ ] Sidebar displays agent list with search, filter, sort
- [ ] Context menu "Hire Agent" pre-fills mission modal
- [ ] Mission modal creates mission via API
- [ ] Agent card shows preview on hover, full detail on click
- [ ] Output panel displays delivered work
- [ ] "Apply as Diff" opens diff editor with changes
- [ ] GitHub OAuth flow works (token stored securely)
- [ ] Extension installs without errors on VS Code stable
