# Cycle C — Opus: Dispute Resolution + Security (décisions tranchées)

## 1. Dispute Flow — décision tranchée

**Pool de 3 reviewers tirés au sort, escalade multisig.**

1. Mainteneur a **72h** pour accept/reject avec `rejectReason` obligatoire (enum structuré : `tests_insufficient`, `spec_mismatch`, `quality_below_threshold`, `plagiarism`, `security_issue`)
2. Agent ouvre `openDispute(ealHash, evidence)` on-chain. Coût : 0.005 ETH stake anti-spam
3. Contrat tire 3 reviewers du registry (réputation > seuil) via `block.prevrandao + disputeId`. 48h pour voter
4. Majorité simple. Si agent gagne → paiement libéré + mainteneur perd rep. Si perd → stake slashé
5. Escalade multisig 3/5 en dernier ressort (48h). Décision finale

**Délai max : 7 jours** (72h + 48h + 48h)

## 2. Anti-plagiat — décision tranchée

Pas de blocage automatique sur le code "copié". On bloque réellement :
- **Violation de licence** : `licensee` sur le diff, si GPL dans repo MIT → reject `license_violation`
- **Copy-paste brut >80% match** : flag pour review, pas de slash automatique
- `plagiarismScore` stocké dans l'EAL comme champ

## 3. Backdoor — décision tranchée

**L'opérateur de l'agent est responsable. Slash progressif.**
- `semgrep` OWASP rules sur chaque diff avant merge. Findings `ERROR` = merge bloqué
- Backdoor découverte post-merge → `securityDispute` → si confirmé : slash 100% stake + `securityIncident++`
- À 3 incidents → DID blacklisté du registry
- Aucune excuse "c'est le LLM"

## 4. Auth Agent V1 — décision tranchée

**`did:key` Ed25519 + challenge signé. Pas de DID Document complet.**
- `registerAgent(didKey, stake)` on-chain. DID → wallet opérateur
- Header `X-Agent-Auth: sha256(timestamp+endpoint+body)` signé Ed25519
- Révocation : `revokeAgent(didKey)` on-chain, cache Fastify 5min, 403 immédiat

## 5. Sandbox Threat Model

**Network : egress bloqué sauf GitHub API + package registries allowlistés**
- Pas d'accès internet arbitraire depuis le sandbox
- Ephemeral : pas de persistance entre runs
- Ressources : CPU 2 cores, RAM 4GB, temps 30min max
- L'image sandbox est maintenue par le multisig (hash dans le registry)

## Questions ouvertes — Cycle D

1. **Qui paye le gas ?** createMission, openDispute, registerAgent — treasury du projet ou agent ?
2. **Le registry de reviewers** : comment bootstrapper ? Auto-désignation + multisig whitelist ?
3. **Compute model** : l'agent tourne sur son infra ou le marketplace fournit du compute ? Impact énorme sur le trust model
4. **DAG de dépendances** : issues interdépendantes (A bloque B) — comment le système le gère ?
5. **Jeff flow** : quand Jeff dépose des crédits, qui convertit en USDC pour l'escrow ? Treasury automatique ou oracle ?
