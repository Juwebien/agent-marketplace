# Cycle H — Grok 4: Synthesis + Build-Readiness Re-Score

### 7 Gaps les Plus Bloquants Restants

1. **ReviewerRegistry.sol spec manquante**  
   - Bloquant car sans specs claires, le smart contract ne peut pas être implémenté ou audité, empêchant l'enregistrement et la sélection des reviewers pour les disputes.  
   - Effort : s (rédiger specs basées sur flow existant).  
   - Dépendances : Tirage reviewers (besoin de registry pour anti-Sybil).

2. **Meta-tx relayer : GSN ou Biconomy ? centralisé au lancement ?**  
   - Bloquant car sans relayer, les agents ne peuvent pas interagir gratuitement (gas payé par client), rendant la plateforme inaccessible pour les agents sans fonds ETH.  
   - Effort : m (intégrer GSN/Biconomy, tester centralisation initiale).  
   - Dépendances : Aucune directe, mais impacte auth et state machine.

3. **DAG de dépendances entre issues**  
   - Bloquant car sans gestion des dépendances, les missions complexes (multi-issues) risquent des deadlocks ou exécutions chaotiques, rendant la plateforme inutilisable pour tâches réelles.  
   - Effort : m (implémenter graphe dans indexer/state machine).  
   - Dépendances : State machine (états doivent supporter DAG).

4. **Compute model de l'agent runtime (son infra ou marketplace ?)**  
   - Bloquant car sans décision sur l'infra (agent vs. marketplace), les agents ne savent pas comment exécuter les tâches, empêchant tout proof of work viable.  
   - Effort : s (décider et documenter, potentiellement marketplace pour beta).  
   - Dépendances : Sandbox (lié à l'infra choisie) et EAL forgery (vérification runtime).

5. **Tirage reviewers résistant au Sybil (block.prevrandao manipulable ?)**  
   - Bloquant car un tirage manipulable permet des attaques Sybil, corrompant les disputes et minant la confiance, rendant les paiements injustes.  
   - Effort : m (implémenter VRF ou alternative résistante).  
   - Dépendances : ReviewerRegistry (base pour anti-Sybil).

6. **EAL forgery : runId réel d'un autre run = vérification impossible sans API GitHub**  
   - Bloquant car sans vérification anti-forgery, les proofs of work peuvent être falsifiés, permettant des fraudes massives et rendant les validations inutiles.  
   - Effort : l (intégrer API GitHub sécurisée ou oracle décentralisé).  
   - Dépendances : Compute model (vérification dépend du runtime) et sandbox (logs GitHub Actions).

7. **Supply chain attack via dépendances npm**  
   - Bloquant car des vulnérabilités npm exposent l'agent runtime à des attaques, compromettant la sécurité globale et empêchant un lancement beta sûr.  
   - Effort : s (audit npm, verrouiller versions, intégrer semgrep).  
   - Dépendances : Sandbox (renforce la mitigation) et compute model (dépend de l'infra).

### Score BUILD-READINESS
**75/100**  
Justification : Les cycles A-F ont validé un flow core robuste (state machine, auth, PoW via EAL, dispute process, fee split, indexer, sandbox), couvrant ~75% des besoins pour une beta (e.g., GitHub integration, on-chain anchoring, meta-tx base). Cependant, les 7 gaps restants bloquent l'utilisabilité réelle : sécurité (Sybil, forgery, supply chain), scalabilité (DAG, compute model) et implémentation de base (specs, relayer) empêchent un lancement fonctionnel. Résolution prioritaire des efforts s/m pourrait porter à 90+.

(412 mots)