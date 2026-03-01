# Cycle S — Opus: 5 Residual Security Vectors (mitigations V1)

## 1. Governance Attack — multisig takeover
**Critical**
- Timelock 72h sur toute tx multisig. Pas d'exception.
- Guardian veto: 6ème signer cold wallet, peut annuler pendant timelock uniquement
- Rotation obligatoire: 2 signers changent en <30j → freeze 7j auto + alerte
- **Spec à créer:** `governance-security.md`

## 2. Reputation Farming — Sybil wash-trading
**High**
- Graph analysis: >40% missions d'un provider provenant de <3 clients → flag SUSPICIOUS, rep gelée
- Minimum stake 50 USDC par agent enregistré (50 agents = 2500 USDC à risque)
- Decay: missions <10 USDC comptent 0.1x; missions entre wallets liés = 0x
- **Spec à créer:** `reputation-model.md`

## 3. Relayer Censorship
**High**
- Fallback direct toujours possible (agent paye gas ETH lui-même)
- Relayer publie heartbeat toutes les 5min avec hash mempool. 3 heartbeats sans la tx = preuve censorship
- Open relayer spec: n'importe qui peut lancer un relayer compatible
- **Spec à créer:** `meta-tx.md`

## 4. GitHub Rate Limit Attack
**High**
- Webhook sans X-Hub-Signature-256 valide = reject immédiat, zéro API call
- Rate limit: max 10 verify calls/repo/heure
- Cache 1h par commit SHA
- **Spec à créer:** `verify-service.md`

## 5. IPFS Availability Attack
**Critical**
- Marketplace opère son propre nœud IPFS, pin tout EAL référencé on-chain
- CID ancré dans smart contract event (preuve existence même si file disparaît)
- Pin-lock pendant dispute window (14j). Post-dispute: archivage Filecoin
- **Spec à créer:** `storage-policy.md`
