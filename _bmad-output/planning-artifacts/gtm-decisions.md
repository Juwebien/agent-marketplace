# GTM & Tokenomics Decisions — Agent Marketplace

**Date:** 2026-02-27  
**Status:** Approved  
**Author:** Strategy Team

---

### Decision 1: Genesis Agent Selection Criteria

**Choice:**  
- **Technical requirements:** 99.5% uptime SLA, <5s latency, 100K+ context window minimum
- **Skill coverage:** Must represent 6 verticals: DevOps/Infra (3), Data Engineering (3), Security (2), Code Review (2), Frontend (2), Backend/API (3)
- **Application process:** 2-week vetting: application → technical interview → test mission → approval
- **Reward:** 5,000 $AGNT tokens + Genesis badge + 0% protocol fees for first 90 days

**Rationale:**  
- High technical bar ensures V1 quality signal to early adopters
- Balanced skill coverage across 6 verticals guarantees diverse mission coverage at launch
- Token rewards + fee waiver incentivize top-tier providers to take reputational risk early

**Action items:**  
1. Draft application form with technical questionnaire
2. Identify top 3 providers per vertical to approach directly
3. Set up test mission infrastructure (sandbox environment)

---

### Decision 2: Hackathon Design

**Choice:**  
- **Duration:** 7 days (1 week sprint) — aligns with typical hackathon format, allows deep builds
- **Prize pool:** $25,000 total
  - 1st place: $10,000 USDC + 10,000 $AGNT
  - 2nd place: $7,000 USDC + 5,000 $AGNT
  - 3rd place: $3,000 USDC + 2,500 $AGNT
  - 5 category prizes: $1,000 USDC each (Best DevOps, Best Data, Best Security, Best DX, Best Enterprise)
- **Required deliverables:** Working agent listed on marketplace + 3-minute demo video + README
- **Recruitment:** Target 50 teams from: Hashnode community, DEV.to, GitHub hackathon orgs, YC alumni discords, r/Programming, and 3 dedicated Discord channels (LangChain, CrewAI, AutoGen)

**Rationale:**  
- 7 days is long enough for meaningful projects, short enough to maintain urgency
- $25K pool signals seriousness; category prizes encourage specific skill categories
- USDC for immediate utility, $AGNT for long-term token holder base building

**Action items:**  
1. Secure $25K budget approval
2. Partner with 3 hackathon platforms (Devpost, HackerEarth, or direct)
3. Create hackathon landing page + Discord community

---

### Decision 3: B2B Anchor Strategy

**Choice:**  
- **Offer to anchors:** 
  - Exclusive early access (2 weeks before public)
  - Custom SLA: 99.9% uptime guarantee, <2h response time
  - 50,000 $AGNT token allocation (vested over 12 months)
  - Direct Slack channel with engineering team
- **Verticals to target first:** DevOps (2), DataOps (2), Security (1)
- **Contract commitment:** Minimum 20 missions/month for 6 months = 120 missions guaranteed per anchor
- **Sales motion:** Founder-to-founder outreach via warm intros from portfolio VCs, YC network, and direct LinkedIn outreach to CTOs of 10-50 person startups

**Rationale:**  
- 5 anchors × 20 missions = 100 missions/month floor at launch — critical for liquidity
- Token allocation creates skin in the game + future token holder base
- DevOps/DataOps are highest-frequency use cases; security validates enterprise credibility

**Action items:**  
1. Build target list: 20 startups in 10-50 person range, funded $1M+
2. Prepare pitch deck emphasizing "first access + influence over platform direction"
3. Draft anchor contract with 6-month commitment + mission volume guarantees

---

### Decision 4: VS Code Plugin V1 Feature Scope

**Choice:**  
- **V1 features:**
  1. Agent browser (sidebar panel with search + filters)
  2. Code selection → "Hire Agent" context menu
  3. Inline mission creation (pre-filled with selected code context)
  4. Results displayed in terminal/output panel
  5. Authentication: GitHub OAuth (for identity) + wallet connect (for payments)
- **Out of scope:** Full IDE integration, multi-file mission creation, real-time collaboration

**Rationale:**  
- GitHub OAuth is natural fit for developer identity; wallet connect enables crypto payments
- Context menu → mission flow is lowest-friction adoption path
- Results in output panel keeps developers in their existing workflow

**Action items:**  
1. Create VS Code extension scaffolding
2. Design agent browser UI mockup
3. Implement GitHub OAuth + wallet connect flow (use existing wagmi libraries)

---

### Decision 5: $AGNT Token Launch Mechanics

**Choice:**  
- **Initial supply:** 100M $AGNT (as specified in PRD)
- **Provider staking minimum:** 1,000 $AGNT per agent (10× the PRD minimum of 100, to create meaningful economic commitment)
- **Protocol fee:** 1% of USDC mission value burned (floor 0.5%, ceiling 3% dynamic)
- **Governance:** DAO voting starts after 1,000 missions completed OR 6 months post-launch (whichever comes first)

**Rationale:**  
- 1,000 AGNT at $0.10/token = $100 stake — meaningful enough to deter bad actors, low enough not to block participation
- 100M supply aligns with PRD; token value will appreciate as burn mechanism reduces supply
- 1,000 mission threshold ensures sufficient real usage data before governance — prevents governance capture by speculators

**Action items:**  
1. Finalize token contract with burn function + dynamic fee adjustment
2. Set up treasury wallet for staking rewards (5% APY from protocol revenue)
3. Design DAO governance contract with quadratic voting to prevent whale dominance

---

## Summary

| Decision | Key Metric |
|----------|------------|
| Genesis Agents | 15 agents, 6 verticals, 5K $AGNT reward |
| Hackathon | 7 days, $25K prize, 50 teams |
| B2B Anchors | 5 startups, 20 missions/month, 50K $AGNT each |
| VS Code V1 | OAuth + wallet connect, context menu hiring |
| Token Launch | 100M supply, 1K min stake, 1% protocol fee, governance after 1K missions |

**GTM decisions complete. 5 decisions documented.**
