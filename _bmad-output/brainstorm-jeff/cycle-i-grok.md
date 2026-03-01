# Cycle I — Grok 4: Compute Model

# Cycle I: Compute Model pour Agent Marketplace

## Décisions Tranchées

Après analyse des modèles A (agent sur infra provider) et B (compute fourni par marketplace via GitHub Actions), nous optons pour un **modèle hybride en V1** pour équilibrer décentralisation et sécurité. Cela combine les avantages des deux : flexibilité pour les providers expérimentés (Modèle A) et trust élevé pour les débutants ou missions sensibles (Modèle B). Le choix du mode est laissé au provider lors de l'enregistrement on-chain, mais influence directement la réputation et le matching. Cela permet une scalabilité progressive vers plus de décentralisation tout en minimisant les risques initiaux de cold start.

1. **Décision V1 : Hybride avec incitation vers Modèle B**. Tous les agents commencent en Modèle B par défaut (runner GitHub Actions officiel, sandboxé avec egress bloqué et Semgrep OWASP). Les providers peuvent opter pour Modèle A après un seuil de réputation (e.g., 10 missions réussies en B). Cela assure une vérifiabilité initiale et réduit les coûts de onboarding. La marketplace self-hoste les runners via un repo dédié, avec scaling via GitHub's hosted runners (coût ~0.008$/min, couvert par fees). Transition vers A autorisée pour scalabilité, mais avec pénalités si abus.

2. **Différenciation de l'EAL selon le mode**. L'Execution Attestation Log (EAL) est un JSON standardisé (signé via EIP-712) incluant logs d'exécution, hashes de inputs/outputs et timestamps. En Modèle B, l'EAL est **high-trust** : auto-généré par le workflow GitHub (vérifiable via API GitHub, immutable). En Modèle A, il est **low-trust** : self-attested par le provider, avec validation heuristique (e.g., durée d'exécution cohérente, absence de red flags via ML spotting). Un EAL low-trust déclenche un QA plus strict (e.g., review manuel obligatoire vs. spot-check en B), impactant les disputes (reviewers favorisent high-trust).

3. **Installation et configuration sur infra provider**. Pour Modèle A, le provider installe lui-même via un **npm package standardisé** (@agent-marketplace/cli), qui inclut un runtime Dockerisé (image officielle basée sur Node.js/Alpine, avec sandbox via nsjail pour isolation). Configuration via CLI : `agent setup --key=privateKey --mode=A`, qui déploie un heartbeat on-chain et teste la conformance. La marketplace fournit docs et templates, mais le provider est responsable (auto-certification initiale).

4. **Preuve de sandbox conforme sans TEE**. Sans Trusted Execution Environment (TEE) en V1 (trop coûteux), la preuve repose sur **self-attestation + vérification décentralisée**. Le provider soumet un hash de config (e.g., Docker compose avec egress bloqué via iptables) lors de l'enregistrement. Conformance prouvée via audits aléatoires par reviewers (tirés du pool, incentivés par 2% fees) ou heartbeat checks (e.g., ping vers un endpoint bloqué). Non-conformance = ban + stake slash. À long terme, intégrer ZK-proofs pour audits off-chain.

5. **Impact sur le matching**. Oui, Modèle B donne un **avantage clair** : +20% au score de réputation (e.g., capabilities match * 1.2), priorisant ces agents pour missions high-value ou disputed. Modèle A compense via frais réduits (pas de GitHub costs) mais risque de matching plus lent (e.g., seulement si aucun B disponible). Cela incite l'adoption de B pour cold start, tout en récompensant la décentralisation mature.

Ce modèle hybride aligne sur le flow existant (GitHub-centric) tout en scalant vers la décentralisation. Coûts estimés : ~$500/mois pour runners initiaux, couverts par fees. Total : 420 mots.

## Questions Cycle J
- **Reputation system** : Comment structurer le scoring (e.g., weighted avg de success rate, EAL trust, dispute history) ? Impact sur staking et slashing ?
- **Scaling compute** : Si overload en Modèle B, fallback auto vers A ? Intégrer providers comme runners décentralisés (e.g., via Akash Network) ?
- **Security edge cases** : Gestion des fuites en Modèle A (e.g., via watermarking payloads) ? Audit frequency pour conformance ?