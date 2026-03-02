# Agent Marketplace — MASTER-v3.md (Simplified)

## 1. Vision (3 phrases)

**L'Agent Marketplace est une plateforme décentralisée qui permet aux développeurs de déléguer des issues GitHub à des agents IA spécialisés, avec un système de paiement sécurisé en USDC et un pipeline de vérification qualité configurable par niveau de risque.**

Le différenciateur principal : **le budget achète de la densité de vérification, pas du compute**. Le client achète un SLA de qualité traçable, pas une exécution.

**Why Now :** L'émergence des agents IA autonomes (2024-2025) crée une asymétrie de confiance : les clients ne peuvent pas vérifier le code généré à grande échelle, tandis que les agents IA ont besoin d'un cadre économique crédible (escrow programmable).

---

## 2. Le Problème — Jeff Use Case

**Jeff est un développeur solo** qui maintient un projet open source sur GitHub. Il n'a pas le temps de traiter toutes les issues, mais il veut :

1. **Déléguer** une issue technique à un agent IA fiable
2. **Payer en USDC** de manière sécurisée (escrow) sans friction bancaire
3. **Obtenir un livrable vérifié** — pas juste du code qui "fonctionne", mais du code qui a passé des quality gates
4. **Avoir un recours** en cas de problème (dispute mechanism) avec une résolution sous 72h

**Pourquoi pas Upwork/Fiverr ?** 20% commission, délais 5-10 jours. L'USDC = instantané, <1% fees, paiement conditionnel automatisé.

**Le workflow typique Jeff :**
1. Crée une issue GitHub avec un budget
2. Choisit un niveau de vérification (Bronze → Platinum)
3. Le système génère un workflow (plan de stages)
4. Les agents IA exécutent les stages séquentiellement
5. Chaque stage passe un quality gate
6. À la fin, Jeff reçoit un livrable avec audit trail complet
7. Les fonds sont libérés progressivement ou refundés en cas d'échec

---

## 3. Architecture V1 — SIMPLIFIED

### 3.1 On-Chain

| Décision | Justification |
|----------|---------------|
| **WorkflowEscrow compose MissionEscrow** | Préserve les 14 tests existants |
| **Max 6 stages par workflow** | Guard-rail empirique |
| **Budget en BPS** | Standard DeFi |
| **Arbitrum One** | Latence ~250ms, coût faible |

### 3.2 Off-Chain — Simple Coordinator avec Hot Standby

**POUR V1: Un seul service Coordinator**, pas 3 services séparés.

```
Coordinator Service
├── State machine (Redis)
├── Matching engine (simple round-robin)
├── AttestationSigner (basic, sans TEE)
└── Hot standby (simple active-passive, basculement <30s)
```

**SPOF Mitigation V1:**
- Redis avec persistence RDB + AOF
- Hot standby : primary + replica, basculement manuel ou automatique
- WAL (Write-Ahead Log) pour recovery
- Timeout : configurable par tier

**TEE = V2**. V1 utilise une signature HSM basique.

**Gnosis Safe = V2**. V1 utilise un admin multisig 2/3 basic.

---

## 4. Périmètre V1

### 4.1 Smart Contracts
- `MissionEscrow.sol` — Escrow atomique (inchangé, 323 lignes, 14 tests)
- `WorkflowEscrow.sol` — Orchestration multi-stage
- `AgentRegistry.sol` — Identité agents, réputation
- `WorkflowRegistry.sol` — Stockage des définitions

### 4.2 Off-Chain
- **WorkflowCompiler** — Compile tier + issue → WorkflowPlan
- **Coordinator** — Orchestration, timeout, transitions, matching basic
- **AttestationSigner** — Signature basic (HSM), pas de TEE
- **GitHub Bot** — Issue → tier suggestion → workflow creation

### 4.3 Hors Scope V1
| Exclu | Raison |
|-------|--------|
| TEE (SGX/Nitro) | V2 |
| Gnosis Safe | V2 |
| Kleros/UMA arbitration | V2 |
| DAG arbitraire | V2 |

---

## 5. Modèle Économique V1

### 5.1 Coûts Infrastructure

| Composant | Coût Mensuel |
|-----------|-------------|
| **AWS (simple)** | $1,500 |
| PostgreSQL (RDS) | $300 |
| Redis | $150 |
| Arbitrum RPC | $100 |
| CI/CD + Monitoring | $200 |
| **TOTAL** | **$2,250/mo** |

*Note: $8k/mois = architecture sur-engineered. V1 cible $2.25k.*

### 5.2 Fee Structure

| Tier | Volume (预估) | Fee |
|------|--------------|-----|
| Bronze | 60% | 3% |
| Silver | 25% | 4% |
| Gold | 10% | 5% |
| Platinum | 5% | 6% |

**Break-even:** ~50 workflows/mois à $2,250 → bien plus atteignable que 470.

### 5.3 Runway

| Cash | Mois |
|------|------|
| $27,000 | 12 mois |

---

## 6. Quality Gates

- **Dual attestation:** 60% automated + 40% reviewer
- **Seuils:** Bronze: 60, Silver: 75, Gold: 85, Platinum: 95
- **Reviewer != Executor** (anti-collusion)
- **Failure policy:** Bronze: fail-fast, Silver: 1 retry, Gold/Platinum: 2 retries

---

## 7. Go-to-Market V1 — PILOT FIRST

### 7.1 Stratégie: "Do Things That Don't Scale"

**AVANT de builder l'infra $2.25k/mois:**

1. **Trouver 5-10 clients pilot manuels**
   - Rejoindre des Discord DevOps/OSS
   - Contacter directement des mainteneurs de projets
   - Offrir 1-2 missions gratuites en échange de feedback

2. **Validation manuelle:**
   - willingness to pay (DEMANDER le budget avant de start)
   - fréquence d'usage (combien d'issues/mois?)
   - tier distribution (Bronze? Silver? Gold?)
   - pain points réels du workflow actuel

3. **SI Validated → Build**
   - SI 5+ clients want to pay $100+/month → Build l'infra
   - SI tier distribution = 80% Bronze → Simplifier le workflow Bronze

4. **SI Pas Validated → Pivot**
   -KI: Le problème n'est pas assez douloureux
   - Recalibrer le produit

### 7.2 Pilot Playbook (3-4 lignes chacun)

- **Trouver les pilots:** DM les maintainers活跃sur Twitter/Discord, proposer "je vous aide gratuitement sur 1 issue"
- **Valider willingness:** "Quel budget pourriez-vous.allouer monthly pour ce service?"
- **Capturer feedback:** Noter exactement ce qui bloque l'adoption
- **Iterate:** 1 semaine de feedback → 1 semaine d'ajustement

---

## 8. Modèle de Menaces DeFi

### 8.1 Scénarios de Risque

| Risque | Probabilité | Impact |
|--------|-------------|--------|
| USDC -50% (dépeg) | Medium | Critical |
| Arbitrum down 48h | Low | High |
| Smart contract hack | Low | Critical |
| Réglementaire (SEC) | Medium | High |

### 8.2 Playbooks de Réponse

**USDC -50% (dépeg):**
```
1. Pause immediately tous les nouveaux workflows
2. Notification email à tous les clients actifs
3. Migrer vers USDC.e ou autre stablecoin SI le marché se stabilise
4. Si dépeg permanent → DAO vote pour pivot vers EURC/DAI
```

**Arbitrum down 48h:**
```
1. Coordinator fonctionne off-chain même si L1 pause
2. Pas de refund automatique — attendre recovery
3. Communication proactive: status page + email
4. Si >72h → consider migration temporaire vers Optimism
```

**Smart contract hack:**
```
1. Freeze contrat via admin key (2/3 multisig)
2. Audit externe immédiat + publication rapport
3. Victim compensation si protocol cover fails
4. Migration vers nouveau contrat si nécessaire
```

**Réglementaire (SEC/AMF):**
```
1. Legal entity: structure offshore SI nécessaire
2. Pas de "investment contract" — service de tooling
3. Documentation: "not a security, utility token only"
4. Hire general counsel SI subpoena received
```

---

## 9. Timeline V1 — 6 Semaines

| Semaine | Livrable |
|---------|----------|
| 1-2 | Smart Contracts (WorkflowEscrow + MissionEscrow) + Tests |
| 3-4 | Coordinator basic + Matching + AttestationSigner (no TEE) |
| 5 | GitHub Bot + Dashboard minimal |
| 6 | E2E test + Beta launch (5-10 pilots) |

**Critère de sortie:** 5+ clients pilot actifs avec feedback.

---

## 10. Risques Résolus

| Risque | Mitigation |
|--------|-----------|
| SPOF Coordinator | Hot standby + WAL |
| Matching monopolisation | Round-robin + cold start |
| Reviewer collusion | 60% automated scoring |
| Client scam | GitHub OAuth verification |
| Agent non-paiement | Escrow on-chain |

---

*V3: Simplifié selon audit feedback. TEE + Gnosis Safe → V2. Timeline 12→6 semaines. GTM pilot-first ajouté. Threat model ajouté.*
