# PRD Challenge — Opus: 10 Affirmations Douteuses

## 1. "30% rework tax" — chiffre fantôme
- Non sourcé. Workday (40%) et Zapier (4.5h/semaine) mesurent autre chose.
- **Fix:** "teams report significant rework on AI outputs" sans chiffre inventé

## 2. Étude METR utilisée à contresens
- METR dit: overhead cognitif IA, pas mismatch. Une marketplace ne résout pas ça.
- **Fix:** Retirer ou reformuler honnêtement

## 3. OKR "10,000 missions/mois à 12 mois" — délirant
- 20x en 6 mois avec 100 providers = 3+ missions/jour/provider. $500K-1M/mois volume. Irréaliste.
- **Fix:** Modèle bottom-up : clients × fréquence × taille

## 4. Matrice concurrentielle biaisée
- Compare produit inexistant (✅ partout) à produits en production. Zero-trust est en V2 mais marqué ✅.
- **Fix:** Colonne "Status" (Live/Planned/V2)

## 5. Business model Stripe→USDC→AGNT — friction cachée
- Stripe fees (2.9%+30¢) + conversion + DEX slippage + 10% protocol = provider reçoit ~$38-40 sur $50.
- **CRITIQUE:** Stripe bannit souvent les comptes crypto. Risque existentiel.
- **Fix:** Modéliser coût réel. Vérifier Stripe ToS crypto. Documenter qui paie chaque couche.

## 6. "Rework reduction 15% à 6 mois" — immesurable
- Mesuré par user survey (auto-déclaration). Pas de baseline pré-marketplace.
- **Fix:** Remplacer par métriques objectives (dispute rate, resubmission rate)

## 7. "77% executives cite trust as barrier" — Accenture sans date
- Citation sans lien, sans méthodologie. Executives = ≠ l'ICP (startups 10-50 personnes).
- **Fix:** Source complète ou retirer

## 8. Timeline "Week 20 MVP" — délusion
- 20 semaines pour: 4 smart contracts audités + API complète + UI + SDK + infra Base Sepolia. Avec 4 devs seniors.
- Week 6 = smart contract audit = 4-6 semaines minimum pour un auditeur externe.
- **Fix:** Timeline réaliste avec buffer audit

## 9. "Cold start: 50 agents, 5 guaranteed missions" — qui les paye ?
- Les 5 missions "guaranties" nécessitent de vrais clients. Qui sont-ils ?
- **Fix:** Treasury pré-finance 250 missions de bootstrap ($X budget réel)

## 10. KYC $1K/tx + $3K lifetime — compliance theatre
- Basé sur FinCEN MSB rules mais marketplace crypto n'est probablement pas une MSB.
- Legal opinion nécessaire AVANT de coder le KYC.
- **Fix:** Legal opinion Week 1, avant d'implémenter quoi que ce soit
