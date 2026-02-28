# Agent Marketplace VS Code Extension — Implementation Specification v2

> **Status:** Build-Ready  
> **Version:** 2.0  
> **Generated:** 2026-02-28  
> **Backend API:** `https://api.agentmarketplace.xyz`

---

## 1. Extension Overview

| Property | Value |
|----------|-------|
| Extension ID | `agentmarketplace.vscode` |
| Display Name | Agent Marketplace |
| Extension Type | VS Code Extension (Manifest v3) |
| Languages | TypeScript (extension host), React + TailwindCSS (webviews) |
| Target VS Code | >=1.85.0 |
| Marketplace | Open VSX (recommended) |

### 1.1 Core Features (V2)

- **Agent Browser Panel** — Sidebar webview for browsing, searching, and filtering AI agents
- **Mission Creation** — Context-aware mission builder with code context
- **Wallet Integration** — MetaMask deep link + QR code for USDC payments
- **Mission Tracking** — Real-time status bar + notification-driven result delivery
- **Escrow Flow** — On-chain payment via MissionEscrow smart contract

---

## 2. Extension Manifest (`package.json`)

### 2.1 Contribution Points

```json
{
  "name": "agent-marketplace",
  "displayName": "Agent Marketplace",
  "version": "2.0.0",
  "publisher": "agentmarketplace",
  "description": "Hire AI agents for your coding tasks — decentralized compute marketplace",
  "icon": "assets/icon.png",
  "categories": ["Developer Tools", "AI"],
  "keywords": ["ai", "agents", "marketplace", "code", "autonomous"],
  "activationEvents": [
    "onStartupFinished",
    "onCommand:agentmarket.hireAgent",
    "onCommand:agentmarket.browseAgents",
    "onCommand:agentmarket.myMissions"
  ],
  "main": "dist/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "agentmarket.hireAgent",
        "title": "Hire Agent for This",
        "category": "Agent Marketplace"
      },
      {
        "command": "agentmarket.browseAgents",
        "title": "Browse Agents",
        "category": "Agent Marketplace"
      },
      {
        "command": "agentmarket.myMissions",
        "title": "My Missions",
        "category": "Agent Marketplace"
      },
      {
        "command": "agentmarket.configure",
        "title": "Configure Agent Marketplace",
        "category": "Agent Marketplace"
      },
      {
        "command": "agentmarket.refreshAgents",
        "title": "Refresh Agent List",
        "category": "Agent Marketplace"
      }
    ],
    "menus": {
      "editor/context": [
        {
          "when": "editorHasSelection",
          "command": "agentmarket.hireAgent",
          "group": "navigation"
        }
      ],
      "commandPalette": [
        {
          "command": "agentmarket.hireAgent",
          "when": "editorHasSelection"
        }
      ]
    },
    "keybindings": [
      {
        "command": "agentmarket.hireAgent",
        "key": "ctrl+shift+h",
        "mac": "cmd+shift+h",
        "when": "editorHasSelection"
      },
      {
        "command": "agentmarket.browseAgents",
        "key": "ctrl+shift+a",
        "mac": "cmd+shift+a",
        "when": "!editorHasSelection"
      }
    ],
    "configuration": {
      "title": "Agent Marketplace",
      "properties": {
        "agentmarket.apiUrl": {
          "type": "string",
          "default": "https://api.agentmarketplace.xyz",
          "description": "Backend API URL"
        },
        "agentmarket.defaultBudget": {
          "type": "number",
          "default": 50,
          "minimum": 1,
          "maximum": 1000,
          "description": "Default mission budget in USDC"
        },
        "agentmarket.defaultSLA": {
          "type": "string",
          "default": "STANDARD_48H",
          "enum": ["STANDARD_48H", "EXPRESS_4H"],
          "description": "Default SLA tier"
        },
        "agentmarket.autoOpenResults": {
          "type": "boolean",
          "default": true,
          "description": "Automatically open agent output when mission completes"
        },
        "agentmarket.showStatusBar": {
          "type": "boolean",
          "default": true,
          "description": "Show mission count in status bar"
        }
      }
    },
    "views": {
      "activitybar": [
        {
          "id": "agentmarket-sidebar",
          "icon": "assets/agent-icon.svg",
          "title": "Agent Marketplace"
        }
      ]
    },
    "viewsContainers": {
      "activitybar": [
        {
          "id": "agentmarket-sidebar",
          "icon": "assets/agent-icon.svg",
          "title": "Agent Marketplace"
        }
      ]
    },
    "webviews": {
      "agent-browser": {
        "id": "agentmarket-agent-browser",
        "title": "Agent Browser",
        "icon": "assets/agent-icon.svg"
      },
      "mission-creation": {
        "id": "agentmarket-mission-creation",
        "title": "Create Mission"
      },
      "my-missions": {
        "id": "agentmarket-my-missions",
        "title": "My Missions"
      }
    }
  },
  "scripts": {
    "build": "npm run build:extension && npm run build:webviews",
    "build:extension": "tsc -p tsconfig.json",
    "build:webviews": "node scripts/build-webviews.js",
    "watch": "tsc -w",
    "dev": "npm run build:extension && code .",
    "test": "node ./out/test/runTest.js",
    "package": "vsce package"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.20.0",
    "@vscode/webview-ui-toolkit": "^1.2.2",
    "axios": "^1.6.0",
    "viem": "^2.0.0",
    "wagmi": "^2.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/vscode": "^1.85.0",
    "@vscode/test-electron": "^2.3.0",
    "esbuild": "^0.19.0",
    "typescript": "^5.3.0",
    "vsce": "^2.15.0"
  },
  "extensionKind": ["workspace"]
}
```

---

## 3. Authentication Flow

### 3.1 First Launch Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                    First Launch Flow                             │
├─────────────────────────────────────────────────────────────────┤
│  1. Extension activates                                          │
│  2. Check: Is GitHub token stored in SecretStorage?              │
│       └─ NO → Show Welcome WebView                               │
│             ├─ "Connect with GitHub" button                     │
│             ├─ "Learn More" link                                 │
│             └─ Skip for now (stores preference)                 │
│  3. Check: Is wallet connected?                                 │
│       └─ NO → Prompt "Connect Wallet"                           │
│             ├─ "Open MetaMask" deep link (mobile/desktop)      │
│             └─ QR code display (webview fallback)               │
│  4. On success → Fetch balance (USDC + AGNT)                   │
│  5. Store auth state in globalState                             │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 GitHub OAuth Implementation

```typescript
// src/auth/githubAuth.ts

export class GitHubAuth {
  private static readonly CLIENT_ID = process.env.GITHUB_CLIENT_ID;
  private static readonly REDIRECT_URI = 'vscode://agentmarketplace/auth/callback';
  private static readonly SCOPES = ['read:user', 'user:email'];

  static async initiate(): Promise<void> {
    const params = new URLSearchParams({
      client_id: this.CLIENT_ID,
      redirect_uri: this.REDIRECT_URI,
      scope: this.SCOPES.join(' '),
      state: this.generateState()
    });

    const authUrl = `https://github.com/login/oauth/authorize?${params}`;
    await vscode.env.openExternal(vscode.Uri.parse(authUrl));
  }

  static async handleCallback(code: string, state: string): Promise<boolean> {
    // Exchange code for token via backend API
    const response = await apiClient.exchangeGitHubToken({
      code,
      redirect_uri: this.REDIRECT_URI
    });

    if (response.token) {
      // Store JWT in VS Code SecretStorage (NOT settings)
      await this.storeToken(response.token);
      return true;
    }
    return false;
  }

  private static async storeToken(token: string): Promise<void> {
    const secretStorage = vscode.extensions.getExtension('agentmarketplace.vscode')
      ?.exports.secretStorage;
    await secretStorage.store('github_jwt', token);
  }

  static async getToken(): Promise<string | undefined> {
    const secretStorage = vscode.extensions.getExtension('agentmarketplace.vscode')
      ?.exports.secretStorage;
    return secretStorage.get('github_jwt');
  }
}
```

### 3.3 Wallet Authentication (MetaMask)

```typescript
// src/auth/walletAuth.ts

export class WalletAuth {
  private static readonly DEEP_LINK = 'metamask://';
  private static readonly CHAIN_ID = '0x2105'; // Base mainnet (8453 decimal)

  static async connect(): Promise<WalletConnection> {
    // Option 1: Deep link (mobile/desktop MetaMask)
    if (await this.canOpenDeepLink()) {
      await this.connectViaDeepLink();
    } else {
      // Option 2: QR code fallback in webview
      return { method: 'qr', qrData: this.generateQRData() };
    }
  }

  private static async canOpenDeepLink(): Promise<boolean> {
    try {
      await vscode.env.openExternal(vscode.Uri.parse(this.DEEP_LINK + 'connect'));
      return true;
    } catch {
      return false;
    }
  }

  static async signMessage(address: string, message: string): Promise<string> {
    // Use wagmi in webview context for wallet signature
    // Returns SIWE signature for backend verification
    const response = await apiClient.verifyWallet({
      address,
      signature: /* signature from wagmi */,
      message
    });
    return response.jwt;
  }

  static async getBalance(address: string): Promise<{ usdc: string; agnt: string }> {
    return apiClient.getBalances(address);
  }
}
```

### 3.4 Auth State Management

```typescript
// src/auth/authState.ts

export interface AuthState {
  isAuthenticated: boolean;
  githubToken?: string;
  walletAddress?: string;
  walletConnected: boolean;
  balances: {
    usdc: string;
    agnt: string;
  };
}

export class AuthStateManager {
  private static readonly STORAGE_KEY = 'agentmarket_auth_state';

  static async get(): Promise<AuthState> {
    const stored = await vscode.workspace.getConfiguration()
      .get<string>(this.STORAGE_KEY);
    return stored ? JSON.parse(stored) : { walletConnected: false, balances: { usdc: '0', agnt: '0' } };
  }

  static async set(state: Partial<AuthState>): Promise<void> {
    const current = await this.get();
    const updated = { ...current, ...state };
    await vscode.workspace.getConfiguration()
      .update(this.STORAGE_KEY, JSON.stringify(updated), true);
  }
}
```

---

## 4. Agent Browser Panel (Sidebar WebView)

### 4.1 Panel Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  🔍 Search agents...                          [⚙️] [🔄]       │
├─────────────────────────────────────────────────────────────────┤
│  Filters:                                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ Price Range │ │   Score     │ │ Availability │            │
│  │ $10 - $100  │ │  ★★★★☆ (80) │ │  ● Online   │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│  Tags: [react] [typescript] [python] [+add]                    │
├─────────────────────────────────────────────────────────────────┤
│  Agent Cards (Compact List):                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 🤖 Claude-Architect    ★★★★★ (95)   $50-200/hr    [Hire] ││
│  │     tags: [architecture] [system-design]                   ││
│  │     Available now                                           ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ 🤖 CodeReview-Pro      ★★★★☆ (87)   $30-80/hr     [Hire] ││
│  │     tags: [code-review] [security]                         ││
│  │     Available in 2h                                         ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ 🤖 TestGen-Express    ★★★☆☆ (72)   $20-50/hr     [Hire] ││
│  │     tags: [testing] [jest] [playwright]                    ││
│  │     Online                                                  ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  Showing 12 of 156 agents                      [1] [2] [3] ...  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Implementation

```typescript
// src/panels/AgentBrowserPanel.ts

export class AgentBrowserPanel {
  public static readonly viewType = 'agentmarket-agent-browser';
  private static instance: AgentBrowserPanel | undefined;

  static createOrShow(extensionUri: vscode.Uri): AgentBrowserPanel {
    if (AgentBrowserPanel.instance) {
      AgentBrowserPanel.instance.panel.reveal();
      return AgentBrowserPanel.instance;
    }

    const panel = vscode.window.createWebviewPanel(
      this.viewType,
      'Agent Marketplace',
      vscode.ViewColumn.Sidebar,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [
          vscode.Uri.joinPath(extensionUri, 'webviews', 'agent-browser'),
          vscode.Uri.joinPath(extensionUri, 'assets')
        ]
      }
    );

    AgentBrowserPanel.instance = new AgentBrowserPanel(panel, extensionUri);
    return AgentBrowserPanel.instance;
  }

  async loadAgents(filters?: AgentFilters): Promise<void> {
    const agents = await apiClient.getAgents(filters);
    this.postMessage({ type: 'agentsLoaded', payload: agents });
  }

  async searchAgents(query: string): Promise<void> {
    const agents = await apiClient.searchAgents(query);
    this.postMessage({ type: 'searchResults', payload: agents });
  }
}
```

### 4.3 Agent Card Component

```typescript
// src/components/AgentCard.tsx (React)

interface AgentCardProps {
  agent: Agent;
  onHire: (agentId: string) => void;
  onViewDetails: (agentId: string) => void;
}

export function AgentCard({ agent, onHire, onViewDetails }: AgentCardProps) {
  return (
    <div className="agent-card" onClick={() => onViewDetails(agent.id)}>
      <div className="agent-header">
        <img src={agent.avatarUrl} alt={agent.name} className="agent-avatar" />
        <div className="agent-info">
          <h3 className="agent-name">{agent.name}</h3>
          <div className="agent-score">
            {'★'.repeat(Math.floor(agent.reputationScore / 20))}
            {'☆'.repeat(5 - Math.floor(agent.reputationScore / 20))}
            <span className="score-value">({agent.reputationScore})</span>
          </div>
        </div>
        <div className="agent-price">
          ${agent.priceMin}-${agent.priceMax}/hr
        </div>
      </div>
      
      <div className="agent-tags">
        {agent.tags.map(tag => (
          <span key={tag} className="tag">{tag}</span>
        ))}
      </div>
      
      <div className="agent-availability">
        {agent.available ? (
          <span className="status online">● Online</span>
        ) : (
          <span className="status offline">
            Available in {agent.availableIn}
          </span>
        )}
      </div>
      
      <button 
        className="hire-button"
        onClick={(e) => { e.stopPropagation(); onHire(agent.id); }}
      >
        Hire
      </button>
    </div>
  );
}
```

---

## 5. Mission Creation Panel (WebView)

### 5.1 Panel Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Create Mission - [Agent Name]                    [✕]          │
├─────────────────────────────────────────────────────────────────┤
│  Context (from editor):                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ File: src/utils/auth.ts                                     ││
│  │ Language: TypeScript                                        ││
│  │ ─────────────────────────────────────────────────────────── ││
│  │ export async function authenticate() {                     ││
│  │   const token = await getToken();                          ││
│  │   if (!token) throw new Error('No token');                 ││
│  │   return validateToken(token);                             ││
│  │ }                                                          ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  Mission Description:                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Write a secure token validation function with               ││
│  │ expiration handling and refresh token support...            ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  Budget: [$50 ████████░░░░░░░░░░░░░░░░░░] $500                │
│  SLA: (●) Standard 48h    ( ) Express 4h                       │
│  ☑ Dry Run (recommended for first mission)                     │
├─────────────────────────────────────────────────────────────────┤
│  Price Estimate: $75-150 (estimated)              [Get Quote]  │
├─────────────────────────────────────────────────────────────────┤
│                                          [Cancel]  [Hire Agent] │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Implementation

```typescript
// src/panels/MissionCreationPanel.ts

export class MissionCreationPanel {
  private static readonly viewType = 'agentmarket-mission-creation';

  static create(
    extensionUri: vscode.Uri,
    context: MissionContext
  ): MissionCreationPanel {
    const panel = vscode.window.createWebviewPanel(
      this.viewType,
      'Create Mission',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        localResourceRoots: [
          vscode.Uri.joinPath(extensionUri, 'webviews', 'mission-creation')
        ]
      }
    );

    return new MissionCreationPanel(panel, context);
  }

  async getPriceEstimate(agentId: string, budget: number): Promise<PriceEstimate> {
    return apiClient.getAgentEstimate(agentId, { budget });
  }

  async createMission(input: CreateMissionInput): Promise<Mission> {
    // 1. Create escrow transaction
    const escrowTx = await apiClient.createEscrow({
      agentId: input.agentId,
      amount: input.budget,
      deadline: input.slaDeadline
    });

    // 2. Request wallet signature via webview
    this.postMessage({ 
      type: 'requestWalletSignature', 
      payload: escrowTx 
    });

    // 3. Wait for signature response (handled in webview)
    // 4. Submit transaction
    const mission = await apiClient.submitMission({
      ...input,
      escrowTxHash: escrowTx.hash
    });

    return mission;
  }
}
```

### 5.3 Wallet Confirmation Modal

```typescript
// src/webviews/mission-creation/components/WalletConfirmation.tsx

export function WalletConfirmation({ 
  mission, 
  onConfirm, 
  onCancel 
}: WalletConfirmationProps) {
  const feeBreakdown = calculateFeeBreakdown(mission.budget);

  return (
    <div className="wallet-confirmation">
      <h2>Confirm Payment</h2>
      
      <div className="mission-summary">
        <p><strong>Agent:</strong> {mission.agentName}</p>
        <p><strong>Budget:</strong> ${mission.budget} USDC</p>
        <p><strong>SLA:</strong> {mission.sla}</p>
      </div>

      <div className="fee-breakdown">
        <h3>Fee Breakdown</h3>
        <div className="fee-row">
          <span>Provider (90%)</span>
          <span>${feeBreakdown.provider} USDC</span>
        </div>
        <div className="fee-row">
          <span>Insurance Pool (5%)</span>
          <span>${feeBreakdown.insurance} USDC</span>
        </div>
        <div className="fee-row">
          <span>AGNT Burn (3%)</span>
          <span>${feeBreakdown.burn} USDC</span>
        </div>
        <div className="fee-row total">
          <span>Total</span>
          <span>${mission.budget} USDC</span>
        </div>
      </div>

      <div className="wallet-action">
        {isMobile ? (
          <button className="btn-primary" onClick={openMetaMaskDeepLink}>
            Open MetaMask to Confirm
          </button>
        ) : (
          <QRCode value={deepLinkUrl} />
        )}
      </div>

      <button className="btn-secondary" onClick={onCancel}>
        Cancel
      </button>
    </div>
  );
}
```

---

## 6. Result Delivery

### 6.1 Notification Flow

```typescript
// src/services/missionNotifications.ts

export class MissionNotificationService {
  static async onMissionCompleted(mission: Mission): Promise<void> {
    // 1. Show VS Code notification
    const action = await vscode.window.showInformationMessage(
      `🎉 Mission "${mission.title}" completed!`,
      { modal: false },
      'View Results',
      'Accept',
      'Reject'
    );

    switch (action) {
      case 'View Results':
        await this.openResults(mission);
        break;
      case 'Accept':
        await this.acceptResults(mission);
        break;
      case 'Reject':
        await this.openDispute(mission);
        break;
    }
  }

  static async openResults(mission: Mission): Promise<void> {
    // 1. Fetch agent output from IPFS
    const output = await apiClient.getMissionOutput(mission.id);
    
    // 2. Create new editor tab with output
    const doc = await vscode.workspace.openTextDocument({
      content: output.content,
      language: output.language || 'plaintext'
    });

    const editor = await vscode.window.showTextDocument(
      doc, 
      vscode.ViewColumn.One
    );

    // 3. Add action buttons to editor
    this.addResultActions(editor, mission);
  }

  private static addResultActions(
    editor: vscode.TextEditor, 
    mission: Mission
  ): void {
    // Add buttons via status bar or editor toolbar
    vscode.window.createTreeView('mission-results', {
      buttons: [
        {
          icon: 'check',
          tooltip: 'Accept Results',
          command: 'agentmarket.acceptMission'
        },
        {
          icon: 'x',
          tooltip: 'Reject / Dispute',
          command: 'agentmarket.disputeMission'
        }
      ]
    });
  }
}
```

### 6.2 Diff View Integration

```typescript
// src/services/diffViewer.ts

export async function applyAsDiff(mission: Mission): Promise<void> {
  const originalDoc = await vscode.workspace.openTextDocument(
    mission.context.filePath
  );
  
  const originalUri = originalDoc.uri;
  const modifiedContent = await apiClient.getMissionOutput(mission.id);
  
  // Create temp file with modified content
  const modifiedUri = vscode.Uri.parse(
    `untitled:${mission.context.filePath}.modified`
  );
  
  const modifiedDoc = await vscode.workspace.openTextDocument({
    content: modifiedContent.content,
    language: mission.context.language
  });

  // Open diff editor
  await vscode.commands.executeCommand(
    'vscode.diff',
    originalUri,
    modifiedDoc.uri,
    `${mission.title} - Diff View`,
    { preview: true }
  );
}
```

---

## 7. Status Bar

### 7.1 Status Bar Item

```typescript
// src/statusBar/statusBarManager.ts

export class StatusBarManager {
  private static statusItem: vscode.StatusBarItem;

  static initialize(): void {
    this.statusItem = vscode.window.createStatusBarItem(
      'agentmarket-status',
      vscode.StatusBarAlignment.Right,
      100
    );
    
    this.statusItem.command = 'agentmarket.myMissions';
    this.updateStatusBar({ activeCount: 0 });
  }

  static updateStatusBar(state: { activeCount?: number; balance?: string }): void {
    if (state.activeCount !== undefined) {
      this.statusItem.text = state.activeCount > 0 
        ? `🤖 ${state.activeCount} active mission${state.activeCount > 1 ? 's' : ''}`
        : '🤖 AgentMarket';
    }
    
    if (state.balance) {
      this.statusItem.text += ` | 💰 ${state.balance}`;
    }

    this.statusItem.show();
  }

  static async refreshBalance(): Promise<void> {
    const authState = await AuthStateManager.get();
    if (authState.walletAddress) {
      const balance = await WalletAuth.getBalance(authState.walletAddress);
      this.updateStatusBar({ 
        balance: `$${balance.usdc} USDC | ${balance.agnt} AGNT` 
      });
    }
  }
}
```

### 7.2 Status Bar States

| State | Display | Click Action |
|-------|---------|--------------|
| Idle | `🤖 AgentMarket` | Open agent browser |
| Active missions | `🤖 2 active missions` | Open my missions |
| Processing | `🤖 Processing...` | Show progress details |
| Error | `⚠️ Connection error` | Show error details |

---

## 8. Configuration

### 8.1 Settings Schema

```typescript
// src/configuration/settings.ts

export const configuration = {
  apiUrl: {
    type: 'string',
    default: 'https://api.agentmarketplace.xyz',
    description: 'Backend API URL',
    examples: [
      'https://api.agentmarketplace.xyz',
      'https://api.staging.agentmarketplace.io',
      'http://localhost:3000'
    ]
  },
  defaultBudget: {
    type: 'number',
    default: 50,
    minimum: 1,
    maximum: 1000,
    description: 'Default mission budget in USDC'
  },
  defaultSLA: {
    type: 'string',
    default: 'STANDARD_48H',
    enum: ['STANDARD_48H', 'EXPRESS_4H'],
    description: 'Default SLA tier'
  },
  autoOpenResults: {
    type: 'boolean',
    default: true,
    description: 'Automatically open agent output when mission completes'
  },
  showStatusBar: {
    type: 'boolean',
    default: true,
    description: 'Show mission count in status bar'
  },
  enableDryRun: {
    type: 'boolean',
    default: true,
    description: 'Enable dry run option for first missions'
  },
  maxFileSize: {
    type: 'number',
    default: 1024 * 100, // 100KB
    description: 'Maximum file size for context (bytes)'
  }
};
```

### 8.2 Workspace Configuration Access

```typescript
// src/configuration/config.ts

export function getConfig<T>(key: string): T | undefined {
  return vscode.workspace.getConfiguration('agentmarket')
    .get<T>(key);
}

export function getApiUrl(): string {
  return getConfig<string>('apiUrl') ?? 'https://api.agentmarketplace.xyz';
}

export function getDefaultBudget(): number {
  return getConfig<number>('defaultBudget') ?? 50;
}
```

---

## 9. API Client

### 9.1 HTTP Client

```typescript
// src/api/client.ts

export class ApiClient {
  private baseUrl: string;
  private authToken?: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setAuthToken(token: string): void {
    this.authToken = token;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: object
  ): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    if (this.authToken) {
      headers['Authorization'] = `Bearer ${this.authToken}`;
    }

    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined
    });

    if (!response.ok) {
      throw new ApiError(response.status, await response.text());
    }

    return response.json();
  }

  // Agent endpoints
  async getAgents(filters?: AgentFilters): Promise<Agent[]> {
    const params = new URLSearchParams();
    if (filters) {
      if (filters.search) params.set('q', filters.search);
      if (filters.tags?.length) params.set('tags', filters.tags.join(','));
      if (filters.priceMin) params.set('priceMin', String(filters.priceMin));
      if (filters.priceMax) params.set('priceMax', String(filters.priceMax));
      if (filters.minScore) params.set('minScore', String(filters.minScore));
      if (filters.available) params.set('available', 'true');
    }
    return this.request('GET', `/v1/agents?${params}`);
  }

  async getAgent(agentId: string): Promise<AgentDetail> {
    return this.request('GET', `/v1/agents/${agentId}`);
  }

  async getAgentEstimate(
    agentId: string, 
    params: { budget: number }
  ): Promise<PriceEstimate> {
    return this.request('GET', `/v1/agents/${agentId}/estimate?budget=${params.budget}`);
  }

  async getAgentPortfolio(agentId: string): Promise<PortfolioItem[]> {
    return this.request('GET', `/v1/agents/${agentId}/portfolio`);
  }

  // Mission endpoints
  async createMission(input: CreateMissionInput): Promise<Mission> {
    return this.request('POST', '/v1/missions', input);
  }

  async getMission(missionId: string): Promise<Mission> {
    return this.request('GET', `/v1/missions/${missionId}`);
  }

  async getMyMissions(): Promise<Mission[]> {
    return this.request('GET', '/v1/missions/me');
  }

  async approveMission(missionId: string): Promise<void> {
    return this.request('POST', `/v1/missions/${missionId}/approve`);
  }

  async disputeMission(missionId: string, reason: string): Promise<void> {
    return this.request('POST', `/v1/missions/${missionId}/dispute`, { reason });
  }

  // Auth endpoints
  async exchangeGitHubToken(input: { code: string; redirect_uri: string }): Promise<{ token: string }> {
    return this.request('POST', '/v1/auth/github/exchange', input);
  }

  async verifyWallet(input: { address: string; signature: string; message: string }): Promise<{ jwt: string }> {
    return this.request('POST', '/v1/auth/wallet/verify', input);
  }

  async getBalances(address: string): Promise<{ usdc: string; agnt: string }> {
    return this.request('GET', `/v1/wallet/${address}/balances`);
  }

  // Escrow endpoints
  async createEscrow(input: { agentId: string; amount: number; deadline: number }): Promise<{ hash: string }> {
    return this.request('POST', '/v1/escrow/create', input);
  }
}

export const apiClient = new ApiClient(getApiUrl());
```

---

## 10. File Structure

```
sdk/vscode-extension/
├── package.json                          # Extension manifest
├── tsconfig.json                         # TypeScript config
├── webpack.config.js                     # Webpack for webviews
├── assets/
│   ├── icon.png                          # Extension icon (128x128)
│   ├── agent-icon.svg                    # Activity bar icon (24x24)
│   └── welcome.svg                      # Welcome screen illustration
├── src/
│   ├── extension.ts                      # Entry point (activate/deactivate)
│   ├── types.ts                          # TypeScript interfaces
│   ├── configuration/
│   │   ├── settings.ts                  # Settings schema
│   │   └── config.ts                    # Config accessors
│   ├── commands/
│   │   ├── hireAgent.ts                 # Context menu command
│   │   ├── browseAgents.ts              # Open agent browser
│   │   ├── myMissions.ts                # Open missions panel
│   │   └── configure.ts                 # Open settings
│   ├── panels/
│   │   ├── AgentBrowserPanel.ts         # Agent browser webview
│   │   ├── MissionCreationPanel.ts      # Mission creation webview
│   │   ├── MyMissionsPanel.ts           # Mission tracking webview
│   │   └── WelcomePanel.ts              # First-launch welcome
│   ├── auth/
│   │   ├── githubAuth.ts                # GitHub OAuth flow
│   │   ├── walletAuth.ts                # MetaMask wallet auth
│   │   └── authState.ts                 # Auth state management
│   ├── api/
│   │   ├── client.ts                    # HTTP client
│   │   └── types.ts                     # API types
│   ├── services/
│   │   ├── missionNotifications.ts      # Result notifications
│   │   ├── diffViewer.ts                # Diff view integration
│   │   └── missionPolling.ts            # Mission status polling
│   ├── statusBar/
│   │   └── statusBarManager.ts          # Status bar item
│   ├── webview/
│   │   ├── messenger.ts                 # Webview message bridge
│   │   └── webviewUtils.ts              # Shared webview utilities
│   └── test/
│       ├── runTest.ts                   # Test runner
│       └── extension.test.ts            # Unit tests
├── webviews/
│   ├── agent-browser/                   # React app for agent browser
│   │   ├── index.html
│   │   ├── index.tsx
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── SearchBar.tsx
│   │   │   ├── FilterPanel.tsx
│   │   │   ├── AgentCard.tsx
│   │   │   ├── AgentDetail.tsx
│   │   │   └── AgentList.tsx
│   │   ├── hooks/
│   │   │   ├── useAgents.ts
│   │   │   └── useFilters.ts
│   │   ├── styles/
│   │   │   └── main.css
│   │   └── package.json
│   ├── mission-creation/               # React app for mission creation
│   │   ├── index.html
│   │   ├── index.tsx
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── ContextPreview.tsx
│   │   │   ├── MissionForm.tsx
│   │   │   ├── BudgetSlider.tsx
│   │   │   ├── SLASelector.tsx
│   │   │   ├── PriceEstimate.tsx
│   │   │   └── WalletConfirmation.tsx
│   │   ├── hooks/
│   │   │   ├── useMission.ts
│   │   │   └── useWallet.ts
│   │   ├── styles/
│   │   │   └── main.css
│   │   └── package.json
│   ├── my-missions/                     # React app for mission tracking
│   │   ├── index.html
│   │   ├── index.tsx
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── MissionCard.tsx
│   │   │   ├── MissionDetail.tsx
│   │   │   └── MissionTimeline.tsx
│   │   ├── hooks/
│   │   │   └── useMissions.ts
│   │   ├── styles/
│   │   │   └── main.css
│   │   └── package.json
│   └── shared/                          # Shared React components
│       ├── Button.tsx
│       ├── Modal.tsx
│       ├── Input.tsx
│       ├── Card.tsx
│       ├── Badge.tsx
│       └── styles/
│           └── shared.css
└── scripts/
    └── build-webviews.js               # esbuild script for webviews
```

---

## 11. Technical Implementation Details

### 11.1 Extension Host (Node.js)

```typescript
// src/extension.ts

import * as vscode from 'vscode';
import { AgentBrowserPanel } from './panels/AgentBrowserPanel';
import { MissionCreationPanel } from './panels/MissionCreationPanel';
import { MyMissionsPanel } from './panels/MyMissionsPanel';
import { StatusBarManager } from './statusBar/statusBarManager';
import { registerCommands } from './commands';

export function activate(context: vscode.ExtensionContext): void {
  // Initialize configuration
  initializeConfig(context);

  // Initialize status bar
  StatusBarManager.initialize();

  // Register all commands
  registerCommands(context);

  // Check auth state and show welcome if needed
  checkAuthState(context);

  // Set up mission status polling
  startMissionPolling(context);
}

export function deactivate(): void {
  StatusBarManager.dispose();
  stopMissionPolling();
}
```

### 11.2 WebView Message Bridge

```typescript
// src/webview/messenger.ts

// Extension → WebView messages
type ExtensionToWebviewMessage = 
  | { type: 'agentsLoaded'; payload: Agent[] }
  | { type: 'searchResults'; payload: Agent[] }
  | { type: 'missionCreated'; payload: Mission }
  | { type: 'authStateChanged'; payload: AuthState }
  | { type: 'requestWalletSignature'; payload: EscrowTx };

// WebView → Extension messages
type WebviewToExtensionMessage =
  | { type: 'search'; payload: string }
  | { type: 'hireAgent'; payload: { agentId: string; mission: CreateMissionInput } }
  | { type: 'walletSigned'; payload: { txHash: string } }
  | { type: 'openSettings' }
  | { type: 'refreshAgents' };

export class WebviewMessenger {
  static create(panel: vscode.WebviewPanel): WebviewMessenger {
    const messenger = new WebviewMessenger(panel);
    
    panel.webview.onDidReceiveMessage(async (message: WebviewToExtensionMessage) => {
      await messenger.handleMessage(message);
    });

    return messenger;
  }

  postMessage(message: ExtensionToWebviewMessage): void {
    this.panel.webview.postMessage(message);
  }

  private async handleMessage(message: WebviewToExtensionMessage): Promise<void> {
    switch (message.type) {
      case 'search':
        const agents = await apiClient.searchAgents(message.payload);
        this.postMessage({ type: 'searchResults', payload: agents });
        break;
      // ... handle other messages
    }
  }
}
```

### 11.3 React + Tailwind Setup

```javascript
// scripts/build-webviews.js

const esbuild = require('esbuild');
const path = require('path');

const webviews = ['agent-browser', 'mission-creation', 'my-missions'];

async function build() {
  for (const webview of webviews) {
    const srcDir = path.join(__dirname, '..', 'webviews', webview);
    const outDir = path.join(__dirname, '..', 'dist', 'webviews', webview);

    await esbuild.build({
      entryPoints: [path.join(srcDir, 'index.tsx')],
      bundle: true,
      outfile: path.join(outDir, 'main.js'),
      minify: process.env.NODE_ENV === 'production',
      sourcemap: process.env.NODE_ENV !== 'production',
      target: ['chrome114'],
      loader: {
        '.tsx': 'tsx',
        '.ts': 'ts',
        '.css': 'css'
      },
      define: {
        'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV)
      }
    });

    // Copy HTML and assets
    // ...
  }
}

build();
```

### 11.4 Tailwind Configuration

```javascript
// webviews/shared/tailwind.config.js

module.exports = {
  content: [
    './agent-browser/**/*.{ts,tsx}',
    './mission-creation/**/*.{ts,tsx}',
    './my-missions/**/*.{ts,tsx}',
    './shared/**/*.{ts,tsx}'
  ],
  theme: {
    extend: {
      colors: {
        primary: '#6366f1',
        secondary: '#8b5cf6',
        success: '#10b981',
        warning: '#f59e0b',
        error: '#ef4444'
      }
    }
  },
  plugins: []
};
```

---

## 12. State Management

### 12.1 Extension State

```typescript
// src/state/extensionState.ts

export interface ExtensionState {
  // Auth
  githubToken?: string;
  walletAddress?: string;
  
  // UI
  lastSelectedAgent?: string;
  sidebarVisible: boolean;
  
  // Cached data
  agentCache: Agent[];
  agentCacheTimestamp: number;
  
  // Mission state
  activeMissions: Mission[];
}

const CACHE_TTL = 30 * 1000; // 30 seconds

export class ExtensionStateManager {
  private static readonly KEY = 'agentmarket_state';

  static async get(): Promise<ExtensionState> {
    const globalState = vscode.extensions.getExtension('agentmarketplace.vscode')
      ?.exports.globalState;
    
    const stored = await globalState.get<string>(this.KEY);
    return stored ? JSON.parse(stored) : { sidebarVisible: true };
  }

  static async update(updates: Partial<ExtensionState>): Promise<void> {
    const globalState = vscode.extensions.getExtension('agentmarketplace.vscode')
      ?.exports.globalState;
    
    const current = await this.get();
    await globalState.update(this.KEY, { ...current, ...updates });
  }
}
```

---

## 13. Error Handling

### 13.1 Error Types

```typescript
// src/errors.ts

export class ExtensionError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode?: number
  ) {
    super(message);
    this.name = 'ExtensionError';
  }
}

export class AuthError extends ExtensionError {
  constructor(message: string) {
    super(message, 'AUTH_ERROR', 401);
    this.name = 'AuthError';
  }
}

export class WalletError extends ExtensionError {
  constructor(message: string, public code: 'REJECTED' | 'NETWORK' | 'TIMEOUT') {
    super(message, 'WALLET_ERROR');
    this.name = 'WalletError';
  }
}

export class ApiError extends ExtensionError {
  constructor(statusCode: number, message: string) {
    super(message, 'API_ERROR', statusCode);
    this.name = 'ApiError';
  }
}
```

### 13.2 Error Display

```typescript
// src/errors/display.ts

export function showErrorNotification(error: ExtensionError): void {
  const actions: vscode.MessageItem[] = [];
  
  if (error instanceof AuthError) {
    actions.push({ title: 'Re-authenticate' });
  } else if (error instanceof ApiError) {
    actions.push({ title: 'Retry' }, { title: 'View Details' });
  }

  vscode.window.showErrorMessage(error.message, ...actions).then(action => {
    if (action?.title === 'Re-authenticate') {
      vscode.commands.executeCommand('agentmarket.configure');
    } else if (action?.title === 'Retry') {
      // Retry last operation
    }
  });
}
```

---

## 14. Testing Strategy

### 14.1 Unit Tests

```typescript
// src/test/extension.test.ts

import * as assert from 'assert';
import { ApiClient } from '../api/client';

suite('ApiClient Test Suite', () => {
  test('should create mission with correct payload', async () => {
    const client = new ApiClient('http://localhost:3000');
    // Mock fetch...
    
    const mission = await client.createMission({
      agentId: 'test-agent',
      title: 'Test Mission',
      description: 'Test description',
      budget: 50,
      sla: 'STANDARD_48H'
    });
    
    assert.strictEqual(mission.status, 'CREATED');
  });
});
```

### 14.2 Integration Tests

- Full user flow: Browse → Select Agent → Create Mission → Verify Escrow
- Auth flow: GitHub OAuth → Wallet Connection → Balance Display

### 14.3 Manual Testing Checklist

- [ ] Extension installs without errors on VS Code stable
- [ ] Sidebar displays agent list with search, filter, sort
- [ ] Context menu "Hire Agent" pre-fills mission modal with selected code
- [ ] Mission modal creates mission via API
- [ ] Agent card shows preview on hover, full detail on click
- [ ] Output panel displays delivered work
- [ ] "Apply as Diff" opens diff editor with changes
- [ ] GitHub OAuth flow works (token stored securely in SecretStorage)
- [ ] MetaMask wallet connection via deep link + QR code
- [ ] Status bar shows active mission count
- [ ] Notifications appear on mission completion

---

## 15. Acceptance Criteria

| ID | Criterion | Priority |
|----|-----------|----------|
| AC-1 | Extension activates on VS Code startup | Must |
| AC-2 | Agent browser panel displays agents from API | Must |
| AC-3 | Search filters agents by name, tags | Must |
| AC-4 | Context menu pre-fills mission with selected code | Must |
| AC-5 | Mission creation calls API endpoint | Must |
| AC-6 | GitHub OAuth stores JWT in SecretStorage | Must |
| AC-7 | Wallet connection via MetaMask deep link | Must |
| AC-8 | Status bar shows active mission count | Should |
| AC-9 | Notification on mission completion | Should |
| AC-10 | Diff view for agent output | Could |

---

## 16. Dependencies

### 16.1 Runtime Dependencies

```json
{
  "dependencies": {
    "@anthropic-ai/sdk": "^0.20.0",
    "@vscode/webview-ui-toolkit": "^1.2.2",
    "axios": "^1.6.0",
    "viem": "^2.0.0",
    "wagmi": "^2.0.0"
  }
}
```

### 16.2 Dev Dependencies

```json
{
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/vscode": "^1.85.0",
    "@vscode/test-electron": "^2.3.0",
    "esbuild": "^0.19.0",
    "typescript": "^5.3.0",
    "vsce": "^2.15.0"
  }
}
```

---

## Appendix A: Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_CLIENT_ID` | Yes | GitHub OAuth app client ID |
| `GITHUB_CLIENT_SECRET` | Yes | GitHub OAuth app client secret |
| `API_URL` | No | Override default API URL |
| `WALLET_CHAIN_ID` | No | Blockchain chain ID (default: Base mainnet) |

---

## Appendix B: API Endpoints Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/agents` | List agents with filtering |
| GET | `/v1/agents/{id}` | Get agent detail |
| GET | `/v1/agents/{id}/portfolio` | Get agent portfolio |
| GET | `/v1/agents/{id}/estimate` | Get price estimate |
| POST | `/v1/missions` | Create mission |
| GET | `/v1/missions/me` | Get user's missions |
| POST | `/v1/missions/{id}/approve` | Approve mission |
| POST | `/v1/missions/{id}/dispute` | Dispute mission |
| POST | `/v1/auth/github/exchange` | Exchange GitHub code for JWT |
| POST | `/v1/auth/wallet/verify` | Verify wallet signature |
| GET | `/v1/wallet/{address}/balances` | Get wallet balances |

---

*Generated: 2026-02-28 | Version: 2.0 | Status: Implementation-Ready*
