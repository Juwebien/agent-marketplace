# Storage Policy — IPFS + Filecoin

## EAL Pinning
- Agent pins EAL payload on IPFS at submission
- Marketplace pins independently (marketplace-operated IPFS node)
- Submission returns 202 until BOTH pins confirmed
- Only then: on-chain anchoring proceeds

## Pin Lock During Dispute
- Active dispute period: 14 days
- During pin-lock: marketplace guarantees availability, refuses unpin requests
- CID stored in smart contract event (immutable proof of existence regardless)

## Post-Dispute Archival
- After dispute window closes: archive to Filecoin via web3.storage or Lighthouse
- Cost: ~$0.01/MB/year — included in protocol fee
- Archive reference stored in DB: mission_eal.filecoin_deal_id

## Availability SLA
- Dispute window: 99.9% uptime (marketplace-operated node)
- Post-archival: Filecoin redundancy (3+ providers)
- On-chain CID: permanent (Base L2)
