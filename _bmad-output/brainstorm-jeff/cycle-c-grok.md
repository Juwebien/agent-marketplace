# Cycle C — Grok 4: Dispute Resolution + Security

# Cycle C: Dispute Resolution + Security — Quand Ça Tourne Mal

**Expert Sécurité :** En tant qu'expert en sécurité pour l'Agent Marketplace, je priorise des mécanismes robustes, minimisant les risques sans DAO en V1. Nous nous appuyons sur le multisig 3/5 pour la gouvernance centralisée, Solidity pour les contrats on-chain, GitHub Actions pour les sandboxes d'exécution, et Fastify pour les APIs backend. Toutes les décisions sont tranchées pour une implémentation V1 claire : pas d'options alternatives. Le focus est sur la détection précoce, la traçabilité via EAL (Execution Attestation Log : JSON signé EIP-712 sur IPFS, hash ancré on-chain), et des pénalités automatisées. Cela s'appuie sur la synthèse du Cycle B, où les tests sandboxés et le spot-checking QA assurent une base de proof-of-work.

## 1. Flow de Dispute Complet
Décision tranchée : Le multisig 3/5 tranche toutes les disputes en V1. Flow précis :  
- L'agent soumet l'EAL via API Fastify, attestant l'exécution (tests passés dans GitHub Actions).  
- Le mainteneur a 48h pour valider ou disputer via une transaction on-chain (contrat Solidity), en joignant des preuves (logs, diffs code).  
- Si dispute, le multisig est notifié automatiquement via webhook Fastify. Les 3/5 membres revuent les EAL et preuves off-chain (via interface sécurisée), puis votent on-chain pour approuver/rejeter.  
- Résolution : Si validé, paiement libéré ; sinon, fonds slashed (50% à mainteneur, 50% burn). Pas d'appel possible en V1 pour simplicité. Cela évite les abus en centralisant sur un petit groupe de confiance, tout en ancrant tout sur-chain pour auditabilité.

## 2. Anti-Plagiat
Décision tranchée : Détection automatisée via intégration de l'outil open-source Moss (Measure of Software Similarity) dans les GitHub Actions workflows.  
- À la soumission de code par l'agent, le workflow GitHub Actions exécute Moss contre une base de données curated (sources open comme GitHub repos publics, Stack Overflow).  
- Seuil : Si similarité >70%, l'EAL est marqué "plagiat suspect" et rejeté automatiquement ; l'agent est notifié via API Fastify.  
- Pas de QA manuel en V1 pour scalabilité ; spot-checking QA (du Cycle B) sert de backup aléatoire sur 10% des submissions. Si détecté post-acceptation, dispute flow (ci-dessus) s'applique avec slash automatique via contrat Solidity. Cela protège l'intégrité sans surcharger le système, en s'appuyant sur des outils existants pour une détection rapide.

## 3. Backdoor LLM
Décision tranchée : Responsabilité pleine sur l'agent ; slash automatique de 100% des stakes via contrat Solidity si backdoor détectée.  
- Détection : Intégrer Snyk ou Semgrep dans les GitHub Actions pour scanner les vulnérabilités (e.g., code injecté malveillant). QA agent (spot-checking) revue manuellement 20% des outputs LLM pour backdoors subtiles.  
- Si backdoor confirmée (e.g., via dispute ou audit post-déploiement), le mainteneur déclenche un "slash event" on-chain, prouvé par EAL logs. L'agent perd ses stakes, banni via révocation auth (voir #4).  
- Pas de responsabilité partagée : L'agent signe l'EAL, attestant l'intégrité ; mainteneur doit auditer avant déploiement. Cela incite à la vigilance, avec traçabilité IPFS pour poursuites légales si needed.

## 4. Auth Agent avec Révocation V1
Décision tranchée : Auth minimale via signatures EIP-712 on-chain, avec révocation par multisig 3/5.  
- Spec : Agents s'enregistrent via transaction Solidity (adresse wallet + metadata JSON sur IPFS). Toute action (soumission EAL, dispute) requiert signature EIP-712 validée par Fastify API avant on-chain.  
- Révocation : Multisig 3/5 peut blacklister une adresse via contrat update (e.g., pour abus répétés). Pas de self-révocation en V1 ; focus sur centralisé pour simplicité. Clés stockées côté agent, avec nonce pour replay protection. Cela assure une auth légère mais sécurisée, intégrée au stack existant sans complexité ajoutée.

## 5. Sandbox Threat Model
Décision tranchée : Threat model assume un agent malveillant peut exfiltrer data limitée ou consommer resources, mais sandbox GitHub Actions limite à l'exécution isolée.  
- Menaces possibles : (1) Exfiltration de secrets via network calls (mitigé par firewall GitHub Actions bloquant outbound non-autorisé) ; (2) Resource exhaustion (e.g., infinite loops, limité à 6h timeout et quotas CPU/RAM) ; (3) Code injection pour persistance (impossible, car runs éphémères sans state persistant) ; (4) Side-channel attacks (e.g., timing, bas risque car pas d'accès hardware partagé).  
- Pas d'accès à repos mainteneur hors fork temporaires ; tous outputs logués dans EAL pour forensic. Si abus détecté (e.g., via monitoring Fastify), révocation immédiate par multisig. Modèle priorise containment : rien ne sort sans validation QA.

**Synthèse Sécurité Globale :** Ces décisions forment un système V1 résilient, avec multisig comme bottleneck de confiance, EAL comme preuve immuable, et automatisations GitHub/Fastify pour scalabilité. Risques résiduels : abus multisig (mitigé par 3/5 threshold) et faux positifs détection (acceptables pour V1). Total : ~620 mots.

## Questions pour Cycle D
1. Intégration paiements : Comment structurer les escrow Solidity pour disputes automatisées ?  
2. Scaling QA : Si volume augmente, remplacer spot-checking par quoi (sans DAO) ?  
3. Audit externe : Quel framework pour auditer les contrats Solidity avant launch ?  
4. User privacy : Comment protéger metadata agents dans IPFS sans leaks ?  
5. Evolution V2 : Premiers pas vers DAO pour decentraliser disputes ?