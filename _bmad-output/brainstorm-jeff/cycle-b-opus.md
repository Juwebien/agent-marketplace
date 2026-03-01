# Cycle B — Opus: Proof of Work Spec (Execution Attestation Log)

## Le problème fondamental

Un hash de diff prouve qu'un diff existe. Pas qu'un agent l'a produit. On a besoin d'une **preuve d'exécution**, pas d'une preuve de résultat.

## Principe V1 : Execution Attestation Log (EAL)

### Payload `ExecutionAttestation` — champs exacts

```json
{
  "version": "eal-v1",
  "taskId": "0x...",
  "agentId": "did:key:***",
  "environment": {
    "image": "ghcr.io/marketplace/sandbox:sha256-abc...",
    "runtime": "github-actions",
    "runId": "12345678",
    "runUrl": "https://github.com/org/repo/actions/runs/12345678"
  },
  "trace": {
    "commandLog": "ipfs://Qm...",
    "testResults": {
      "framework": "vitest",
      "passed": 42,
      "failed": 0,
      "hash": "sha256:deadbeef..."
    },
    "commits": ["abc1234"],
    "diffHash": "sha256:cafebabe...",
    "startedAt": "2026-03-01T00:00:00Z",
    "completedAt": "2026-03-01T00:12:37Z"
  },
  "llmDisclosure": {
    "used": true,
    "providers": ["anthropic/claude-sonnet-4"],
    "tokenEstimate": 45000
  },
  "signature": "0x..."
}
```

## Ancrage on-chain — < 5000 gas

```solidity
struct Attestation {
    bytes32 ealHash;   // keccak256 du JSON complet (stocké IPFS)
    address agent;     // ecrecover
    uint48 timestamp;
    Status status;     // Submitted | Verified | Disputed
}
```

Payload sur IPFS. On-chain = hash + signature seulement. ~4200 gas. ✅

## Vérification QA Agent — sans tout re-exécuter

1. Structural check: signature valide, runId existe via GitHub API
2. Duration heuristic: timing cohérent avec la complexité
3. Test replay sélectif: re-run tests dans la même image Docker
4. Diff review: le diff répond-il à l'issue ? (LLM reviewer OK)

## LLM externe — embrasser, pas combattre

- Disclosure obligatoire mais déclaratif (V1)
- Ce qui compte = tests passent + diff résout l'issue
- `llmDisclosure` alimente le score de réputation
- V2 (TEE): vérification des appels API sortants

## Questions ouvertes — Cycle C

1. Comment un QA agent détecte-t-il un plagiat (copypaste depuis internet) si les tests passent quand même ?
2. Qui maintient l'image sandbox officielle ? Qui l'audite ?
3. Dispute : le mainteneur refuse un PR valide. Qui tranche ? DAO vote ? Multisig ? Délai ?
4. Comment l'agent s'authentifie-t-il avec révocation possible (pas juste un wallet) ?
5. Si l'agent utilise un LLM qui génère du code backdooré, qui est responsable ?
