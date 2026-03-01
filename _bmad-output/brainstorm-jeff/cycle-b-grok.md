# Cycle B — Grok 4: Proof of Work Spec

# Cycle B — Grok 4: Agent Marketplace — Proof of Work pour Tâches de Coding

En tant qu'expert en sécurité et architecture distribuée, je brainstorme sur le Cycle B, en me concentrant sur une proof-of-work (PoW) robuste pour valider le travail d'un agent autonome dans l'Agent Marketplace. Le Cycle A repose sur un flow GitHub-to-blockchain avec escrow Solidity sur Base L2, mais son PoW simpliste ("hash du diff") est insuffisant : il ne prouve pas l'effort réel, car un bot peut générer un diff trivial en millisecondes sans computation significative. Je propose une spec V1 challengeante, respectant les contraintes (pas de TEE/SGX, gas < 5000 pour vérification on-chain, stack Solidity/Hardhat/Fastify/GitHub Actions). L'approche priorise la reproductibilité, l'infalsifiabilité et la vérification cheap, tout en identifiant des gaps. Total : ~620 mots.

## Spec Concrète du Format Proof-of-Work V1

Pour une tâche de coding (e.g., implémenter une feature via PR GitHub), la PoW doit être **reproductible** (re-exécutable par un vérificateur), **infalsifiable** (signée cryptographiquement), et **cheap à vérifier** (off-chain pour la plupart, avec ancrage on-chain minimal). Inspiré de proof-of-stake mais adapté à du travail computationnel, sans mining énergivore. Format : un bundle JSON signé, généré par l'agent pendant l'exécution, ancré via hash on-chain.

### 1. Preuve de Travail Valide pour Tâche de Coding
Une PoW valide est une "execution trace" hashée, prouvant un effort computationnel mesurable (e.g., cycles CPU via benchmarks). Critères :
- **Reproductible** : L'agent exécute la tâche dans un environnement dockerisé standard (défini dans l'issue GitHub), produisant des outputs déterministes.
- **Infalsifiable** : Signée via clé EOA (Ethereum-compatible) de l'agent, avec nonce anti-replay.
- **Cheap à Vérifier** : Vérification off-chain par un QA agent (via GitHub Action), puis hash soumis on-chain pour < 2000 gas (simple storage slot update).

### 2. Données Capturées dans l'Execution Trace
L'agent capture une trace structurée pendant l'exécution autonome :
- **Commandes** : Log des commandes shell/git (e.g., `git clone`, `npm test`), avec arguments et outputs.
- **Timestamps** : UTC timestamps pour chaque étape, plus durée totale (e.g., >5min pour une tâche non-triviale).
- **Test Outputs** : Résultats de tests unitaires (e.g., Jest/Pytest logs), incluant pass/fail ratios et coverage metrics.
- **Logs** : Logs applicatifs (e.g., console outputs, error stacks) et un "work proof" comme un hashchain (e.g., Merkle tree de diffs intermédiaires).
- Format : JSON { "taskId": "GH-issue-123", "trace": [ { "step": "clone", "cmd": "git clone repo", "output": "...", "timestamp": "2023-10-01T12:00:00Z", "durationMs": 500 } ], "finalDiffHash": "0xabc...", "signature": "0xSigFromAgentEOA" }.
L'agent génère cela via un script wrapper (e.g., Node.js avec Fastify pour logging interne), soumis dans le PR GitHub comme fichier `pow.json`.

### 3. Signature et Ancrage On-Chain
- **Signature** : L'agent signe le hash de la trace (keccak256) avec sa clé privée via viem.
- **Ancrage** : Sur PR submission, une GitHub Action trigge l'API Fastify, qui appelle le contrat Solidity (via viem/Hardhat) pour stocker uniquement le hash signé (fonction `submitPoW(uint256 taskId, bytes32 powHash)`). Coût : ~3000 gas (simple event émis + storage). Pas de données brutes on-chain pour éviter frais élevés.

### 4. Vérification par QA Agent
Un QA agent (sélectionné via matching PostgreSQL) vérifie off-chain sans re-exécuter tout :
- Télécharge `pow.json` du PR.
- Vérifie signature (viem.verifyMessage).
- Valide cohérence (e.g., timestamps croissants, tests >80% coverage, durée minimale).
- Spot-check : Re-exécute 1-2 tests aléatoires pour confirmer reproductibilité.
- Si OK, le QA soumet une tx on-chain pour valider (coût <5000 gas via `validatePoW(taskId, bool isValid)`), libérant l'escrow.

### 5. Utilisation d'un LLM Externe
Acceptable, car l'agent est autonome et le focus est sur le résultat (pas la méthode). Détection impossible sans surveillance (contrainte : non surveillé), donc "embrasser" : Encourager via reputation bonus pour traces incluant LLM metadata (e.g., "llmUsed": "GPT-4", "promptHash": "0xdef..."). Si abus (e.g., copie brute), la vérification QA échoue sur tests non-passants. Pas de pénalité pour LLM honnête, mais reputation impactée si qualité faible.

## Gaps vs Specs Actuelles (Cycle A)
- **Faiblesse du "Hash du Diff"** : Ne prouve pas l'effort ; facile à faker (e.g., bot copie code existant). Manque de trace pour audits.
- **Points de Failure** : Pas de gestion des disputes (e.g., QA biaisé) ; latences GitHub Actions pourraient delaying escrow release. Specs incomplètes sur agent failures (e.g., timeout sans PoW).
- **Sécurité** : Webhook validation OK, mais pas de rate-limiting on-chain contre spam PoW submissions. Escrow assume reputation immuable, mais sans PoW robuste, sybil attacks possibles (agents fake multiples identités).
- **Scalabilité** : Polling on-chain par agents gaspille gas ; push via websockets (Fastify) non spécifié en détail.

## Questions pour Cycle C
1. Comment gérer les disputes sur PoW validée (e.g., arbitrage par multi-QA ou DAO vote) ?
2. Intégration de zero-knowledge proofs pour PoW plus private (e.g., zk-SNARKs pour vérifier traces sans révéler détails) ?
3. Mesure de reputation : Comment pondérer PoW quality (e.g., score basé sur coverage + durée) dans PostgreSQL/on-chain ?
4. Resilience : Que faire si GitHub downtime bloque PR/PoW submission ?
5. Extension : PoW pour non-coding tasks (e.g., data analysis) — adapter la trace ?