# Cycle O — Grok 4: 10 Critical Edge Cases

### Edge Cases Critiques pour Agent Marketplace

Voici les 10 edge cases les plus critiques non couverts, avec sévérité, comportement actuel et correction minimale V1.

1. **Timing attacks** (deux agents acceptent simultanément)  
   - Sévérité: Critical  
   - Comportement actuel: Undefined behavior (risque de double assignation).  
   - Correction V1: Implémenter verrou atomique on-chain pour first-come-first-served; rejeter la seconde acceptation.

2. **Partial failures** (USDC OK mais event on-chain échoue)  
   - Sévérité: High  
   - Comportement actuel: Undefined behavior (état inconsistante).  
   - Correction V1: Ajouter retry mechanism avec timeout; rollback USDC si event fails.

3. **Agent suicide** (provider détruit agent en mission)  
   - Sévérité: Critical  
   - Comportement actuel: Undefined behavior (escrow bloqué).  
   - Correction V1: Détecter via heartbeat; auto-forfeit mission et libérer escrow aux reviewers.

4. **Reviewer disappears** (2/3 votent, 3ème absent)  
   - Sévérité: High  
   - Comportement actuel: Undefined behavior (dispute bloquée).  
   - Correction V1: Timeout après 24h; majorité des votes existants gagne, sinon default à échec.

5. **Jeff underfunds** (dépôt < minimum)  
   - Sévérité: Medium  
   - Comportement actuel: Undefined behavior (mission potentiellement créée).  
   - Correction V1: Valider montant on-chain avant création; rejeter si insuffisant.

6. **Chain reorg pendant dispute** (vote réorganisé)  
   - Sévérité: Critical  
   - Comportement actuel: Undefined behavior (résultat corrompu).  
   - Correction V1: Utiliser finality checks (e.g., 10 blocks); re-vote si reorg détecté.

7. **IPFS pin failure** (payload perdu)  
   - Sévérité: High  
   - Comportement actuel: Undefined behavior (hash sans data).  
   - Correction V1: Exiger multi-pinning (e.g., via service); fallback à rejection si unpinned.

8. **Agent changes DID** (révocation en mission)  
   - Sévérité: High  
   - Comportement actuel: Undefined behavior (auth cassée).  
   - Correction V1: Locker DID au début de mission; ignorer changements jusqu'à fin.

9. **Multiple EALs** (2 submissions pour même mission)  
   - Sévérité: Medium  
   - Comportement actuel: Undefined behavior (duplication).  
   - Correction V1: Accepter seulement le premier EAL on-chain; ignorer subséquents.

10. **Treasury drained** (pool vide en dispute)  
    - Sévérité: Critical  
    - Comportement actuel: Undefined behavior (paiement impossible).  
    - Correction V1: Vérifier solde avant dispute; halt disputes si drained, notifier admins.

(Total: 348 mots)