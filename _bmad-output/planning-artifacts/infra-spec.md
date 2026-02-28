# Agent Marketplace - Infrastructure Specification

## 1. Repository Structure

```
agent-marketplace/
├── contracts/                    # Hardhat project (Solidity 0.8.20)
│   ├── src/
│   │   └── contracts/
│   │       ├── AgentNFT.sol
│   │       ├── MissionRegistry.sol
│   │       └── Marketplace.sol
│   ├── test/                     # Contract tests (100% coverage target)
│   ├── scripts/
│   │   ├── deploy.ts             # Local deploy script
│   │   └── verify.ts            # Contract verification
│   ├── hardhat.config.ts
│   └── package.json
├── api/                          # Fastify API (Node.js/TypeScript)
│   ├── src/
│   │   ├── routes/
│   │   │   ├── agents.ts
│   │   │   ├── missions.ts
│   │   │   └── health.ts
│   │   ├── services/
│   │   │   ├── agent.service.ts
│   │   │   ├── mission.service.ts
│   │   │   └── blockchain.service.ts
│   │   ├── models/
│   │   │   ├── agent.model.ts
│   │   │   └── mission.model.ts
│   │   ├── indexer/
│   │   │   └── event-listener.ts
│   │   ├── db/
│   │   │   └── postgres.ts
│   │   └── index.ts
│   ├── tests/
│   └── package.json
├── sdk/                          # Provider SDK
│   ├── typescript/
│   │   ├── src/
│   │   │   ├── client.ts
│   │   │   └── types.ts
│   │   └── package.json
│   └── python/
│       ├── agent_marketplace/
│       │   ├── __init__.py
│       │   └── client.py
│       └── pyproject.toml
├── web/                          # Next.js 14 (App Router)
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx
│   │   │   ├── agents/
│   │   │   ├── missions/
│   │   │   └── api/
│   │   ├── components/
│   │   ├── lib/
│   │   │   ├── api.ts
│   │   │   └── wagmi.ts
│   │   └── styles/
│   ├── public/
│   ├── next.config.js
│   └── package.json
└── k8s/                          # Kubernetes manifests
    ├── base/
    │   ├── namespace.yaml
    │   ├── api-deployment.yaml
    │   ├── indexer-deployment.yaml
    │   ├── web-deployment.yaml
    │   ├── api-service.yaml
    │   ├── indexer-service.yaml
    │   ├── web-service.yaml
    │   ├── configmap.yaml
    │   └── secret.yaml
    └── overlays/
        ├── development/
        │   └── kustomization.yaml
        └── production/
            └── kustomization.yaml
```

---

## 2. Docker Compose (Local Development)

```yaml
# docker-compose.yml
version: '3.9'

services:
  # PostgreSQL 16 with pgvector extension
  postgres:
    image: pgvector/pgvector:pg16
    container_name: agent-marketplace-postgres
    environment:
      POSTGRES_USER: agent_marketplace
      POSTGRES_PASSWORD: dev_password
      POSTGRES_DB: agent_marketplace_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U agent_marketplace"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Redis for job queues
  redis:
    image: redis:7-alpine
    container_name: agent-marketplace-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  # Hardhat local node (Base Sepolia fork)
  hardhat:
    image: node:20-alpine
    container_name: agent-marketplace-hardhat
    working_dir: /app/contracts
    command: npx hardhat node --hostname 0.0.0.0
    ports:
      - "8545:8545"
    volumes:
      - ./contracts:/app/contracts
      - contracts_node_data:/app/contracts/node_data
    environment:
      CHAIN_ID: "31337"
      RPC_URL: "http://localhost:8545"

  # API Service (Fastify)
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    container_name: agent-marketplace-api
    ports:
      - "3001:3001"
    volumes:
      - ./api:/app
      - /app/node_modules
    environment:
      NODE_ENV: development
      PORT: 3001
      DATABASE_URL: postgresql://agent_marketplace:dev_password@postgres:5432/agent_marketplace_dev
      REDIS_URL: redis://redis:6379
      JWT_SECRET: dev_jwt_secret_change_in_production
      RPC_URL: http://hardhat:8545
      CHAIN_ID: "31337"
      CONTRACT_ADDRESSES: '{}'
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      hardhat:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

  # Indexer Service (Blockchain event listener)
  indexer:
    build:
      context: ./api
      dockerfile: Dockerfile
      target: indexer
    container_name: agent-marketplace-indexer
    volumes:
      - ./api:/app
      - /app/node_modules
    environment:
      NODE_ENV: development
      DATABASE_URL: postgresql://agent_marketplace:dev_password@postgres:5432/agent_marketplace_dev
      REDIS_URL: redis://redis:6379
      RPC_URL: http://hardhat:8545
      CHAIN_ID: "31337"
      CONTRACT_ADDRESSES: '{}'
      INDEXER_START_BLOCK: "0"
    depends_on:
      postgres:
        condition: service_healthy
      hardhat:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3002/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

  # Frontend (Next.js)
  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: agent-marketplace-web
    ports:
      - "3000:3000"
    volumes:
      - ./web:/app
      - /app/node_modules
      - /app/.next
    environment:
      NODE_ENV: development
      NEXT_PUBLIC_API_URL: http://localhost:3001
      NEXT_PUBLIC_CHAIN_ID: "31337"
      NEXT_PUBLIC_CONTRACT_ADDRESSES: '{}'
    depends_on:
      - api
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
  redis_data:
  contracts_node_data:

networks:
  default:
    name: agent-marketplace-network
```

---

## 3. Kubernetes Manifests (k3s)

### 3.1 Namespace

```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: agent-marketplace
  labels:
    name: agent-marketplace
    environment: production
```

### 3.2 ConfigMap

```yaml
# k8s/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-marketplace-config
  namespace: agent-marketplace
data:
  RPC_URL: "https://sepolia.base.org"
  CHAIN_ID: "84532"
  CONTRACT_ADDRESSES: '{"agentNFT":"0x...","missionRegistry":"0x...","marketplace":"0x..."}'
  NODE_ENV: "production"
  API_PORT: "3001"
  INDEXER_PORT: "3002"
  WEB_PORT: "3000"
  DATABASE_HOST: "postgres.agent-marketplace.svc.cluster.local"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "agent_marketplace"
  REDIS_HOST: "redis.agent-marketplace.svc.cluster.local"
  REDIS_PORT: "6379"
```

### 3.3 Secret

```yaml
# k8s/base/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: agent-marketplace-secret
  namespace: agent-marketplace
type: Opaque
stringData:
  # Database
  DATABASE_USERNAME: "agent_marketplace"
  DATABASE_PASSWORD: "CHANGE_ME_IN_PRODUCTION"
  
  # Blockchain
  ALCHEMY_API_KEY: "CHANGE_ME"
  PRIVATE_KEY: "CHANGE_ME"
  
  # Authentication
  JWT_SECRET: "CHANGE_ME_USE_64_CHAR_RANDOM_STRING"
  
  # External Services
  # Add more secrets as needed
```

### 3.4 PostgreSQL (StatefulSet)

```yaml
# k8s/base/postgres-statefulset.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: agent-marketplace
spec:
  ports:
    - port: 5432
      targetPort: 5432
      name: postgres
  clusterIP: None
  selector:
    app: postgres

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: agent-marketplace
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: pgvector/pgvector:pg16
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secret
                  key: DATABASE_USERNAME
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secret
                  key: DATABASE_PASSWORD
            - name: POSTGRES_DB
              value: "agent_marketplace"
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
```

### 3.5 Redis (Deployment)

```yaml
# k8s/base/redis-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: agent-marketplace
spec:
  ports:
    - port: 6379
      targetPort: 6379
      name: redis
  selector:
    app: redis

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: agent-marketplace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
              name: redis
          volumeMounts:
            - name: redis-data
              mountPath: /data
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
      volumes:
        - name: redis-data
          emptyDir: {}
```

### 3.6 API Deployment

```yaml
# k8s/base/api-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: agent-marketplace
spec:
  ports:
    - port: 3001
      targetPort: 3001
      protocol: TCP
      name: http
  selector:
    app: api
  type: ClusterIP

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: agent-marketplace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      containers:
        - name: api
          image: registry.ju/agent-marketplace-api:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 3001
              name: http
          env:
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: NODE_ENV
            - name: PORT
              valueFrom:
                configMapKeyRef:
                  key: API_PORT
            - name: RPC_URL
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: RPC_URL
            - name: CHAIN_ID
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CHAIN_ID
            - name: CONTRACT_ADDRESSES
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CONTRACT_ADDRESSES
            - name: DATABASE_URL
              value: "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@$(DATABASE_HOST):$(DATABASE_PORT)/$(DATABASE_NAME)"
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secret
                  key: DATABASE_PASSWORD
            - name: REDIS_URL
              value: "redis://$(REDIS_HOST):$(REDIS_PORT)"
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secret
                  key: JWT_SECRET
            - name: PRIVATE_KEY
              valueFrom:
                secretKeyRef:
                  name: agent-marketplace-secret
                  key: PRIVATE_KEY
          envFrom:
            - configMapRef:
                name: agent-marketplace-config
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 10
            periodSeconds: 5
```

### 3.7 Indexer Deployment

```yaml
# k8s/base/indexer-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: indexer
  namespace: agent-marketplace
spec:
  ports:
    - port: 3002
      targetPort: 3002
      protocol: TCP
      name: http
  selector:
    app: indexer
  type: ClusterIP

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: indexer
  namespace: agent-marketplace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: indexer
  template:
    metadata:
      labels:
        app: indexer
        version: v1
    spec:
      containers:
        - name: indexer
          image: registry.ju/agent-marketplace-indexer:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 3002
              name: http
          env:
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: NODE_ENV
            - name: RPC_URL
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: RPC_URL
            - name: CHAIN_ID
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CHAIN_ID
            - name: CONTRACT_ADDRESSES
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CONTRACT_ADDRESSES
            - name: INDEXER_START_BLOCK
              value: "0"
          envFrom:
            - configMapRef:
                name: agent-marketplace-config
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3002
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 3002
            initialDelaySeconds: 10
            periodSeconds: 10
```

### 3.8 Web Deployment

```yaml
# k8s/base/web-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: agent-marketplace
spec:
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
      name: http
  selector:
    app: web
  type: ClusterIP

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: agent-marketplace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v1
    spec:
      containers:
        - name: web
          image: registry.ju/agent-marketplace-web:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: NODE_ENV
              value: "production"
            - name: NEXT_PUBLIC_API_URL
              value: "http://api.agent-marketplace.svc.cluster.local:3001"
            - name: NEXT_PUBLIC_CHAIN_ID
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CHAIN_ID
            - name: NEXT_PUBLIC_CONTRACT_ADDRESSES
              valueFrom:
                configMapKeyRef:
                  name: agent-marketplace-config
                  key: CONTRACT_ADDRESSES
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
```

### 3.9 HTTPRoute (Envoy Gateway)

```yaml
# k8s/base/httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: agent-marketplace-api
  namespace: agent-marketplace
spec:
  parentRefs:
    - name: gateway
      namespace: envoy-gateway
  hostnames:
    - "api.agent-marketplace.ju"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: api
          port: 3001

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: agent-marketplace-web
  namespace: agent-marketplace
spec:
  parentRefs:
    - name: gateway
      namespace: envoy-gateway
  hostnames:
    - "app.agent-marketplace.ju"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web
          port: 3000
```

### 3.10 Kustomization

```yaml
# k8s/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: agent-marketplace

resources:
  - ../../base/namespace.yaml
  - ../../base/configmap.yaml
  - ../../base/secret.yaml
  - ../../base/postgres-statefulset.yaml
  - ../../base/redis-deployment.yaml
  - ../../base/api-deployment.yaml
  - ../../base/indexer-deployment.yaml
  - ../../base/web-deployment.yaml
  - ../../base/httproute.yaml

images:
  - name: agent-marketplace-api
    newName: registry.ju/agent-marketplace-api
    newTag: dev
  - name: agent-marketplace-indexer
    newName: registry.ju/agent-marketplace-indexer
    newTag: dev
  - name: agent-marketplace-web
    newName: registry.ju/agent-marketplace-web
    newTag: dev

configMapGenerator:
  - name: agent-marketplace-config
    behavior: merge
    envs:
      - .env.development
```

---

## 4. GitHub Actions CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: registry.ju
  IMAGE_NAME_API: agent-marketplace-api
  IMAGE_NAME_INDEXER: agent-marketplace-indexer
  IMAGE_NAME_WEB: agent-marketplace-web

jobs:
  # ===========================================
  # Contract Tests
  # ===========================================
  contract-tests:
    name: Smart Contract Tests
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: contracts

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: contracts/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Compile contracts
        run: npx hardhat compile

      - name: Run contract tests
        run: npx hardhat test

      - name: Generate coverage report
        run: npx hardhat coverage
        continue-on-error: true

      - name: Upload coverage report
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          directory: ./contracts
        continue-on-error: true

  # ===========================================
  # API Tests
  # ===========================================
  api-tests:
    name: API Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    defaults:
      run:
        working-directory: api

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: api/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Setup database schema
        run: |
          npx prisma generate
          npx prisma db push
        env:
          DATABASE_URL: postgresql://test_user:test_password@localhost:5432/test_db

      - name: Run API tests
        run: npm test
        env:
          DATABASE_URL: postgresql://test_user:test_password@localhost:5432/test_db
          RPC_URL: ${{ secrets.RPC_URL }}
          CHAIN_ID: '84532'
          JWT_SECRET: test_jwt_secret

  # ===========================================
  # Build and Push API Image
  # ===========================================
  build-api:
    name: Build and Push API Image
    runs-on: ubuntu-latest
    needs: [contract-tests, api-tests]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_API }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push API
        uses: docker/build-push-action@v5
        with:
          context: ./api
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===========================================
  # Build and Push Indexer Image
  # ===========================================
  build-indexer:
    name: Build and Push Indexer Image
    runs-on: ubuntu-latest
    needs: [contract-tests, api-tests]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_INDEXER }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Indexer
        uses: docker/build-push-action@v5
        with:
          context: ./api
          file: ./api/Dockerfile.indexer
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===========================================
  # Build and Push Web Image
  # ===========================================
  build-web:
    name: Build and Push Web Image
    runs-on: ubuntu-latest
    needs: [contract-tests, api-tests]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_WEB }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Web
        uses: docker/build-push-action@v5
        with:
          context: ./web
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===========================================
  # ArgoCD Sync
  # ===========================================
  argocd-sync:
    name: ArgoCD Sync
    runs-on: ubuntu-latest
    needs: [build-api, build-indexer, build-web]
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install ArgoCD CLI
        run: |
          curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          chmod +x /usr/local/bin/argocd

      - name: Login to ArgoCD
        run: |
          argocd login ${{ secrets.ARGOCD_SERVER }} \
            --username ${{ secrets.ARGOCD_USERNAME }} \
            --password ${{ secrets.ARGOCD_PASSWORD }} \
            --insecure

      - name: Update image tags
        run: |
          IMAGE_TAG=$(echo ${{ github.sha }} | cut -c1-8)
          
          argocd app set agent-marketplace \
            --param api.image.tag=$IMAGE_TAG \
            --param indexer.image.tag=$IMAGE_TAG \
            --param web.image.tag=$IMAGE_TAG

      - name: Sync ArgoCD application
        run: |
          argocd app sync agent-marketplace \
            --timeout 300 \
            --prune \
            --dry-run=false

      - name: Wait for deployment
        run: |
          argocd app wait agent-marketplace \
            --timeout 300 \
            --health
```

---

## 5. Environment Variables

### 5.1 Root `.env.example`

```bash
# ===========================================
# Blockchain / Smart Contracts
# ===========================================
CHAIN_ID=84532
RPC_URL=https://sepolia.base.org
ALCHEMY_API_KEY=your_alchemy_api_key_here
PRIVATE_KEY=your_private_key_here

# Contract Addresses (after deployment)
AGENT_NFT_ADDRESS=0x...
MISSION_REGISTRY_ADDRESS=0x...
MARKETPLACE_ADDRESS=0x...

# ===========================================
# Database
# ===========================================
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=agent_marketplace
DATABASE_USERNAME=agent_marketplace
DATABASE_PASSWORD=change_me_in_production

# ===========================================
# Redis
# ===========================================
REDIS_HOST=localhost
REDIS_PORT=6379

# ===========================================
# API Configuration
# ===========================================
NODE_ENV=development
API_PORT=3001
INDEXER_PORT=3002

# JWT
JWT_SECRET=change_me_use_64_char_random_string
JWT_EXPIRES_IN=7d

# ===========================================
# Frontend
# ===========================================
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_CONTRACT_ADDRESSES={}
```

### 5.2 Contracts `.env.example`

```bash
# Hardhat / Local Development
CHAIN_ID=31337
RPC_URL=http://localhost:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deployer Account (first Hardhat account)
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Base Sepolia
SEPOLIA_RPC_URL=https://sepolia.base.org
SEPOLIA_PRIVATE_KEY=your_sepolia_private_key
BASESCAN_API_KEY=your_basescan_api_key
```

### 5.3 API `.env.example`

```bash
# Server
NODE_ENV=development
PORT=3001

# Database
DATABASE_URL=postgresql://agent_marketplace:dev_password@localhost:5432/agent_marketplace_dev

# Redis
REDIS_URL=redis://localhost:6379

# Blockchain
RPC_URL=http://localhost:8545
CHAIN_ID=31337
CONTRACT_ADDRESSES='{"agentNFT":"0x...","missionRegistry":"0x...","marketplace":"0x..."}'

# Authentication
JWT_SECRET=dev_jwt_secret_change_in_production

# Indexer
INDEXER_START_BLOCK=0
```

### 5.4 Web `.env.example`

```bash
# API
NEXT_PUBLIC_API_URL=http://localhost:3001

# Blockchain
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_CONTRACT_ADDRESSES='{"agentNFT":"0x...","missionRegistry":"0x...","marketplace":"0x..."}'

# Wallet Connect
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_project_id
```

### 5.5 Kubernetes Development Overlay `.env.development`

```bash
NODE_ENV=production
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532
DATABASE_HOST=postgres.agent-marketplace.svc.cluster.local
DATABASE_PORT=5432
DATABASE_NAME=agent_marketplace
REDIS_HOST=redis.agent-marketplace.svc.cluster.local
REDIS_PORT=6379
```

---

## 6. Local Development Setup Script

```bash
#!/bin/bash

# ===========================================
# Agent Marketplace - Local Development Setup
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Agent Marketplace - Local Setup${NC}"
echo -e "${BLUE}======================================${NC}"

# ===========================================
# Check Prerequisites
# ===========================================
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Docker Compose is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo -e "${RED}npm is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Check Docker daemon is running
docker info >/dev/null 2>&1 || { echo -e "${RED}Docker daemon is not running. Please start Docker.${NC}" >&2; exit 1; }

echo -e "${GREEN}All prerequisites satisfied.${NC}"

# ===========================================
# Install Dependencies
# ===========================================
echo -e "\n${YELLOW}Installing dependencies...${NC}"

# Install contracts dependencies
echo -e "${BLUE}Installing contracts dependencies...${NC}"
cd contracts
npm install
cd ..

# Install API dependencies
echo -e "${BLUE}Installing API dependencies...${NC}"
cd api
npm install
cd ..

# Install web dependencies
echo -e "${BLUE}Installing web dependencies...${NC}"
cd web
npm install
cd ..

echo -e "${GREEN}Dependencies installed.${NC}"

# ===========================================
# Start Docker Compose
# ===========================================
echo -e "\n${YELLOW}Starting Docker Compose services...${NC}"

docker-compose up -d postgres redis hardhat

# Wait for services to be healthy
echo -e "${BLUE}Waiting for services to be ready...${NC}"

# Wait for PostgreSQL
echo -e "${BLUE}Waiting for PostgreSQL...${NC}"
until docker-compose exec -T postgres pg_isready -U agent_marketplace >/dev/null 2>&1; do
  sleep 2
done
echo -e "${GREEN}PostgreSQL is ready.${NC}"

# Wait for Hardhat
echo -e "${BLUE}Waiting for Hardhat node...${NC}"
until curl -s http://localhost:8545 >/dev/null 2>&1; do
  sleep 2
done
echo -e "${GREEN}Hardhat node is ready.${NC}"

# ===========================================
# Deploy Smart Contracts
# ===========================================
echo -e "\n${YELLOW}Deploying smart contracts to local Hardhat node...${NC}"

cd contracts

# Deploy contracts
DEPLOY_OUTPUT=$(npx hardhat run scripts/deploy.ts --network localhost 2>&1)

# Extract contract addresses from output
AGENT_NFT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'AgentNFT:\s*\K0x[a-fA-F0-9]{40}' || echo "")
MISSION_REGISTRY_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'MissionRegistry:\s*\K0x[a-fA-F0-9]{40}' || echo "")
MARKETPLACE_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Marketplace:\s*\K0x[a-fA-F0-9]{40}' || echo "")

# Save contract addresses to a temp file for later use
cat > .contract-addresses.json << EOF
{
  "agentNFT": "$AGENT_NIT_ADDRESS",
  "missionRegistry": "$MISSION_REGISTRY_ADDRESS",
  "marketplace": "$MARKETPLACE_ADDRESS"
}
EOF

echo -e "${GREEN}Contracts deployed:${NC}"
echo -e "  AgentNFT: ${AGENT_NFT_ADDRESS}"
echo -e "  MissionRegistry: ${MISSION_REGISTRY_ADDRESS}"
echo -e "  Marketplace: ${MARKETPLACE_ADDRESS}"

cd ..

# ===========================================
# Setup Database Schema
# ===========================================
echo -e "\n${YELLOW}Setting up database schema...${NC}"

cd api
npx prisma generate
npx prisma db push
cd ..

# ===========================================
# Seed Development Data
# ===========================================
echo -e "\n${YELLOW}Seeding development data...${NC}"

# Create seed data script output
cat > scripts/seed-dev-data.ts << 'EOF'
import { ethers } from 'hardhat';

async function main() {
  const [deployer, user1, user2, user3] = await ethers.getSigners();
  
  const agentNFT = await ethers.getContractAt('AgentNFT', process.env.AGENT_NFT_ADDRESS || '');
  const missionRegistry = await ethers.getContractAt('MissionRegistry', process.env.MISSION_REGISTRY_ADDRESS || '');
  
  // Create 3 agents
  const agents = [
    { name: 'Data Collector', description: 'Collects and processes data from various sources', price: ethers.parseEther('0.01') },
    { name: 'Analysis Agent', description: 'Performs statistical analysis and generates insights', price: ethers.parseEther('0.02') },
    { name: 'Notification Agent', description: 'Sends notifications across multiple channels', price: ethers.parseEther('0.005') },
  ];
  
  console.log('\n=== Creating Agents ===');
  for (const agent of agents) {
    const tx = await agentNFT.mintAgent(agent.name, agent.description, agent.price);
    await tx.wait();
    console.log(`Created agent: ${agent.name}`);
  }
  
  // Create 5 missions
  const missions = [
    { agentId: 1, description: 'Collect weather data for Paris', reward: ethers.parseEther('0.005'), duration: 3600 },
    { agentId: 1, description: 'Aggregate crypto prices from exchanges', reward: ethers.parseEther('0.01'), duration: 1800 },
    { agentId: 2, description: 'Analyze sales data for Q4', reward: ethers.parseEther('0.015'), duration: 7200 },
    { agentId: 3, description: 'Send daily digest to team', reward: ethers.parseEther('0.003'), duration: 900 },
    { agentId: 2, description: 'Generate monthly report', reward: ethers.parseEther('0.02'), duration: 10800 },
  ];
  
  console.log('\n=== Creating Missions ===');
  for (const mission of missions) {
    const tx = await missionRegistry.createMission(
      mission.agentId,
      mission.description,
      mission.reward,
      mission.duration
    );
    await tx.wait();
    console.log(`Created mission: ${mission.description}`);
  }
  
  console.log('\n=== Seed Data Complete ===');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOF

cd contracts
export AGENT_NFT_ADDRESS="$AGENT_NFT_ADDRESS"
export MISSION_REGISTRY_ADDRESS="$MISSION_REGISTRY_ADDRESS"
npx hardhat run ../scripts/seed-dev-data.ts --network localhost 2>/dev/null || true
cd ..

echo -e "${GREEN}Development data seeded.${NC}"

# ===========================================
# Start API and Indexer Services
# ===========================================
echo -e "\n${YELLOW}Starting API and Indexer services...${NC}"

# Set environment variables for services
export DATABASE_URL="postgresql://agent_marketplace:dev_password@localhost:5432/agent_marketplace_dev"
export REDIS_URL="redis://localhost:6379"
export RPC_URL="http://localhost:8545"
export CHAIN_ID="31337"
export CONTRACT_ADDRESSES="{\"agentNFT\":\"$AGENT_NIT_ADDRESS\",\"missionRegistry\":\"$MISSION_REGISTRY_ADDRESS\",\"marketplace\":\"$MARKETPLACE_ADDRESS\"}"

docker-compose up -d api indexer

# Wait for API to be ready
echo -e "${BLUE}Waiting for API...${NC}"
until curl -s http://localhost:3001/health >/dev/null 2>&1; do
  sleep 2
done
echo -e "${GREEN}API is ready.${NC}"

# ===========================================
# Start Frontend
# ===========================================
echo -e "\n${YELLOW}Starting Frontend...${NC}"

docker-compose up -d web

# Wait for frontend to be ready
echo -e "${BLUE}Waiting for Frontend...${NC}"
until curl -s http://localhost:3000 >/dev/null 2>&1; do
  sleep 2
done
echo -e "${GREEN}Frontend is ready.${NC}"

# ===========================================
# Summary
# ===========================================
echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}Local Development Environment Ready!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo -e "  - PostgreSQL:   ${GREEN}localhost:5432${NC}"
echo -e "  - Redis:        ${GREEN}localhost:6379${NC}"
echo -e "  - Hardhat:      ${GREEN}localhost:8545${NC}"
echo -e "  - API:          ${GREEN}http://localhost:3001${NC}"
echo -e "  - Indexer:      ${GREEN}http://localhost:3002${NC}"
echo -e "  - Frontend:     ${GREEN}http://localhost:3000${NC}"
echo ""
echo -e "${BLUE}Contract Addresses:${NC}"
echo -e "  - AgentNFT:         $AGENT_NIT_ADDRESS"
echo -e "  - MissionRegistry: $MISSION_REGISTRY_ADDRESS"
echo -e "  - Marketplace:     $MARKETPLACE_ADDRESS"
echo ""
echo -e "${YELLOW}To stop all services:${NC}"
echo -e "  docker-compose down"
echo ""
echo -e "${YELLOW}To view logs:${NC}"
echo -e "  docker-compose logs -f [service_name]"
echo ""
```

---

## 7. Quick Reference Commands

### Development
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Reset database
docker-compose exec postgres psql -U agent_marketplace -c "DROP DATABASE agent_marketplace_dev;"
docker-compose exec postgres psql -U agent_marketplace -c "CREATE DATABASE agent_marketplace_dev;"
cd api && npx prisma db push
```

### Kubernetes (k3s)
```bash
# Apply manifests
kubectl apply -k k8s/overlays/development

# Check status
kubectl get all -n agent-marketplace

# View logs
kubectl logs -n agent-marketplace -l app=api -f
kubectl logs -n agent-marketplace -l app=indexer -f
kubectl logs -n agent-marketplace -l app=web -f

# Restart deployment
kubectl rollout restart deployment/api -n agent-marketplace
kubectl rollout restart deployment/indexer -n agent-marketplace
kubectl rollout restart deployment/web -n agent-marketplace
```

### ArgoCD
```bash
# Login
argocd login registry.ju --username admin

# Sync manually
argocd app sync agent-marketplace

# Check status
argocd app get agent-marketplace
```

---

*Infrastructure spec complete.*
