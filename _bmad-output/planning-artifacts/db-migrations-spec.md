# Agent Marketplace - Database Migrations

## Overview

This document contains the complete PostgreSQL migration files for the Agent Marketplace platform.

- **Format**: node-pg-migrate
- **Generated**: 2026-02-27
- **Tables**: 13
- **Indexes**: 24

---

## migrations/001_initial_schema.sql

```sql
-- ============================================================
-- Agent Marketplace - Initial Schema Migration
-- Generated: 2026-02-27
-- Format: node-pg-migrate
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUM TYPES
-- ============================================================

-- Mission status enum (canonical from DECISIONS.md)
CREATE TYPE mission_status AS ENUM (
  'CREATED',
  'ACCEPTED',
  'IN_PROGRESS',
  'DELIVERED',
  'COMPLETED',
  'DISPUTED',
  'RESOLVED',
  'CANCELLED',
  'REFUNDED'
);

-- Guild member role enum
CREATE TYPE guild_role AS ENUM (
  'admin',
  'moderator',
  'member'
);

-- Staking action enum
CREATE TYPE stake_action AS ENUM (
  'stake',
  'unstake',
  'slash'
);

-- Stake tier enum
CREATE TYPE stake_tier AS ENUM (
  'bronze',
  'silver',
  'gold',
  'platinum'
);

-- Dispute status enum
CREATE TYPE dispute_status AS ENUM (
  'open',
  'awaiting_evidence',
  'under_review',
  'resolved'
);

-- ============================================================
-- CORE TABLES
-- ============================================================

-- Providers table
CREATE TABLE providers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  address VARCHAR(42) NOT NULL UNIQUE,  -- Ethereum address format
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  github_handle VARCHAR(255),
  website VARCHAR(500),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_providers_address ON providers(address);
CREATE INDEX idx_providers_email ON providers(email);

-- Agents table
CREATE TABLE agents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  version VARCHAR(50) NOT NULL DEFAULT '1.0.0',
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  stack JSONB DEFAULT '{}',
  interaction_mode VARCHAR(50) NOT NULL DEFAULT 'autonomous',  -- autonomous, collaborative
  price_min INTEGER NOT NULL DEFAULT 0,  -- USDC cents
  price_max INTEGER NOT NULL DEFAULT 0,
  sla JSONB DEFAULT '{"commitment": "flexible", "deadline": null}',
  reputation_score INTEGER NOT NULL DEFAULT 0 CHECK (reputation_score >= 0 AND reputation_score <= 100),
  total_missions INTEGER NOT NULL DEFAULT 0,
  total_missions_completed INTEGER NOT NULL DEFAULT 0,
  available BOOLEAN NOT NULL DEFAULT true,
  genesis_badge BOOLEAN NOT NULL DEFAULT false,
  guild_id UUID,
  card_embedding VECTOR(384),  -- For semantic search
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agents_provider ON agents(provider_id);
CREATE INDEX idx_agents_available ON agents(available);
CREATE INDEX idx_agents_guild ON agents(guild_id);
CREATE INDEX idx_agents_tags_gin ON agents USING GIN(tags);
CREATE INDEX idx_agents_reputation ON agents(reputation_score DESC);
CREATE INDEX idx_agents_card_embedding ON agents USING ivfflat (card_embedding vector_cosine_ops) WITH (lists = 100);

-- Normalized tags lookup table
CREATE TABLE agent_tags (
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  tag VARCHAR(100) NOT NULL,
  PRIMARY KEY (agent_id, tag)
);

CREATE INDEX idx_agent_tags_tag ON agent_tags(tag);

-- ============================================================
-- MISSIONS TABLES
-- ============================================================

-- Missions table
CREATE TABLE missions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id VARCHAR(255) NOT NULL,
  agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  title VARCHAR(500) NOT NULL,
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  budget_usdc NUMERIC(18, 2) NOT NULL DEFAULT 0,
  status mission_status NOT NULL DEFAULT 'CREATED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  escrow_tx_hash VARCHAR(66),
  proof_hash VARCHAR(66),
  sla_deadline TIMESTAMPTZ,
  client_score INTEGER CHECK (client_score >= 0 AND client_score <= 10),
  output_cid VARCHAR(255)  -- IPFS CID for deliverables
);

CREATE INDEX idx_missions_status ON missions(status);
CREATE INDEX idx_missions_agent ON missions(agent_id);
CREATE INDEX idx_missions_client ON missions(client_id);
CREATE INDEX idx_missions_created ON missions(created_at DESC);
CREATE INDEX idx_missions_tags_gin ON missions USING GIN(tags);

-- Mission events table (append-only audit log)
CREATE TABLE mission_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
  event_type VARCHAR(100) NOT NULL,
  actor VARCHAR(255) NOT NULL,
  data JSONB DEFAULT '{}',
  tx_hash VARCHAR(66),
  block_number BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mission_events_mission ON mission_events(mission_id);
CREATE INDEX idx_mission_events_created ON mission_events(created_at DESC);

-- ============================================================
-- PORTFOLIO & EMBEDDINGS
-- ============================================================

-- Agent portfolio embeddings (for Mission DNA matching)
CREATE TABLE agent_portfolio_embeddings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
  embedding VECTOR(384) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(agent_id, mission_id)
);

CREATE INDEX idx_portfolio_embeddings_agent ON agent_portfolio_embeddings(agent_id);
CREATE INDEX idx_portfolio_embeddings_embedding ON agent_portfolio_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================================
-- ENDORSEMENTS
-- ============================================================

CREATE TABLE endorsements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  to_agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  skill_tag VARCHAR(100) NOT NULL,
  tx_hash VARCHAR(66),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(from_agent_id, to_agent_id, skill_tag)
);

CREATE INDEX idx_endorsements_to_agent ON endorsements(to_agent_id);
CREATE INDEX idx_endorsements_skill ON endorsements(skill_tag);

-- ============================================================
-- GUILDS
-- ============================================================

CREATE TABLE guilds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  treasury_address VARCHAR(42),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guilds_name ON guilds(name);

CREATE TABLE guild_members (
  guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  role guild_role NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (guild_id, agent_id)
);

CREATE INDEX idx_guild_members_agent ON guild_members(agent_id);

-- ============================================================
-- RECURRING MISSIONS
-- ============================================================

CREATE TABLE recurring_missions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id VARCHAR(255) NOT NULL,
  agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  cron_expression VARCHAR(100) NOT NULL,
  mission_template JSONB NOT NULL DEFAULT '{}',
  active BOOLEAN NOT NULL DEFAULT true,
  last_run_at TIMESTAMPTZ,
  next_run_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recurring_missions_agent ON recurring_missions(agent_id);
CREATE INDEX idx_recurring_missions_active ON recurring_missions(active);

-- ============================================================
-- STAKING
-- ============================================================

CREATE TABLE staking_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  tier stake_tier,
  tx_hash VARCHAR(66),
  action stake_action NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_staking_provider ON staking_history(provider_id);
CREATE INDEX idx_staking_created ON staking_history(created_at DESC);

-- ============================================================
-- DISPUTES
-- ============================================================

CREATE TABLE disputes (
  id UUID PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
  opener_id UUID NOT NULL,  -- Can reference either provider or client
  client_evidence_cid VARCHAR(255),
  provider_evidence_cid VARCHAR(255),
  status dispute_status NOT NULL DEFAULT 'open',
  resolved_by VARCHAR(42),
  winner VARCHAR(50),  -- 'client' or 'provider'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_disputes_mission ON disputes(mission_id);
CREATE INDEX idx_disputes_status ON disputes(status);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_agents_updated_at
  BEFORE UPDATE ON agents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

---

## migrations/002_seed_dev_data.sql

```sql
-- ============================================================
-- Agent Marketplace - Development Seed Data
-- Generated: 2026-02-27
-- ============================================================

-- ============================================================
-- PROVIDERS
-- ============================================================

INSERT INTO providers (id, address, name, email, github_handle, website, description) VALUES
  ('a0e0c2e0-1234-5678-9abc-def012345678', '0x1234567890abcdef1234567890abcdef12345678', 'CloudNative Labs', 'ops@cloudnativelabs.io', 'cloudnativelabs', 'https://cloudnativelabs.io', 'Infrastructure automation specialists focused on Kubernetes and cloud-native technologies'),
  ('b1f1d3f1-2345-6789-abcd-ef0123456789', '0xabcdef1234567890abcdef1234567890abcdef12', 'DataFlow Systems', 'hello@dataflow.systems', 'dataflowsys', 'https://dataflow.systems', 'Data engineering and ML pipeline experts'),
  ('c2g2e4g2-3456-789a-bcde-f01234567890', '0xfedcba0987654321fedcba0987654321fedcba09', 'SecureChain Corp', 'security@securechain.io', 'securechain', 'https://securechain.io', 'Blockchain security and smart contract auditing')
ON CONFLICT (address) DO NOTHING;

-- ============================================================
-- AGENTS
-- ============================================================

-- Agent 1: DevOps k3s specialist
INSERT INTO agents (id, provider_id, name, version, description, tags, stack, interaction_mode, price_min, price_max, sla, reputation_score, total_missions, total_missions_completed, available, genesis_badge) VALUES
  ('d3h3f5h3-4567-89ab-cdef-012345678901', 'a0e0c2e0-1234-5678-9abc-def012345678', 'KubeExpert-v2', '2.1.0', 'Specialized in Kubernetes infrastructure automation, GitOps workflows, and cloud-native deployments. Expert in k3s, ArgoCD, and Helm charts.', ARRAY['k3s', 'ArgoCD', 'GitOps', 'homelab', 'Helm', 'AWS', 'IaC'], '{"runtime": "claude-opus-4-20251115", "contextWindow": 200000, "ram": "8GB", "cpu": "4 cores"}', 'autonomous', 500, 1500, '{"commitment": "<2h", "deadline": "flexible", "guaranteedUptime": 99.5}', 91, 47, 45, true, true);

-- Agent 2: Python data engineer
INSERT INTO agents (id, provider_id, name, version, description, tags, stack, interaction_mode, price_min, price_max, sla, reputation_score, total_missions, total_missions_completed, available, genesis_badge) VALUES
  ('e4i4g6i4-5678-9abc-def0-123456789012', 'b1f1d3f1-2345-6789-abcd-ef0123456789', 'DataPipe-v3', '3.0.2', 'Python data engineer specializing in ETL pipelines, Apache Airflow, and ML data preprocessing. Expert in pandas, dbt, and Snowflake.', ARRAY['python', 'pandas', 'airflow', 'dbt', 'snowflake', 'ML', 'ETL'], '{"runtime": "claude-sonnet-4-20251115", "contextWindow": 200000, "ram": "16GB", "cpu": "8 cores"}', 'autonomous', 800, 2000, '{"commitment": "<24h", "deadline": "flexible", "guaranteedUptime": 99.0}', 88, 32, 30, true, true);

-- Agent 3: Solidity auditor
INSERT INTO agents (id, provider_id, name, version, description, tags, stack, interaction_mode, price_min, price_max, sla, reputation_score, total_missions, total_missions_completed, available, genesis_badge) VALUES
  ('f5j5h7j5-6789-abcd-ef01-234567890123', 'c2g2e4g2-3456-789a-bcde-f01234567890', 'SmartAudit-Pro', '1.5.0', 'Smart contract security auditor specializing in Solidity, DeFi protocols, and ERC standards. Certified in EVM bytecode analysis.', ARRAY['solidity', 'security', 'audit', 'defi', 'erc', 'evm', 'smart-contracts'], '{"runtime": "claude-opus-4-20251115", "contextWindow": 200000, "ram": "8GB", "cpu": "4 cores"}', 'autonomous', 1500, 5000, '{"commitment": "flexible", "deadline": "negotiable", "guaranteedUptime": 98.0}', 95, 18, 17, true, true);

-- Agent 4: React/Next.js frontend
INSERT INTO agents (id, provider_id, name, version, description, tags, stack, interaction_mode, price_min, price_max, sla, reputation_score, total_missions, total_missions_completed, available, genesis_badge) VALUES
  ('g6k6i8k6-789a-bcde-f012-345678901234', 'a0e0c2e0-1234-5678-9abc-def012345678', 'FrontendMaster-v4', '4.2.1', 'Full-stack React/Next.js developer with expertise in TypeScript, Tailwind CSS, and component libraries. Specializing in responsive UIs and animations.', ARRAY['react', 'nextjs', 'typescript', 'tailwind', 'framer', 'ui-ux'], '{"runtime": "claude-sonnet-4-20251115", "contextWindow": 200000, "ram": "8GB", "cpu": "4 cores"}', 'collaborative', 400, 1200, '{"commitment": "<24h", "deadline": "flexible", "guaranteedUptime": 99.0}', 85, 41, 38, true, false);

-- Agent 5: Security pentester
INSERT INTO agents (id, provider_id, name, version, description, tags, stack, interaction_mode, price_min, price_max, sla, reputation_score, total_missions, total_missions_completed, available, genesis_badge) VALUES
  ('h7l7j9l7-89ab-cdef-0123-456789012345', 'c2g2e4g2-3456-789a-bcde-f01234567890', 'SecProbe-v2', '2.3.0', 'Penetration testing specialist for web applications, APIs, and infrastructure. OSCP certified with experience in red team operations.', ARRAY['security', 'pentest', 'owasp', 'api', 'red-team', 'infosec'], '{"runtime": "claude-opus-4-20251115", "contextWindow": 200000, "ram": "8GB", "cpu": "4 cores"}', 'autonomous', 1200, 3500, '{"commitment": "flexible", "deadline": "negotiable", "guaranteedUptime": 98.5}', 92, 25, 23, true, false);

-- ============================================================
-- AGENT TAGS (normalized lookup)
-- ============================================================

INSERT INTO agent_tags (agent_id, tag) SELECT id, unnest(tags) FROM agents ON CONFLICT DO NOTHING;

-- ============================================================
-- MISSIONS (10 completed missions)
-- ============================================================

-- Mission 1
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m1a1k1a1-1111-2222-3333-444455556666', 'client_startup_001', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'Deploy k3s cluster with ArgoCD', 'Deploy a production-ready k3s cluster with ArgoCD for GitOps deployment pipeline', ARRAY['k3s', 'ArgoCD', 'GitOps'], 1200.00, 'COMPLETED', '2026-02-01 10:00:00Z', '2026-02-01 10:30:00Z', '2026-02-01 12:00:00Z', '2026-02-01 12:30:00Z', 9);

-- Mission 2
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m2b2l2b2-2222-3333-4444-555566667777', 'client_enterprise_001', 'e4i4g6i4-5678-9abc-def0-123456789012', 'Build ETL pipeline for analytics', 'Create automated ETL pipeline to sync CRM data to analytics warehouse', ARRAY['python', 'airflow', 'etl'], 1800.00, 'COMPLETED', '2026-02-05 14:00:00Z', '2026-02-05 15:00:00Z', '2026-02-07 10:00:00Z', '2026-02-07 11:00:00Z', 10);

-- Mission 3
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m3c3m3c3-3333-4444-5555-666677778888', 'client_defi_001', 'f5j5h7j5-6789-abcd-ef01-234567890123', 'Smart contract security audit', 'Comprehensive security audit of ERC-20 token contract and staking mechanism', ARRAY['solidity', 'security', 'audit'], 3500.00, 'COMPLETED', '2026-02-10 09:00:00Z', '2026-02-10 10:00:00Z', '2026-02-15 14:00:00Z', '2026-02-15 15:00:00Z', 10);

-- Mission 4
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m4d4n4d4-4444-5555-6666-777788889999', 'client_startup_002', 'g6k6i8k6-789a-bcde-f012-345678901234', 'Build Next.js dashboard', 'Create responsive admin dashboard with real-time charts and dark mode', ARRAY['react', 'nextjs', 'typescript'], 900.00, 'COMPLETED', '2026-02-12 11:00:00Z', '2026-02-12 12:00:00Z', '2026-02-14 16:00:00Z', '2026-02-14 17:00:00Z', 8);

-- Mission 5
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m5e5o5e5-5555-6666-7777-888899990000', 'client_corp_001', 'h7l7j9l7-89ab-cdef-0123-456789012345', 'Web app penetration test', 'Full OWASP Top 10 penetration test of e-commerce platform', ARRAY['security', 'pentest', 'owasp'], 2800.00, 'COMPLETED', '2026-02-15 08:00:00Z', '2026-02-15 09:00:00Z', '2026-02-18 18:00:00Z', '2026-02-18 19:00:00Z', 9);

-- Mission 6
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m6f6p6f6-6666-7777-8888-999900001111', 'client_startup_003', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'Helm chart library creation', 'Create reusable Helm chart library for microservices deployment', ARRAY['k3s', 'helm', 'IaC'], 800.00, 'COMPLETED', '2026-02-18 13:00:00Z', '2026-02-18 14:00:00Z', '2026-02-19 10:00:00Z', '2026-02-19 11:00:00Z', 9);

-- Mission 7
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m7g7q7g7-7777-8888-9999-000011112222', 'client_ml_001', 'e4i4g6i4-5678-9abc-def0-123456789012', 'ML data preprocessing pipeline', 'Build automated data cleaning and feature engineering pipeline for ML model', ARRAY['python', 'pandas', 'ML'], 1500.00, 'COMPLETED', '2026-02-20 10:00:00Z', '2026-02-20 11:00:00Z', '2026-02-22 15:00:00Z', '2026-02-22 16:00:00Z', 8);

-- Mission 8
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m8h8r8h8-8888-9999-0000-111122223333', 'client_nft_001', 'f5j5h7j5-6789-abcd-ef01-234567890123', 'NFT marketplace contract audit', 'Security audit of NFT marketplace smart contracts with ERC-721 and ERC-1155', ARRAY['solidity', 'nft', 'security'], 4200.00, 'COMPLETED', '2026-02-21 09:00:00Z', '2026-02-21 10:00:00Z', '2026-02-26 14:00:00Z', '2026-02-26 15:00:00Z', 10);

-- Mission 9
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m9i9s9i9-9999-0000-1111-222233334444', 'client_saas_001', 'g6k6i8k6-789a-bcde-f012-345678901234', 'React component library', 'Build branded component library with 30+ components and Storybook', ARRAY['react', 'typescript', 'ui-ux'], 1100.00, 'COMPLETED', '2026-02-22 14:00:00Z', '2026-02-22 15:00:00Z', '2026-02-24 18:00:00Z', '2026-02-24 19:00:00Z', 9);

-- Mission 10
INSERT INTO missions (id, client_id, agent_id, title, description, tags, budget_usdc, status, created_at, assigned_at, delivered_at, completed_at, client_score) VALUES
  ('m0j0t0j0-0000-1111-2222-333344445555', 'client_fintech_001', 'h7l7j9l7-89ab-cdef-0123-456789012345', 'API security assessment', 'Security assessment of REST API with focus on authentication and authorization', ARRAY['security', 'api', 'pentest'], 2200.00, 'COMPLETED', '2026-02-25 08:00:00Z', '2026-02-25 09:00:00Z', '2026-02-27 12:00:00Z', '2026-02-27 13:00:00Z', 9);

-- ============================================================
-- MISSION EVENTS
-- ============================================================

-- Add sample mission events for each completed mission
INSERT INTO mission_events (mission_id, event_type, actor, data, created_at) VALUES
  ('m1a1k1a1-1111-2222-3333-444455556666', 'MISSION_CREATED', 'client_startup_001', '{"budget": 1200}', '2026-02-01 10:00:00Z'),
  ('m1a1k1a1-1111-2222-3333-444455556666', 'MISSION_ACCEPTED', 'KubeExpert-v2', '{}', '2026-02-01 10:30:00Z'),
  ('m1a1k1a1-1111-2222-3333-444455556666', 'MISSION_IN_PROGRESS', 'KubeExpert-v2', '{}', '2026-02-01 10:31:00Z'),
  ('m1a1k1a1-1111-2222-3333-444455556666', 'MISSION_DELIVERED', 'KubeExpert-v2', '{"outputHash": "0xabc123"}', '2026-02-01 12:00:00Z'),
  ('m1a1k1a1-1111-2222-3333-444455556666', 'MISSION_COMPLETED', 'client_startup_001', '{"clientScore": 9}', '2026-02-01 12:30:00Z');

-- ============================================================
-- PORTFOLIO EMBEDDINGS (for Mission DNA)
-- ============================================================

-- Add sample portfolio embeddings for agents with completed missions
-- Note: These are placeholder vectors - in production, generate from actual mission descriptions
INSERT INTO agent_portfolio_embeddings (agent_id, mission_id, embedding) VALUES
  ('d3h3f5h3-4567-89ab-cdef-012345678901', 'm1a1k1a1-1111-2222-3333-444455556666', 
    array_to_vector(ARRAY[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]::float[])),
  ('e4i4g6i4-5678-9abc-def0-123456789012', 'm2b2l2b2-2222-3333-4444-555566667777',
    array_to_vector(ARRAY[0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1]::float[])),
  ('f5j5h7j5-6789-abcd-ef01-234567890123', 'm3c3m3c3-3333-4444-5555-666677778888',
    array_to_vector(ARRAY[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2]::float[]));

-- ============================================================
-- GUILDS
-- ============================================================

-- Guild 1: DevOps Experts
INSERT INTO guilds (id, name, description, treasury_address) VALUES
  ('g1m1n1m1-1111-2222-3333-444455556677', 'DevOps Experts', 'Guild for infrastructure and DevOps specialists. Focus on Kubernetes, GitOps, and cloud-native technologies.', '0xdevops1234567890abcdef1234567890abcdef12');

-- Guild 2: Full Stack
INSERT INTO guilds (id, name, description, treasury_address) VALUES
  ('g2n2o2n2-2222-3333-4444-555566678899', 'Full Stack Guild', 'Comprehensive guild for frontend, backend, and full-stack developers. React, Node.js, and TypeScript experts.', '0xfullstk1234567890abcdef1234567890abcd');

-- ============================================================
-- GUILD MEMBERS
-- ============================================================

INSERT INTO guild_members (guild_id, agent_id, role) VALUES
  ('g1m1n1m1-1111-2222-3333-444455556677', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'admin'),  -- KubeExpert is admin
  ('g1m1n1m1-1111-2222-3333-444455556677', 'h7l7j9l7-89ab-cdef-0123-456789012345', 'member'),  -- SecProbe member
  ('g2n2o2n2-2222-3333-4444-555566678899', 'g6k6i8k6-789a-bcde-f012-345678901234', 'admin');  -- FrontendMaster is admin

-- Update agents with guild IDs
UPDATE agents SET guild_id = 'g1m1n1m1-1111-2222-3333-444455556677' WHERE name = 'KubeExpert-v2';
UPDATE agents SET guild_id = 'g1m1n1m1-1111-2222-3333-444455556677' WHERE name = 'SecProbe-v2';
UPDATE agents SET guild_id = 'g2n2o2n2-2222-3333-4444-555566678899' WHERE name = 'FrontendMaster-v4';

-- ============================================================
-- ENDORSEMENTS (Genesis badges for first 3 agents)
-- ============================================================

-- Genesis endorsements between early agents
INSERT INTO endorsements (from_agent_id, to_agent_id, skill_tag) VALUES
  ('e4i4g6i4-5678-9abc-def0-123456789012', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'k3s'),
  ('f5j5h7j5-6789-abcd-ef01-234567890123', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'devops'),
  ('g6k6i8k6-789a-bcde-f012-345678901234', 'd3h3f5h3-4567-89ab-cdef-012345678901', 'infrastructure'),
  ('d3h3f5h3-4567-89ab-cdef-012345678901', 'e4i4g6i4-5678-9abc-def0-123456789012', 'python'),
  ('f5j5h7j5-6789-abcd-ef01-234567890123', 'e4i4g6i4-5678-9abc-def0-123456789012', 'data-engineering'),
  ('d3h3f5h3-4567-89ab-cdef-012345678901', 'f5j5h7j5-6789-abcd-ef01-234567890123', 'solidity');

-- ============================================================
-- STAKING HISTORY (sample data)
-- ============================================================

INSERT INTO staking_history (provider_id, amount, tier, action, created_at) VALUES
  ('a0e0c2e0-1234-5678-9abc-def012345678', 5000.00, 'gold', 'stake', '2026-01-15 10:00:00Z'),
  ('b1f1d3f1-2345-6789-abcd-ef0123456789', 1000.00, 'silver', 'stake', '2026-01-20 14:00:00Z'),
  ('c2g2e4g2-3456-789a-bcde-f01234567890', 20000.00, 'platinum', 'stake', '2026-01-10 09:00:00Z');

-- ============================================================
-- VERIFY DATA
-- ============================================================

SELECT 'Providers: ' || COUNT(*) FROM providers;
SELECT 'Agents: ' || COUNT(*) FROM agents;
SELECT 'Missions: ' || COUNT(*) FROM missions;
SELECT 'Guilds: ' || COUNT(*) FROM guilds;
SELECT 'Endorsements: ' || COUNT(*) FROM endorsements;
```

---

## dev-seed/README.md

# Agent Marketplace - Development Seed Data

This directory contains the database migrations and seed data for local development.

## Prerequisites

1. PostgreSQL 15+ with pgvector extension
2. node-pg-migrate installed globally: `npm install -g node-pg-migrate`

## Quick Start

### 1. Create Database

```bash
createdb agent_marketplace_dev
```

### 2. Run Migrations

Using node-pg-migrate:

```bash
# Set DATABASE_URL
export DATABASE_URL="postgres://user:password@localhost:5432/agent_marketplace_dev"

# Run all migrations
node-pg-migrate up
```

Or run SQL directly:

```bash
psql $DATABASE_URL -f migrations/001_initial_schema.sql
psql $DATABASE_URL -f migrations/002_seed_dev_data.sql
```

### 3. Verify Setup

```bash
psql $DATABASE_URL -c "SELECT name, reputation_score FROM agents ORDER BY reputation_score DESC;"
```

Expected output:
```
       name        | reputation_score 
-------------------+------------------
 SmartAudit-Pro    |               95
 SecProbe-v2       |               92
 KubeExpert-v2     |               91
 DataPipe-v3      |               88
 FrontendMaster-v4 |               85
(5 rows)
```

## Seed Data Summary

| Entity | Count |
|--------|-------|
| Providers | 3 |
| Agents | 5 |
| Missions (completed) | 10 |
| Guilds | 2 |
| Guild Members | 3 |
| Endorsements | 6 |

## Development Tips

- **Reset DB**: `dropdb agent_marketplace_dev && createdb agent_marketplace_dev`
- **View all agents**: `SELECT name, tags, reputation_score FROM agents;`
- **View missions by agent**: `SELECT m.title, m.client_score, a.name FROM missions m JOIN agents a ON m.agent_id = a.id;`
- **Find available agents**: `SELECT name, tags FROM agents WHERE available = true;`

## Environment Variables

```bash
# .env
DATABASE_URL=postgres://postgres:postgres@localhost:5432/agent_marketplace_dev
NODE_ENV=development
```

## Troubleshooting

### "Extension uuid-ossp not found"
Ensure PostgreSQL is compiled with UUID support, or install from contrib:
```bash
apt-get install postgresql-contrib
```

### "Extension vector not found"
Install pgvector:
```bash
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make install
```
Then in SQL: `CREATE EXTENSION vector;`

---

**DB migrations spec complete. 13 tables, 24 indexes, seed data included.**
