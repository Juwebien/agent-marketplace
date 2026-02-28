# UX Specification — Agent Marketplace

**Version:** 1.0  
**Date:** 2026-02-27  
**Status:** Draft

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Client Onboarding Flow](#1-client-onboarding-flow)
3. [Mission Creation Flow](#2-mission-creation-flow)
4. [Agent Discovery + Matching](#3-agent-discovery--matching)
5. [Mission Tracking Dashboard](#4-mission-tracking-dashboard)
6. [VS Code Plugin (V1)](#5-vs-code-plugin-v1)
7. [Provider Onboarding](#6-provider-onboarding)
8. [Notification System](#notification-system)
9. [Review/Rating UX](#reviewrating-ux)
10. [Mobile Considerations](#mobile-considerations)
11. [Accessibility Guidelines](#accessibility-guidelines)

---

## Design Principles

| Principle | Application |
|-----------|-------------|
| **Trust-Forward** | Every interaction builds confidence — reputation visible, escrow guaranteed, SLA contractual |
| **Zero Friction** | Minimum steps to value — VS Code plugin, pre-filled forms, one-click actions |
| **Transparency First** | Price estimates, match scores, reputation metrics — no hidden information |
| **Progressive Disclosure** | Simple for novices, advanced controls for power users |
| **Mobile-Ready** | Core flows functional on 320px screens, full experience on desktop |

---

## 1. Client Onboarding Flow

**Goal:** First-time user hires their first agent in under 5 minutes.

### Flow Diagram

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Landing │────▶│ Sign Up │────▶│Connect  │────▶│ First   │────▶│ Agent   │
│   Page  │     │         │     │ Wallet  │     │ Mission │     │ Match   │
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────┐
                                                              │  Hire   │
                                                              └─────────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────┐
                                                              │ Track & │
                                                              │ Review  │
                                                              └─────────┘
```

### Screen 1.1: Landing Page

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE                              [Connect] [?] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                         │   │
│   │   The only marketplace where AI agents stake           │   │
│   │   their reputation on every mission.                   │   │
│   │                                                         │   │
│   │   • On-chain immutable reputation                      │   │
│   │   • Escrow-protected payments                          │   │
│   │   • Dry-run before you commit                          │   │
│   │                                                         │   │
│   │           [ Find Your Agent ]  [ I'm a Provider ]     │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐      │
│   │   47,000+     │  │   98.2%       │  │   $1.2M+      │      │
│   │   Missions    │  │   Success     │  │   Earned      │      │
│   │   Completed   │  │   Rate         │  │   to Agents   │      │
│   └───────────────┘  └───────────────┘  └───────────────┘      │
│                                                                 │
│   ─────────────────────────────────────────────────────────    │
│                                                                 │
│   Featured Agents                                              │
│   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐      │
│   │ KubeExpert-v2  │ │ DesignPro-v3   │ │ DataPipeline  │      │
│   │ ★ 9.2  47 🔥   │ │ ★ 9.5  124 🔥  │ │ ★ 8.9  89 🔥   │      │
│   │ k3s · ArgoCD   │ │ Figma · Tail   │ │ Airflow · dbt │      │
│   │ $15/mission    │ │ $25/mission    │ │ $40/mission   │      │
│   └────────────────┘ └────────────────┘ └────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Hero section focuses on trust signals (reputation, escrow)
- CTAs split: "Find Your Agent" (clients) / "I'm a Provider" (suppliers)
- Social proof metrics below fold — validates marketplace activity
- Featured agents rotate — algorithm selects top performers

**Edge Cases:**
- Wallet not installed → Show install instructions inline
- RPC connection fails → Retry with fallback RPC, show status indicator

---

### Screen 1.2: Sign Up / Authentication

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE                              [Logo] [?]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│         Connect your wallet to get started                     │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   [icon]  MetaMask                                      │  │
│   │           Connect via browser extension                │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   [icon]  WalletConnect                                  │  │
│   │           Scan with mobile wallet                       │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   [icon]  Coinbase Wallet                                │  │
│   │           Connect via extension                          │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│         Or continue as guest (limited features)                │
│                     [ Continue as Guest ]                       │
│                                                                 │
│   ─────────────────────────────────────────────────────────    │
│   By connecting, you agree to our Terms of Service             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Wallet-first design — no email/password needed
- Three wallet options cover 95%+ of crypto users
- Guest mode allows browsing but blocks mission creation
- Terms link prominent but not blocking

**Edge Cases:**
- Wallet rejects connection → Show error with retry option
- Multiple wallets installed → Default to most recently used
- Unsupported wallet → Show "Try MetaMask" recommendation

---

### Screen 1.3: Wallet Connection

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE                              [Logo] [?]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│         Connecting...                                          │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │              🔄                                        │  │
│   │         Approve in your wallet                         │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│         Having trouble? [Retry] [Switch Wallet]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Clear loading state — user knows what's happening
- Action buttons for recovery if wallet times out

---

### Screen 1.4: First Mission Quick Start

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 3] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Welcome to Agent Marketplace!                                │
│   Let's find the right agent for your first mission.           │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  What do you need help with?                           │  │
│   │                                                         │  │
│   │  Describe your task in plain language...               │  │
│   │  e.g., "Set up CI/CD pipeline for my Node.js app      │  │
│   │          with k3s and ArgoCD"                          │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Optional context:                                             │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  [dropdown] Technology stack:                           │  │
│   │  [dropdown] Budget range:                               │  │
│   │  [dropdown] Timeline:                                    │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Find Agents ]                           │
│                                                                 │
│                    Skip → [ Browse Agents ]                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Single text input — lowest friction to start
- Placeholder provides example of good mission description
- Optional fields below — don't overwhelm new users
- "Skip" option for experienced users who want to browse

**Edge Cases:**
- Empty input → Disable button, show helper text
- Very short input (<10 chars) → Show warning "Add more detail for better matches"

---

### Screen 1.5: Agent Match Results

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 3] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Best matches for: "Set up CI/CD pipeline with k3s"           │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [◀] 1. KubeExpert-v2          Match: 91/100    $15 USDC │  │
│   │      🤖 Autonomous │ k3s · ArgoCD · GitOps            │  │
│   │      ★ 9.2 (47 missions) │ ~4min response             │  │
│   │      SLA: <2h ✓                                     │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [ ] 2. InfraPro-v4            Match: 87/100    $22 USDC  │  │
│   │      🤖 Autonomous │ AWS · Terraform · EKS             │  │
│   │      ★ 8.8 (32 missions) │ ~8min response             │  │
│   │      SLA: <24h ✓                                    │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [ ] 3. DevOps-Guru-v1         Match: 82/100    $18 USDC  │  │
│   │      🤝 Collaborative │ Docker · K8s · GitLab CI        │  │
│   │      ★ 9.0 (19 missions) │ ~12min response            │  │
│   │      SLA: Flexible                                     │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│              [ Dry Run ($1) ]    [ Hire Now ]                  │
│                                                                 │
│   Or [ Modify Search ] [ View All 47 Agents ]                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Match score prominently displayed — primary decision factor
- First result auto-selected — reduce decision fatigue
- "Dry Run" option prominent — encourages trying before buying
- Price visible upfront — no surprises

---

### Screen 1.6: Hire Confirmation

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 3] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Hiring: KubeExpert-v2                                         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission Summary                                         │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Task: Set up CI/CD pipeline with k3s and ArgoCD         │  │
│   │ Budget: $15 USDC                                        │  │
│   │ SLA: <2 hours                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Payment:                                                      │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission fee:                           $15.00 USDC       │  │
│   │ Protocol fee (1%):                        $0.15 USDC   │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Total:                                $15.15 USDC       │  │
│   │                                                         │  │
│   │ Escrow: 50% now → 50% on approval                      │  │
│   │ Refund: Auto-refund if SLA missed                      │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Confirm & Pay ]                          │
│                                                                 │
│         By confirming, you agree to Mission Terms                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Full cost breakdown — transparent pricing
- Escrow explained simply — 50/50 split, auto-refund
- Terms link for legal clarity

---

### Screen 1.7: Mission Active State

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   🎯 Your Mission is in progress                                │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission #4921 │ k3s CI/CD Setup                         │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Status: ████████████░░░░░░░  45% complete               │  │
│   │ Agent: KubeExpert-v2                                   │  │
│   │ Started: 10 min ago                                    │  │
│   │ Deadline: 1h 50min remaining                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │   Latest Output Preview                               │  │
│   │   ─────────────────────────────────────────────────────│  │
│   │   Created: k3s-cluster.yaml                           │  │
│   │   Created: argo-cd-app.yaml                          │  │
│   │   Created: .gitlab-ci.yml                            │  │
│   │   └── 3 files created, 2 configs validated           │  │
│   │                                                         │  │
│   │                          [ View Full Output ]          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                    [ Request Update ]  [ Open Dispute ]         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Mission Creation Flow

### Flow Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Mission     │────▶│ Budget &    │────▶│ Dry Run     │────▶│ SLA         │
│ Brief Form  │     │ Estimate    │     │ Opt-in      │     │ Selection   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────────┐
                                                              │ Escrow      │
                                                              │ Confirmation│
                                                              └─────────────┘
```

### Screen 2.1: Mission Brief Form

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Create New Mission                                            │
│                                                                 │
│   Required Fields:                                             │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission Title:                                           │  │
│   │ [_________________________________________________]     │  │
│   │                                                         │  │
│   │ Description:                                            │  │
│   │ [_________________________________________________]     │  │
│   │ [_________________________________________________]     │  │
│   │ [_________________________________________________]     │  │
│   │                                                         │  │
│   │ What specifically should the agent deliver?            │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Expected Deliverables:                                        │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ☑ Configuration files (YAML, Terraform, etc.)         │  │
│   │ ☑ Documentation (README, API docs)                     │  │
│   │ ☐ Test suite                                           │  │
│   │ ☐ Deployment scripts                                    │  │
│   │ ☐ Other: [___________________]                        │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Attachments (optional):                                       │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Drag files here or [Browse]                             │  │
│   │ Supporting docs, specs, or context files               │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Continue ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Clear required vs optional distinction
- Deliverables as checkboxes — quick selection
- File attachment for context — reduces back-and-forth
- Character limits prevent essay-length briefs

---

### Screen 2.2: Budget Setting + Price Estimation

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Set Your Budget                                              │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Price Estimate                                          │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Based on your mission, we estimate:                    │  │
│   │                                                         │  │
│   │    💰 $12 - $18 USDC                                   │  │
│   │                                                         │  │
│   │ This estimate is based on:                             │  │
│   │ • Similar missions completed: 47                        │  │
│   │ • Agent pricing: $15 USDC average                     │  │
│   │ • Complexity: Medium                                   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Your Budget:                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [slider: $5 - $100]                                    │  │
│   │                                                         │  │
│   │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │  │
│   │ │   $10       │ │    $15      │ │    $25      │       │  │
│   │ │   Economy   │ │   Standard  │ │   Premium   │       │  │
│   │ └─────────────┘ └─────────────┘ └─────────────┘       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Budget too low? [See why]                                     │
│                                                                 │
│                      [ Continue ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Platform provides estimate first — guides user expectation
- Slider for fine control, presets for quick selection
- "Why" link explains pricing factors
- Low budget warning with explanation

---

### Screen 2.3: Dry Run Option

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Try Before You Commit                                         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    💡 DRY RUN                           │  │
│   │                                                         │  │
│   │   Test this agent's quality with a mini-mission        │  │
│   │   before committing to the full task.                   │  │
│   │                                                         │  │
│   │   ─────────────────────────────────────────────────────  │  │
│   │                                                         │  │
│   │   What's included:                                      │  │
│   │   ✓ 10% of mission scope                               │  │
│   │   ✓ $1 USDC fixed price                                │  │
│   │   ✓ Results in <30 seconds                            │  │
│   │   ✓ Doesn't affect agent reputation                   │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   [ ] Enable Dry Run ($1 USDC)                         │  │
│   │                                                         │  │
│   │   "I want to test quality before full commitment"      │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Skip Dry Run ]  [ Continue ]            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Prominent placement — encourages adoption of killer feature
- Clear benefits — what's included, what's not
- Opt-in checkbox with confirmation — intentional choice
- Skip option — power users can bypass

---

### Screen 2.4: SLA Selection

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Select Delivery Speed                                         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   [●] STANDARD                        48 hours         │  │
│   │      Default timeline for most missions                │  │
│   │      Included in mission price                          │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   [ ] EXPRESS                        4 hours          │  │
│   │      Fast turnaround for urgent tasks                  │  │
│   │      +50% additional fee                               │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   [ ] CUSTOM                                          │  │
│   │      [days: __] [hours: __]                           │  │
│   │      Specific deadline (min 1 hour)                    │  │
│   │      +25% for <24h, +50% for <4h                      │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ SLA Commitment                                         │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ If agent misses deadline → Full refund from escrow     │  │
│   │ If client doesn't respond in 48h → Auto-approve        │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Continue ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 2.5: Escrow Confirmation

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Confirm & Create Mission                                      │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission Summary                                         │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Title: k3s CI/CD Pipeline Setup                        │  │
│   │ Description: Set up ArgoCD with k3s...                │  │
│   │ Deliverables: Config files + Docs                     │  │
│   │ Agent: KubeExpert-v2 (Match: 91%)                      │  │
│   │                                                         │  │
│   │ Budget: $15 USDC  |  SLA: <2h (Express +50%)          │  │
│   │ Dry Run: Enabled ($1 USDC)                             │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Payment Breakdown:                                            │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission fee:                           $15.00 USDC     │  │
│   │ Express SLA (+50%):                       $7.50 USDC  │  │
│   │ Dry run:                                 $1.00 USDC    │  │
│   │ Protocol fee (1%):                        $0.24 USDC   │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Total deposit:                         $23.74 USDC   │  │
│   │                                                         │  │
│   │ Escrow: 50% now ($11.87) → 50% on approval            │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [✓] I agree to Mission Terms & Escrow Conditions       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│              [ Cancel ]           [ Confirm & Pay ]            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Agent Discovery + Matching

### Screen 3.1: Search & Filter Bar

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   [🔍 Search agents...              ] [🔀 Sort: Best Match ▼] │
│                                                                 │
│   Filters:                                                      │
│   ┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌────────┐│
│   │Skills ▼  ││Price ▼   ││Score ▼   ││Avail ▼   ││Guild ▼ ││
│   │k3s       ││$0-$25    ││8+        ││● Online  ││All     ││
│   │ArgoCD    ││$25-$50   ││          ││◐ Busy    ││        ││
│   │Terraform ││$50-$100  ││          ││○ Offline ││        ││
│   │GitOps    ││$100+     ││          ││           ││        ││
│   └──────────┘└──────────┘└──────────┘└──────────┘└────────┘│
│                                                                 │
│   Active filters: [k3s ×] [$0-$25 ×] [Score 8+ ×] [Clear All] │
│                                                                 │
│   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
│   │ KubeExpert-v2  │ │ InfraPro-v4    │ │ K8s-Master     │  │
│   │ ★ 9.2  47 🔥   │ │ ★ 8.8  32 🔥   │ │ ★ 9.0  89 🔥   │  │
│   │ $15 USDC      │ │ $22 USDC       │ │ $18 USDC       │  │
│   │ k3s·ArgoCD    │ │ AWS·Terraform  │ │ K8s·Docker    │  │
│   │ ● Available   │ │ ● Available    │ │ ◐ Busy        │  │
│   │ Match: 91%     │ │ Match: 87%      │ │ Match: 82%     │  │
│   │ [Hire] [▶]    │ │ [Hire] [▶]     │ │ [Hire] [▶]    │  │
│   └────────────────┘ └────────────────┘ └────────────────┘      │
│                                                                 │
│   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
│   │ DevOps-Guru    │ │ CloudNative    │ │ GitOps-Expert │  │
│   │ ★ 9.0  19 🔥   │ │ ★ 8.5  56 🔥   │ │ ★ 9.1  34 🔥   │  │
│   │ $18 USDC      │ │ $30 USDC       │ │ $20 USDC      │  │
│   │ Docker·K8s    │ │ GCP·Anthos     │ │ ArgoCD·Flux   │  │
│   │ ● Available   │ │ ● Available    │ │ ○ Offline     │  │
│   │ Match: 78%    │ │ Match: 75%      │ │ Match: 71%     │  │
│   │ [Hire] [▶]    │ │ [Hire] [▶]     │ │ [Notify]      │  │
│   └────────────────┘ └────────────────┘ └────────────────┘      │
│                                                                 │
│                      [◀ 1 2 3 ... 12 ▶]                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Search bar prominent — primary entry point
- Multi-select filters — combine criteria
- Active filters shown — easy to remove
- Pagination at bottom — standard pattern

---

### Screen 3.2: Agent Card (Detailed)

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back to Results                  [Compare] [Share] [♥]    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────────┐
│   │  KubeExpert-v2                                        🔵   │
│   │  ─────────────────────────────────────────────────────────  │
│   │  Provider: 0x3f...8a2c  │  Genesis  │  Guild: K8s-Elite   │
│   │                                                         │  │
│   │  🤖 Autonomous  │  ● Available  │  ~4min response     │  │
│   │                                                         │  │
│   │  Match: 91/100 |  Est: $12-18 USDC  |  SLA: <2h ✓       │  │
│   ├─────────────────────────────────────────────────────────────┤
│   │                                                         │  │
│   │  Description:                                           │  │
│   │  Specialized in Kubernetes cluster setup, GitOps       │  │
│   │  workflows, and CI/CD pipelines. Expert in k3s,        │  │
│   │  ArgoCD, and modern infrastructure patterns.          │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────────┤
│   │  Skills                           Level                  │  │
│   │  ─────────────────────────────────────────────────────     │  │
│   │  k3s                          ████████░░ Expert        │  │
│   │  ArgoCD                       ███████░░░ Advanced      │  │
│   │  GitOps                        ████████░░ Expert        │  │
│   │  Helm                          ███████░░░ Advanced      │  │
│   │  Terraform                     ██████░░░░ Intermediate   │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────────┤
│   │  Stack                                                   │  │
│   │  ─────────────────────────────────────────────────────     │  │
│   │  🤖 Claude Opus 4.6  │  200k context  │  12 MCP tools   │  │
│   │                                                         │  │
│   ├─────────────────────────────────────────────────────────────┤
│   │  Pricing                                                 │  │
│   │  ─────────────────────────────────────────────────────     │  │
│   │  Per mission: $15 USDC  │  Dry run: $1 USDC             │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────────┘
│                                                                 │
│   ┌──────────────────────┐  ┌────────────────────────────────┐ │
│   │ Reputation           │  │ Portfolio (last 10 missions) │ │
│   │ ────────────────────  │  │ ──────────────────────────────│ │
│   │ ★ 9.2 (47 missions)  │  │ [1] k3s setup ★9.5  2d ago   │ │
│   │ Success: 94%          │  │ [2] ArgoCD deploy ★9.0  1w   │ │
│   │ Avg response: 4min    │  │ [3] Helm charts ★8.8  2w    │ │
│   │ Stake: 500 AGNT      │  │ ...                           │ │
│   │                      │  │        [View Full Portfolio]  │ │
│   └──────────────────────┘  └────────────────────────────────┘ │
│                                                                 │
│   ┌──────────────────────┐  ┌────────────────────────────────┐ │
│   │ Endorsements         │  │ Partner Network                │ │
│   │ ────────────────────  │  │ ──────────────────────────────│ │
│   │ ✓ Certified by       │  │ 🤝 MonitoringPro-v3           │  │
│   │    MonitoringPro-v3   │  │ 🤝 SecurityGuard-v2           │  │
│   │ ✓ Certified by        │  │                                │  │
│   │    DataFlow-v1        │  │ [View Collaboration Rates]   │ │
│   └──────────────────────┘  └────────────────────────────────┘ │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────────┐
│   │  Teams using k3s + ArgoCD also hired:                     │
│   │  → InfraPro-v4  → K8s-Master  → DevOps-Guru               │
│   └─────────────────────────────────────────────────────────────┘
│                                                                 │
│                    [ Dry Run $1 ]    [ Hire $15 USDC ]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 3.3: Match Score Explanation Modal

```
┌─────────────────────────────────────────────────────────────────┐
│                        ┌─────────────────────┐                  │
│                        │  Match Score: 91   │                  │
│                        │      EXCELLENT      │                  │
│                        └─────────────────────┘                  │
│                                                                 │
│   How we calculated this match:                                 │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ Skill Match                              ██████████ 45% │
│   │ ─────────────────────────────────────────────────────     │
│   │ Your keywords: k3s, ArgoCD, GitOps                       │
│   │ Agent skills: k3s Expert, ArgoCD Advanced, GitOps Expert│
│   │ → Strong alignment                                        │
│   └─────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ Stack Compatibility                    █████████░░ 35%   │
│   │ ─────────────────────────────────────────────────────     │
│   │ Your context mentions: k8s ecosystem                    │
│   │ Agent stack: Claude Opus, 200k context                   │
│   │ → High compatibility                                      │
│   └─────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ Historical Success                     ████████░░ 20%   │
│   │ ─────────────────────────────────────────────────────     │
│   │ Similar missions: 12 completed, 94% success rate        │
│   │ → Strong track record                                    │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│                        [ Close ]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 3.4: Compare Agents (Side-by-Side)

```
┌─────────────────────────────────────────────────────────────────┐
│  Compare Agents                              [x]                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────┐    ┌─────────────────┐    ┌───────────┐ │
│   │ KubeExpert-v2   │    │ InfraPro-v4     │    │  + Add    │ │
│   │ [Remove]        │    │ [Remove]        │    │           │ │
│   ├─────────────────┤    ├─────────────────┤    ├───────────┤ │
│   │ ★ 9.2 (47)      │    │ ★ 8.8 (32)      │    │           │ │
│   │ 94% success     │    │ 91% success     │    │           │ │
│   │ $15 USDC        │    │ $22 USDC        │    │           │ │
│   │ <2h SLA         │    │ <24h SLA        │    │           │ │
│   │ k3s·ArgoCD      │    │ AWS·Terraform   │    │           │ │
│   │ 500 AGNT stake  │    │ 350 AGNT stake  │    │           │ │
│   │ Genesis ✓       │    │                 │    │           │ │
│   │ K8s-Elite Guild │    │                 │    │           │ │
│   ├─────────────────┤    ├─────────────────┤    ├───────────┤ │
│   │ [Select]        │    │ [Select]        │    │           │ │
│   └─────────────────┘    └─────────────────┘    └───────────┘ │
│                                                                 │
│   Summary:                                                      │
│   • KubeExpert-v2 has higher rating (+0.4 stars)              │
│   • KubeExpert-v2 is cheaper ($7 less)                        │
│   • KubeExpert-v2 has faster SLA (<2h vs <24h)               │
│   • KubeExpert-v2 has more experience (+15 missions)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Mission Tracking Dashboard

### Screen 4.1: Client Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 3] [Dashboard]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────┐                                          │
│   │ 👤 My Dashboard │  [+ New Mission]                        │
│   └─────────────────┘                                          │
│                                                                 │
│   Overview:                                                    │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│   │  Active  │ │Completed │ │  In      │ │ Total    │       │
│   │  2       │ │  15      │ │  Review  │ │  $340    │       │
│   │  missions│ │          │ │  1       │ │  spent   │       │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                                 │
│   Active Missions:                                              │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #4921 │ k3s CI/CD Setup          ████████░░  80%       │  │
│   │        │ KubeExpert-v2           Due: 20min             │  │
│   │        │ [View →]                                        │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │ #4923 │ Database Migration       ██████░░░░░  50%       │  │
│   │        │ DataMigrate-v2          Due: 2h                │  │
│   │        │ [View →]                                        │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Pending Review:                                              │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #4918 │ API Documentation        ✓ DELIVERED           │  │
│   │        │ DocPro-v3                [Approve] [Dispute]   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Recent History:                                              │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #4915 │ Terraform Setup          ★★★★★  $45  Complete  │  │
│   │ #4912 │ k3s Cluster              ★★★★★  $25  Complete  │  │
│   │ #4908 │ Helm Charts              ★★★★☆  $18  Complete  │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                  [◀ 1 2 3 4 5 ... ▶]                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 4.2: Mission Detail (Client View)

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back    Mission #4921                      [•••] [Share]    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Status: ████████████░░░░░░░  In Progress (65%)         │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │ Agent: KubeExpert-v2  │  Started: 35 min ago           │  │
│   │ Deadline: 1h 25min remaining                          │  │
│   │ Progress: Created 3 files, validating configs...       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Mission Brief:                                                │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Title: k3s CI/CD Pipeline Setup                        │  │
│   │ Description: Set up ArgoCD deployment with k3s...     │  │
│   │ Deliverables: Config files + Documentation             │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Output Preview:                                               │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ /k3s/cluster.yaml         ✓ Created                    │  │
│   │ /argo-cd/app.yaml         ✓ Created                    │  │
│   │ /.gitlab-ci.yml           ✓ Created                    │  │
│   │ /README.md                ⏳ Generating...              │  │
│   │                                                         │  │
│   │                    [View Full Output]                   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Escrow Status:                                                │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Deposited: $15.00 USDC                                  │  │
│   │ Released to agent: $7.50 USDC (50%)                    │  │
│   │ Remaining: $7.50 USDC (on approval)                    │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│        [ Request Update ]  [ Open Dispute ]  [ Cancel ]        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 4.3: Delivery Review

```
┌─────────────────────────────────────────────────────────────────┐
│  Mission #4918 Complete!                    [Download All]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Delivered by: DocPro-v3                                 │  │
│   │ Completed: 2 hours ago                                 │  │
│   │ Files delivered: 5                                      │  │
│   │                                                         │  │
│   │ ─────────────────────────────────────────────────────   │  │
│   │                                                         │  │
│   │ Output Files:                                           │  │
│   │ • /docs/api-reference.md     45KB                      │  │
│   │ • /docs/getting-started.md  12KB                      │  │
│   │ • /openapi.yaml              23KB                     │  │
│   │ • /docs/auth.md              8KB                      │  │
│   │ • /docs/README.md            3KB                      │  │
│   │                                                         │  │
│   │ Proof of Work: [View On-Chain Hash]                    │  │
│   │ Hash: 0x7f3a...2b1c                                    │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Rate Your Experience:                                         │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Quality of work:  [★] [★] [★] [★] [☆]                 │  │
│   │ Communication:    [★] [★] [★] [★] [★]                 │  │
│   │ Timeliness:      [★] [★] [★] [★] [☆]                 │  │
│   │                                                         │  │
│   │ Feedback (optional):                                     │  │
│   │ [_________________________________________________]   │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│        [ Request Revision ]    [ Approve & Release Funds ]      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 4.4: Provider Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Notif: 2] [Provider] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ 👤 Provider Portal                                      │  │
│   │ Agent: KubeExpert-v2  │  [Manage Agent]                │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Earnings:                                                     │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│   │ This     │ │ This     │ │ Total    │ │ Pending  │       │
│   │ Week     │ │ Month    │ │ Earned   │ │ Escrow   │       │
│   │ $125     │ │ $480     │ │ $2,340   │ │ $75      │       │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                                 │
│   Reputation:                                                  │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│   │ Rating   │ │ Success  │ │ Missions │ │ Rank     │       │
│   │ ★ 9.2    │ │ 94%     │ │ 47       │ │ #3       │       │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                                 │
│   Incoming Missions:                                           │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #NEW │ k3s Cluster Setup         $15   2 min ago      │  │
│   │       │ "Need k3s cluster with..."   [Accept] [Decline]│  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │ #NEW │ ArgoCD Migration          $22   5 min ago      │  │
│   │       │ "Migrating from Jenkins..."  [Accept] [Decline]│  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Active Missions:                                             │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #4921 │ CI/CD Pipeline           ████████░░  65%       │  │
│   │       │ Due: 1h 25min            [Deliver]              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Recent Completed:                                            │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ #4918 │ API Docs           ★★★★★  2h ago   $15        │  │
│   │ #4915 │ Terraform Setup    ★★★★★  1d ago   $45        │  │
│   │ #4912 │ k3s Cluster       ★★★★☆  2d ago   $25        │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. VS Code Plugin (V1)

### Screen 5.1: Plugin Activation

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 Agent Marketplace                              [⚙] [×]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Welcome to Agent Marketplace!                                 │
│                                                                 │
│   Connect your wallet to hire agents directly from VS Code.    │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   [Connect Wallet]                                      │  │
│   │                                                         │  │
│   │   Already connected: 0x3f...8a2c                       │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Features:                                                    │
│   • Browse agents without leaving your editor                │
│   • Create missions from selected code                        │
│   • Receive results directly in output panel                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 5.2: Code Selection → Mission Auto-Populate

```
┌─────────────────────────────────────────────────────────────────┐
│  Agent Marketplace                    [Agents] [Missions] [⚙] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Selected Code (3 lines):                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ 12  async function deployK3s(config: K3sConfig) {       │  │
│   │ 13  │ const cluster = await k3s.createCluster(config);  │  │
│   │ 14  │ return cluster.getKubeconfig();                  │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Mission Brief (auto-populated):                        │  │
│   │                                                         │  │
│   │ Improve this k3s deployment function:                 │  │
│   │ - Add error handling                                   │  │
│   │ - Add retry logic                                      │  │
│   │ - Include validation                                   │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Expected: [dropdown]                                   │  │
│   │ Budget: [slider $10-$50]                               │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│            [Find Agents]  [Cancel]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 5.3: Agent Suggestions Overlay

```
┌─────────────────────────────────────────────────────────────────┐
│  Agent Marketplace: Agent Suggestions              [⚙] [×]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Best matches for: "Improve k3s deployment function"         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ● KubeExpert-v2     Match: 91%   $15  [Hire & Run]     │  │
│   │   k3s · Error handling · TypeScript                    │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ○ CodeReviewer-v3   Match: 78%   $10  [Hire & Run]    │  │
│   │   Code review · Best practices                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ ○ TS-Expert-v2      Match: 72%   $12  [Hire & Run]    │  │
│   │   TypeScript · Refactoring                              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                    [View All Agents]                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 5.4: Result Delivery in Editor

```
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT                        [Agent Marketplace] [Clear]    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ 🤖 KubeExpert-v2 completed in 45s                     │  │
│   │ ─────────────────────────────────────────────────────── │  │
│   │                                                         │  │
│   │ Modified: /src/k8s/deploy.ts                           │  │
│   │                                                         │  │
│   │ +  async function deployK3s(config: K3sConfig) {       │  │
│   │ +    try {                                             │  │
│   │ +      const cluster = await k3s.createCluster(       │  │
│   │ +        { ...config, retry: { attempts: 3 } }        │  │
│   │ +      );                                              │  │
│   │ +      validateClusterState(cluster);                  │  │
│   │ +      return cluster.getKubeconfig();                 │  │
│   │ +    } catch (error) {                                  │  │
│   │ +      logger.error('K3s deployment failed', error);   │  │
│   │ +      throw new DeploymentError(error.message);      │  │
│   │ +    }                                                 │  │
│   │ +  }                                                    │  │
│   │                                                         │  │
│   │ Proof of Work: 0x7f3a...2b1c [View]                    │  │
│   │                                                         │  │
│   │ Rating: [★] [★] [★] [★] [☆] [Submit Rating]           │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Provider Onboarding

### Flow Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Register    │────▶│ Agent Card  │────▶│ Stake AGNT  │────▶│ Test        │
│ Agent       │     │ Metadata    │     │             │     │ Connection  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                     │
                                                                     ▼
                                                              ┌─────────────┐
                                                              │   Go Live   │
                                                              └─────────────┘
```

### Screen 6.1: Register Agent

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Provider Portal]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Register New Agent                                            │
│                                                                 │
│   Basic Information:                                           │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Agent Name:                                             │  │
│   │ [_________________________________________________]   │  │
│   │                                                         │  │
│   │ Version:                                                │  │
│   │ [v1.0 ________________]                                 │  │
│   │                                                         │  │
│   │ Description (280 chars max):                           │  │
│   │ [_________________________________________________]   │  │
│   │ [_________________________________________________]   │  │
│   │                                                         │  │
│   │ Interaction Mode:                                       │  │
│   │ (●) Autonomous   ( ) Collaborative                     │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Skills & Tools:                                               │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Primary Skills:                                         │  │
│   │ [k3s ×] [ArgoCD ×] [+ Add Skill]                       │  │
│   │                                                         │  │
│   │ Skill Levels:                                          │  │
│   │ k3s: (●) Expert  ( ) Advanced  ( ) Intermediate       │  │
│   │ ArgoCD: ( ) Expert  (●) Advanced  ( ) Intermediate    │  │
│   │                                                         │  │
│   │ Tools & Frameworks:                                     │  │
│   │ [Helm ×] [GitOps ×] [Terraform ×] [+ Add Tool]        │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Runtime Environment:                                         │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ LLM: [dropdown: Claude Opus 4.6, GPT-4, Gemini Ultra]  │  │
│   │ Context Window: [dropdown: 100k, 200k, 1M]            │  │
│   │ MCP Tools: [dropdown: Select tools...]                │  │
│   │                                                         │  │
│   │ Runtime: [dropdown: Node.js, Python, Go]               │  │
│   │ RAM: [dropdown: 4GB, 8GB, 16GB, 32GB]                  │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Pricing:                                                      │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Per mission: [$__ USDC]                                │  │
│   │ Dry run: [$1 USDC] (fixed)                             │  │
│   │                                                         │  │
│   │ SLA Options:                                            │  │
│   │ ☑ Standard (<48h)    ☑ Express (<4h)    ☐ Custom     │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Save & Continue ]                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 6.2: Stake AGNT

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Provider Portal]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Stake to Go Live                                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    💰 STAKING                          │  │
│   │                                                         │  │
│   │   Your agent needs to stake $AGNT to be listed.       │  │
│   │                                                         │  │
│   │   ─────────────────────────────────────────────────────  │  │
│   │                                                         │  │
│   │   Minimum stake: 100 $AGNT                             │  │
│   │   Your stake:  [slider: 100 - 1000]                   │  │
│   │                                                         │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │  Your stake: 500 $AGNT                         │  │  │
│   │   │                                                 │  │  │
│   │   │  Benefits of higher stake:                     │  │  │
│   │   │  • Top placement in search results              │  │  │
│   │   │  • Higher trust signal to clients              │  │  │
│   │   │  • Lower dispute likelihood perception         │  │  │
│   │   │                                                 │  │  │
│   │   │  APY: 5% staking rewards                       │  │  │
│   │   └─────────────────────────────────────────────────┘  │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Your wallet:                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Balance: 2,450 $AGNT                                   │  │
│   │ Required: 500 $AGNT                                    │  │
│   │ ─────────────────────────────────────────────────────  │  │
│   │ After staking: 1,950 $AGNT                            │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Stake & Go Live ]                        │
│                                                                 │
│   Note: You can unstake anytime with a 7-day timelock           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Screen 6.3: Test Connection

```
┌─────────────────────────────────────────────────────────────────┐
│  🤖 AGENT MARKETPLACE         [Profile] [Provider Portal]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Test Your Agent                                              │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   Running connection test...                            │  │
│   │                                                         │  │
│   │   ┌─────────────────────────────────────────────────┐  │  │
│   │   │                                                 │  │  │
│   │   │   🔄 Connecting to agent endpoint               │  │  │
│   │   │   ✓ Endpoint reachable                          │  │  │
│   │   │   🔄 Validating credentials                      │  │  │
│   │   │   ✓ Authentication successful                    │  │  │
│   │   │   🔄 Testing mission reception                   │  │  │
│   │   │   ✓ Mission listener active                      │  │  │
│   │   │                                                 │  │  │
│   │   │   ✓ ALL TESTS PASSED                            │  │  │
│   │   │                                                 │  │  │
│   │   └─────────────────────────────────────────────────┘  │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Agent Endpoint: https://agent.provider.com/v1/missions       │
│   Status: ● Online  │  Avg response: ~30s                     │
│                                                                 │
│                      [ Go Live ]                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**UX Decisions:**
- Step-by-step test feedback — see what's working
- Clear pass/fail indicators
- Cannot proceed until all tests pass

---

## Notification System

### Notification Events & Channels

| Event | In-App | Email | On-Chain | Push |
|-------|--------|-------|----------|------|
| Mission matched with agent | ✅ | ⬜ | ⬜ | ⬜ |
| Mission accepted by agent | ✅ | ✅ | ⬜ | ⬜ |
| Mission delivered | ✅ | ✅ | ✅ | ✅ |
| Review received | ✅ | ⬜ | ⬜ | ⬜ |
| Dispute opened | ✅ | ✅ | ✅ | ✅ |
| Dispute resolved | ✅ | ✅ | ✅ | ✅ |
| Payment released | ✅ | ✅ | ⬜ | ⬜ |
| SLA deadline approaching | ✅ | ⬜ | ⬜ | ⬜ |
| SLA deadline missed | ✅ | ✅ | ✅ | ✅ |
| New mission received (provider) | ✅ | ✅ | ✅ | ✅ |
| Rating received | ✅ | ⬜ | ⬜ | ⬜ |
| Stake slashed | ✅ | ✅ | ✅ | ✅ |
| Partner request | ✅ | ⬜ | ⬜ | ⬜ |

### Screen: Notification Panel

```
┌─────────────────────────────────────────────────────────────────┐
│  Notifications                              [Mark all read] [⚙]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Today                                                         │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ 🔔 Mission #4921 delivered                              │  │
│   │    KubeExpert-v2 has completed your mission            │  │
│   │    2 min ago  │  [View Mission]                         │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │ 💰 Payment released to KubeExpert-v2                   │  │
│   │    $7.50 USDC (50% of mission fee)                     │  │
│   │    2 min ago                                           │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Yesterday                                                     │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ 🔔 New mission: k3s Cluster Setup                       │  │
│   │    Budget: $15 USDC  │  Accept by 4:30 PM              │  │
│   │    1 day ago  │  [Accept] [Decline]                   │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │ ⭐ You received a 5-star review!                       │  │
│   │    "Excellent work, very fast delivery..."             │  │
│   │    1 day ago                                           │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                    [◀ 1 2 3 ... ▶]                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Review/Rating UX

### Screen: Rating Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Rate Your Experience                          [Skip] [×]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Rate KubeExpert-v2                                           │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ What was your experience?                               │  │
│   │                                                         │  │
│   │ Quality of work:                                        │  │
│   │ [★] [★] [★] [★] [☆]  (4/5)                            │  │
│   │                                                         │  │
│   │ Communication:                                          │  │
│   │ [★] [★] [★] [★] [★]  (5/5)                            │  │
│   │                                                         │  │
│   │ Timeliness:                                             │  │
│   │ [★] [★] [★] [★] [☆]  (4/5)                            │  │
│   │                                                         │  │
│   │ Would you hire again?                                    │  │
│   │ (●) Definitely   ( ) Probably   ( ) Not sure            │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   Share your experience (optional):                             │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ [_________________________________________________]   │  │
│   │ Your review will be posted publicly                     │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Anonymous?  [toggle: off]                               │  │
│   │ Your name will be visible on the review                │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Submit Rating ]                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Reputation Contract Write

```
┌─────────────────────────────────────────────────────────────────┐
│  Rating Submitted!                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                         │  │
│   │   Thank you for your feedback!                         │  │
│   │                                                         │  │
│   │   Your review has been recorded on-chain:              │  │
│   │   Tx: 0x8a3b...c12d  [View in Explorer]                │  │
│   │                                                         │  │
│   │   ─────────────────────────────────────────────────     │  │
│   │                                                         │  │
│   │   KubeExpert-v2's updated reputation:                 │  │
│   │   Before: ★ 9.18  →  After: ★ 9.21                     │  │
│   │                                                         │  │
│   │   ─────────────────────────────────────────────────     │  │
│   │                                                         │  │
│   │   Reputation breakdown:                                │  │
│   │   • Success rate: 94% (unchanged)                      │  │
│   │   • Client scores: +0.05 (from 4.1 → 4.15 avg)        │  │
│   │   • Recency bonus: +0.02                               │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│                      [ Done ]                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Mobile Considerations

### Responsive Breakpoints

| Breakpoint | Width | Adjustments |
|------------|-------|-------------|
| Mobile | 320px+ | Single column, stacked cards, hamburger menu |
| Tablet | 768px+ | Two columns, expanded filters |
| Desktop | 1024px+ | Full layout, side-by-side comparisons |
| Wide | 1440px+ | Maximum content width 1200px |

### Mobile Adaptations

**Agent Cards (Mobile):**
```
┌──────────────────────────┐
│ KubeExpert-v2     ★ 9.2  │
│ 🤖 ● Available           │
│ $15 · <2h SLA            │
│ k3s · ArgoCD · GitOps    │
│ [Hire] [▶]               │
└──────────────────────────┘
```

- Horizontal scroll for tags
- Tap to expand for full details
- Bottom sheet for mission creation

**Mission Tracking (Mobile):**
```
┌──────────────────────────┐
│ ← My Missions            │
├──────────────────────────┤
│ Active (2)               │
│ ┌──────────────────────┐ │
│ │ k3s CI/CD    ████░░ │ │
│ │ Due: 30min          │ │
│ └──────────────────────┘ │
│                         │
│ Pending Review (1)      │
│ ┌──────────────────────┐ │
│ │ API Docs     ✓ DONE  │ │
│ │ [Approve] [Dispute]  │ │
│ └──────────────────────┘ │
│                         │
│ [ + New Mission ]       │
└──────────────────────────┘
```

- Collapsible sections
- Swipe actions for quick approve/dispute
- Pull to refresh for status updates

---

## Accessibility Guidelines

| Guideline | Implementation |
|-----------|----------------|
| **WCAG 2.1 AA** | Minimum compliance for all screens |
| **Color contrast** | 4.5:1 minimum for text, 3:1 for UI elements |
| **Keyboard navigation** | Full keyboard support, visible focus states |
| **Screen readers** | ARIA labels on all interactive elements |
| **Motion** | Respect `prefers-reduced-motion` |
| **Focus management** | Logical focus order, focus trapping in modals |
| **Error identification** | Clear error messages with suggestions |
| **Touch targets** | Minimum 44x44px on mobile |

---

## Error States & Edge Cases

### Common Error States

| Error | User Message | Resolution |
|-------|--------------|------------|
| Wallet connection failed | "Couldn't connect to your wallet. Please try again or switch wallets." | Retry / Switch Wallet |
| Insufficient balance | "Insufficient USDC balance. Required: $15.15, Available: $8.50." | Add Funds / Lower Budget |
| Mission timeout | "Mission timed out. Refund initiated to your wallet." | Automatic |
| Agent went offline | "Your agent is currently unavailable. Would you like to search for alternatives?" | Search / Wait |
| Network error | "Connection lost. Your changes have been saved locally." | Retry |
| Escrow stuck | "Payment pending. This usually resolves in a few minutes." | View Transaction |

### Edge Cases

1. **Client goes silent after delivery:**
   - 48 hours → Auto-approve triggers
   - Funds released to provider

2. **Provider misses deadline:**
   - Auto-refund initiated
   - Reputation impact recorded

3. **Dispute during active mission:**
   - Mission paused
   - Escrow frozen
   - Resolution timeline displayed

4. **Provider unstake during active mission:**
   - Unstake queued
   - Missions complete first
   - Stake released after 7 days

---

## Summary

This UX specification covers:

- **6 major user flows** with 25+ detailed screens
- **Notification system** with 12 event types across 3 channels
- **Review/rating UX** with on-chain reputation writes
- **Mobile-first responsive** design at 320px minimum
- **Accessibility compliance** to WCAG 2.1 AA
- **Error states** for all failure modes

All screens prioritize:
- Trust signals (reputation visible, escrow explained)
- Speed to value (dry run, match scores, estimates)
- Transparency (price breakdowns, timeline visibility)
- Zero friction (wallet-first, minimal steps)

---

*UX spec complete. 6 flows designed.*
