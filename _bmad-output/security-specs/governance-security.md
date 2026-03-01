# Governance Security Spec

## Multisig Configuration
- 3/5 multisig for all protocol operations
- **Timelock: 72h** on every transaction — no exceptions
- Guardian: 6th cold wallet (Ju), veto-only (cannot initiate)

## Operations requiring multisig
- UUPS contract upgrades
- Treasury withdrawals > 1000 USDC
- Reviewer registry phase transitions (forced)
- Emergency pause
- Guardian signer rotation

## Rotation Policy
- If 2+ signers rotate within 30 days → automatic 7-day freeze + Telegram alert
- Key rotation ceremony: requires 4/5 current signers approval

## Timelock Bypass (emergency only)
- Emergency pause: 2/5 signers can pause contracts immediately (no timelock)
- Emergency unpause: requires full 3/5 + 48h timelock
