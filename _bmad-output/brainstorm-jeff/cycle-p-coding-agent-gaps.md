# Cycle P — Grok 4: What a Coding Agent Needs But Specs Don't Say

1. **Bootstrapper l'environnement local ?** Non documenté. Réponse: Suivre steps: cloner repo, copier .env.example en .env, remplir vars, run `docker-compose up -d`, puis `pnpm install` et `pnpm prisma generate`.

2. **Ordre déploiement contrats ?** Non documenté. Réponse: Déployer d'abord USDC mock, puis ReputationOracle, MissionFactory, ensuite Mission (dépend de Factory), enfin FiatOnRamp (dépend de USDC).

3. **Obtenir adresses contrats déployés ?** Non documenté. Réponse: Utiliser script Hardhat avec artifacts; stocker adresses dans JSON post-déploiement, les passer via constructor args aux contrats dépendants.

4. **Initialiser ReputationOracle ?** Non documenté. Réponse: Après déploiement, appeler init() sur ReputationOracle avec adresses de MissionFactory et autres; utiliser owner account pour setup initial.

5. **Valeur MINIMUM_MISSION_AMOUNT ?** Non documenté. Réponse: 10 USDC = 10000000 (10 * 10^6 decimals pour USDC).

6. **Tester local sans Stripe/Transak ?** Non documenté. Réponse: Implémenter mock API endpoints dans backend pour simuler onramp; utiliser faucet local pour mint USDC test.

7. **Format exact JWT auth API ?** Non documenté. Réponse: Algo HS256, claims: {sub: userId, role: string, iat/exp: UNIX timestamps}, expiry 1h, signed avec secret from .env.

8. **Gérer migrations DB au démarrage ?** Non documenté. Réponse: Utiliser `prisma migrate deploy` en prod; `prisma migrate dev` en local; run via script on startup si pas auto.

9. **Version Base Sepolia pour tests ?** Non documenté. Réponse: Chain ID 84532, RPC URL: https://sepolia.base.org (utiliser Alchemy/Infura pour stability).

10. **Config CI/CD ?** Non documenté. Réponse: GitHub Actions: workflow pour tests (pnpm test + Hardhat) on push/PR, deploy sur merge to main via Vercel/Netlify pour frontend/backend.