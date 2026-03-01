# AGENT-CODING-GUIDE Challenge — Grok 4

# Mises à Jour pour AGENT-CODING-GUIDE.md

Voici une liste des sections du guide à mettre à jour, basée sur les nouvelles décisions du brainstorm. Chaque item identifie une section concernée, ce qui est faux/manquant, et la correction exacte. Limité à 10 items pour prioriser les changements essentiels. Ces mises à jour peuvent être appliquées directement par un agent de patching.

### Item 1
- **Section concernée**: 1. Résumé du projet
- **Ce qui est faux/manquant**: Les fees sont listées comme "10% total: 3% burn, 5% insurance, 2% treasury" (impliquant 90% au reste), mais cela a été corrigé à 95/3/2 sans mention de 5% insurance.
- **Correction exacte**: Remplacer la phrase par : "Le token $AGNT (ERC-20, 100M supply) gère staking (min 1,000 AGNT), fees (5% total: 3% burn, 2% treasury, 95% au provider) et gouvernance."

### Item 2
- **Section concernée**: 1. Résumé du projet
- **Ce qui est faux/manquant**: Pas de mention de l'EAL (Execution Attestation Log) comme format de proof of work pour les agents.
- **Correction exacte**: Ajouter à la fin de la section : "Les agents utilisent EAL (Execution Attestation Log) comme format de proof of work pour valider les exécutions."

### Item 3
- **Section concernée**: 1. Résumé du projet
- **Ce qui est faux/manquant**: Pas de mention du TDL (Task Description Language) en YAML frontmatter, que les agents doivent parser.
- **Correction exacte**: Ajouter après "Fonctionnalités clés" : "Les missions utilisent TDL (Task Description Language) en format YAML frontmatter, que les agents doivent savoir parser pour interpréter les tâches."

### Item 4
- **Section concernée**: 1. Résumé du projet
- **Ce qui est faux/manquant**: La compliance OFAC est mentionnée comme "intégrée", mais sans préciser qu'elle est synchrone et bloquante (le guide pourrait impliquer async).
- **Correction exacte**: Modifier "compliance OFAC/KYC intégrée" en : "compliance OFAC/KYC intégrée de manière synchrone et bloquante."

### Item 5
- **Section concernée**: 1. Résumé du projet
- **Ce qui est faux/manquant**: Pas de mention du cap de reputation (Modèle A = 70).
- **Correction exacte**: Ajouter après "Fonctionnalités clés" : "Reputation cap implémenté via Modèle A avec une limite maximale de 70."

### Item 6
- **Section concernée**: 4. Interfaces Solidity clés
- **Ce qui est faux/manquant**: Pas d'interface pour le nouveau contrat ReviewerRegistry.sol.
- **Correction exacte**: Ajouter une nouvelle interface après IMissionEscrow :
  ```solidity
  interface IReviewerRegistry is IAccessControl {
      function registerReviewer(string calldata reviewerURI) external returns (uint256 reviewerId);
      function getReviewer(uint256 reviewerId) external view returns (address owner, string memory uri);
  }
  ```

### Item 7
- **Section concernée**: 4. Interfaces Solidity clés
- **Ce qui est faux/manquant**: Pas d'interface pour MinimalForwarder.sol (pour meta-transactions).
- **Correction exacte**: Ajouter une nouvelle interface à la fin de la section :
  ```solidity
  interface IMinimalForwarder {
      function execute(address to, bytes calldata data) external returns (bool success, bytes memory returndata);
      function getNonce(address from) external view returns (uint256);
  }
  ```

### Item 8
- **Section concernée**: 4. Interfaces Solidity clés
- **Ce qui est faux/manquant**: Pas d'interface pour ColdStartVault.sol.
- **Correction exacte**: Ajouter une nouvelle interface après IInsurancePool :
  ```solidity
  interface IColdStartVault is IAccessControl {
      function deposit(uint256 amount) external;
      function withdraw(uint256 amount) external;
      function getVaultBalance() external view returns (uint256);
  }
  ```

### Item 9
- **Section concernée**: 4. Interfaces Solidity clés
- **Ce qui est faux/manquant**: Dans IAGNTToken, le burn est listé comme "function burn(uint256 amount) external;", mais il doit être via buy-and-burn pour AGNT (pas USDC).
- **Correction exacte**: Ajouter une note après l'interface IAGNTToken : "// Note: Burn implémenté via buy-and-burn pour AGNT, pas directement sur USDC."

### Item 10
- **Section concernée**: 6. Patterns obligatoires
- **Ce qui est faux/manquant**: Pas de mention du diagramme Mermaid pour la state machine de MissionEscrow.
- **Correction exacte**: Ajouter un nouveau sous-point : "- **State Machine**: Utiliser le diagramme Mermaid suivant pour la state machine de MissionEscrow (ajouter à l'architecture) :
  ```mermaid
  stateDiagram-v2
      [*] --> CREATED
      CREATED --> FUNDED: fund
      FUNDED --> ACCEPTED: accept
      ACCEPTED --> IN_PROGRESS: start
      IN_PROGRESS --> DELIVERED: deliver
      DELIVERED --> COMPLETED: complete
      DELIVERED --> DISPUTED: dispute
      DISPUTED --> COMPLETED: resolve (client loses)
      DISPUTED --> REFUNDED: resolve (client wins)
      [*] --> CANCELLED: cancel
  ```"