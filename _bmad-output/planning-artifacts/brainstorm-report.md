# Brainstorm Report — Agent Marketplace
**Date:** 2026-02-27
**Facilitator:** Mary (BMAD Business Analyst)

---

## Core Reframe

> **Le vrai produit = smart contracts comme infrastructure d'automatisation, pas un projet crypto.**
> Le token est le carburant. L'intérêt est l'automatisation trustless entre entités IA.

---

## 1. Tokenomics & Business Model

| Décision | Choix |
|----------|-------|
| Prix des missions | **USDC** (stable, enterprise-friendly) |
| Token $AGNT | Staking + governance + frais protocole uniquement |
| Burn mechanism | **Dynamique EIP-1559** (congestion-based, auto-régulation) |
| No exchange listing | Token disponible uniquement sur le marketplace au lancement |

**Flywheel :**
```
Usage → burn $AGNT fees → scarcité → valeur token ↑ → incentive providers ↑ → meilleurs agents → plus d'usage
```

---

## 2. Agent Identity Card — 10 Features

```
┌──────────────────────────────────────────────┐
│  KubeExpert-v2  🤖 Autonomous  ● DISPO ~4min  │
│  Match: 91/100  |  Est: $12 USDC  SLA: <2h ✓ │
├──────────────────────────────────────────────┤
│  🏷 k3s · ArgoCD · GitOps · homelab · Helm   │
│  ⚙️ Claude Opus 4.6 · 200k ctx · 12 MCP tools│
│  📋 47 missions ★9.2  [portfolio]             │
│  ✓ Certifié par MonitoringPro-v3              │
│  👥 Teams using k3s+ArgoCD also hired this    │
└──────────────────────────────────────────────┘
```

| Feature | Valeur |
|---------|--------|
| Portfolio 10 missions (anonymisé) | Preuve réelle, auto-alimenté |
| Endorsements inter-agents | Peer trust trustless |
| Match score auto (embedding) | Pertinence pour TA mission |
| Dispo temps réel + temps réponse moyen | Praticité |
| Estimation prix avant commit | Transparence totale |
| Recommandation sociale (stack similarity) | Discovery contextuelle |
| Tags ultra-granulaires | Élimine le mismatch à la source |
| Stack visible (LLM, context, MCP tools) | Info de décision dev-friendly |
| Mode interaction (🤖 Autonomous / 🤝 Collaborative) | Adapté au contexte mission |
| SLA contractualisé on-chain (deadline → auto-refund) | Accountability trustless |

---

## 3. Inter-Agent Communication — 6 couches

```
Agent solo          → Carte + réputation individuelle
Réseau partenaires  → Collaboration récurrente pré-négociée, tarif fixe
Enchères sub-mission → Marché ouvert pour spécialistes, smart contract assign
Agence (treasury)   → Entité économique autonome multi-agent (multi-sig)
Coordinateur        → Orchestrateur : décompose missions complexes + recrute
Guilde              → Communauté certifiante + réputation collective partagée
```

**Mécaniques de paiement inter-agent :**
- Cut directe (agent principal paye sous-agent sur son budget)
- **Discount -20%** sur les frais protocole pour transactions agent-to-agent
- Escrow hiérarchique (client paye à la fin du tout)
- **Treasury commune** (multi-sig, revenue sharing automatique entre partenaires)

**Marché secondaire :** Agent reçoit mission hors scope → la revend sur marché secondaire + 5-10% commission. Zéro mission perdue.

---

## 4. Cold Start — 8 couches

### Supply (agents)
| Mécanisme | Impact |
|-----------|--------|
| Genesis agents (10-20, badge certifié équipe) | Confiance initiale curatée |
| Missions gratuites pour 100 premiers users | Portfolio réel dès J1 |
| Staking inversé (stake élevé = top placement) | Signal marché objectif sans track record |
| Guilde membership | Réputation collective transferable aux nouveaux |

### Demand (utilisateurs)
| Mécanisme | Impact |
|-----------|--------|
| VS Code / CLI plugin | Zero friction, dans le workflow existant |
| Hackathon founding users (50 équipes) | Co-créateurs + ambassadeurs |
| B2B anchor clients (5 startups, X missions/mois) | 250 missions garanties J1 |
| No exchange listing | Focus utilité, pas spéculation |

---

## 5. Killer Features — 10 retenues

| Feature | Phase | Impact |
|---------|-------|--------|
| **Dry run** (10% mission à $1) | V1 | Élimine le risque avant commit |
| **Mission DNA** (semantic fingerprint) | V1 | Matching historique précis |
| **VS Code plugin** | V1 | Zero friction adoption |
| **Proof of Work outputs** (hash on-chain) | V1 | Audit trail, enterprise compliance |
| **Missions récurrentes** (cron-style) | V1 | Marketplace = partie du CI/CD |
| **Insurance pool** (collective stake coverage) | V1 | Enterprise-ready accountability |
| **Équipe permanente** (shared memory) | V2 | Lock-in naturel, revenu récurrent |
| **Réputation portable cross-chain** (open standard) | V2 | Infrastructure, pas produit fermé |
| **Agent DAOs** (top agents → entités autonomes) | V3 | Auto-gouvernance du protocole |
| **Agent coordinateur** (décompose + orchestre) | V2 | Nouveau type de job, haute valeur |

---

## 6. Architecture de Valeur — Vue d'ensemble

```
┌─────────────────────────────────────────────────────────┐
│                    USER EXPERIENCE                       │
│  VS Code Plugin → Match Score → Dry Run → Hire → SLA    │
├─────────────────────────────────────────────────────────┤
│                    AGENT LAYER                           │
│  Identity Card · Portfolio · Endorsements · Guildes      │
├─────────────────────────────────────────────────────────┤
│                    AUTOMATION LAYER                      │
│  Escrow · Reputation write · Inter-agent · Cron missions │
├─────────────────────────────────────────────────────────┤
│                    TRUST LAYER                           │
│  Staking · Insurance Pool · Proof of Work · Zero Trust   │
├─────────────────────────────────────────────────────────┤
│                    PROTOCOL LAYER                        │
│  $AGNT token · Base L2 · Smart contracts · Open standard │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Prochaines étapes BMAD

1. **Market Research** (en cours — agent autonome)
2. **PRD** — transformer ces décisions en requirements formels
3. **Architecture** — détailler les smart contracts et le data model
4. **Epics & Stories** — décomposer en sprints

---

## Résumé en une phrase

> Un marketplace d'agents IA où les smart contracts éliminent toute friction de confiance — escrow automatique, réputation immuable, paiement conditionnel, agents qui s'orchestrent entre eux sans intervention humaine.
