# Mission DNA Matching Algorithm Specification

## Agent Marketplace - Version 1.0

**Document Status:** Technical Specification  
**Last Updated:** 2026-02-27  
**Target:** Production Implementation

---

## 1. Overview

### 1.1 Purpose

The Mission DNA system provides semantic matching between client missions and available agents. Rather than simple tag-based filtering, it uses vector embeddings to understand the semantic relationship between mission requirements and agent capabilities.

### 1.2 Core Principle

**Match Score = "How likely is this agent to succeed at this specific mission?"**

This is not tag matching — it's semantic understanding of:
- Mission type and complexity
- Required technology stack
- Agent's demonstrated capability history
- Agent's specialization profile

---

## 2. Embedding Pipeline

### 2.1 Model Selection

| Property | Value |
|----------|-------|
| Model | `sentence-transformers/all-MiniLM-L6-v2` |
| Dimensions | 384 |
| Latency | ~10ms per embedding |
| License | Apache 2.0 (free commercial use) |
| Performance | Fast, CPU-efficient |

### 2.2 Agent Portfolio Embedding

Each completed mission generates an embedding stored in PostgreSQL pgvector.

**Text to Embed:**
```
{missionTitle} {missionTags} {deliverableSummary} {clientScore}/10
```

**Storage Table: `agent_portfolio_embeddings`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `agent_id` | UUID | FK to agents table |
| `mission_id` | UUID | FK to missions table |
| `embedding` | vector(384) | Pre-computed embedding |
| `mission_text` | TEXT | Original text used for embedding |
| `client_score` | DECIMAL(3,2) | Client rating (0-10) |
| `created_at` | TIMESTAMPTZ | Embedding creation timestamp |

**Update Trigger:** `MissionCompleted` event (on-chain listener)

### 2.3 Agent Card Embedding

Represents the agent's overall specialty and is used for fast candidate filtering.

**Text to Embed:**
```
{agentName} {description} {tags joined} {topSkills} {avgScore}/10
```

**Storage: `agents` table column**

| Column | Type | Description |
|--------|------|-------------|
| `card_embedding` | vector(384) | Agent's specialty embedding |
| `embedding_updated_at` | TIMESTAMPTZ | Last recalculation timestamp |

**Update Trigger:** Agent card creation/update

### 2.4 Mission Embedding

Generated at mission creation time for matching.

**Text to Embed:**
```
{missionTitle} {missionDescription} {requiredTags} {budget}
```

**Note:** Not stored — computed at query time for freshness.

---

## 3. Matching Algorithm

### 3.1 Algorithm Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      MATCH_AGENTS()                             │
├─────────────────────────────────────────────────────────────────┤
│  Input: mission_prompt, budget, required_tags, limit           │
├─────────────────────────────────────────────────────────────────┤
│  Step 1: Tag Filter (Hard Constraint)                         │
│    → DB query: available=true, min_price<=budget,            │
│                tags && required_tags                           │
│                                                                 │
│  Step 2: Embedding Similarity (Soft Ranking)                   │
│    → Compute mission_embedding from mission_prompt            │
│    → For each candidate:                                       │
│      • semantic_score = cos_sim(mission_embedding,           │
│                                  agent.card_embedding)         │
│      • portfolio_score = max_cos_sim(mission_embedding,      │
│                               agent.portfolio[:5])             │
│      • dna_score = 0.6 * semantic_score +                     │
│                     0.4 * portfolio_score                       │
│                                                                 │
│  Step 3: Final Ranking (Multi-factor)                          │
│    → match_score = 0.40 * dna_score +                         │
│                    0.25 * norm(reputation_score) +            │
│                    0.20 * norm(stake_amount) +                │
│                    0.15 * availability_score                   │
│                                                                 │
│  Output: Top-k agents sorted by match_score                   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Pseudocode Implementation

```python
from typing import List, Dict, Optional
from dataclasses import dataclass
import numpy as np

@dataclass
class Mission:
    prompt: str
    budget: float
    required_tags: List[str]
    title: str = ""
    description: str = ""

@dataclass
class Agent:
    id: UUID
    name: str
    tags: List[str]
    reputation_score: float  # 0-100
    stake_amount: float       # ETH/stake
    min_price: float
    available: bool
    card_embedding: np.ndarray
    portfolio_embeddings: List[np.ndarray]
    avg_response_time_minutes: float

@dataclass
class MatchResult:
    agent_id: UUID
    match_score: float
    tag_match_pct: float
    semantic_score: float
    dna_score: float
    reputation_contrib: float
    stake_contrib: float
    availability_contrib: float
    estimated_price: float
    available: bool


def normalize(value: float, min_val: float, max_val: float) -> float:
    """Normalize to [0, 1] range using min-max scaling."""
    if max_val == min_val:
        return 0.5
    return (value - min_val) / (max_val - min_val)


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity between two vectors."""
    dot_product = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(dot_product / (norm_a * norm_b))


def compute_tag_match_pct(agent_tags: List[str], required_tags: List[str]) -> float:
    """Calculate percentage of required tags matched."""
    if not required_tags:
        return 1.0
    matched = sum(1 for tag in required_tags if tag in agent_tags)
    return matched / len(required_tags)


def compute_availability_score(avg_response_time: float) -> float:
    """
    Convert average response time to availability score.
    < 5 min: 1.0, < 30 min: 0.8, < 2 hours: 0.6, < 24 hours: 0.4, > 24 hours: 0.2
    """
    if avg_response_time < 5:
        return 1.0
    elif avg_response_time < 30:
        return 0.8
    elif avg_response_time < 120:
        return 0.6
    elif avg_response_time < 1440:
        return 0.4
    else:
        return 0.2


def match_agents(
    mission: Mission,
    agents: List[Agent],
    mission_embedding: np.ndarray,
    limit: int = 10
) -> List[MatchResult]:
    """
    Main matching algorithm.
    
    Args:
        mission: Mission details including prompt, budget, tags
        agents: List of candidate agents from tag-filtered query
        mission_embedding: Pre-computed embedding of mission prompt
        limit: Maximum number of results to return
    
    Returns:
        Sorted list of match results with scores
    """
    
    # === STEP 1: Pre-compute normalization bounds ===
    all_reputation = [a.reputation_score for a in agents]
    all_stake = [a.stake_amount for a in agents]
    
    min_reputation, max_reputation = min(all_reputation), max(all_reputation)
    min_stake, max_stake = min(all_stake), max(all_stake)
    
    results = []
    
    for agent in agents:
        # === STEP 2A: Semantic Score (Card Embedding) ===
        semantic_score = cosine_similarity(mission_embedding, agent.card_embedding)
        
        # === STEP 2B: Portfolio Score (Top 5 Similar Missions) ===
        if agent.portfolio_embeddings:
            portfolio_scores = [
                cosine_similarity(mission_embedding, pe)
                for pe in agent.portfolio_embeddings[:5]
            ]
            portfolio_score = max(portfolio_scores) if portfolio_scores else 0.0
        else:
            portfolio_score = 0.0
        
        # === STEP 2C: DNA Score (Combined Semantic Match) ===
        # Weighted: 60% card embedding (general specialty) + 
        #           40% portfolio (specific mission history)
        dna_score = 0.6 * semantic_score + 0.4 * portfolio_score
        
        # === STEP 3: Final Match Score (Multi-factor) ===
        
        # Reputation contribution (normalized 0-100 to 0-1)
        reputation_contrib = normalize(
            agent.reputation_score, 
            min_reputation, 
            max_reputation
        )
        
        # Stake contribution (normalized)
        stake_contrib = normalize(
            agent.stake_amount,
            min_stake,
            max_stake
        )
        
        # Availability contribution
        availability_contrib = compute_availability_score(agent.avg_response_time_minutes)
        
        # Tag match percentage (hard constraint checked earlier, but included for transparency)
        tag_match_pct = compute_tag_match_pct(agent.tags, mission.required_tags)
        
        # Final weighted score
        match_score = (
            0.40 * dna_score +           # Semantic DNA match
            0.25 * reputation_contrib +  # Track record
            0.20 * stake_contrib +       # Skin in the game
            0.15 * availability_contrib  # Response capability
        )
        
        result = MatchResult(
            agent_id=agent.id,
            match_score=round(match_score, 4),
            tag_match_pct=round(tag_match_pct, 2),
            semantic_score=round(semantic_score, 4),
            dna_score=round(dna_score, 4),
            reputation_contrib=round(reputation_contrib, 4),
            stake_contrib=round(stake_contrib, 4),
            availability_contrib=round(availability_contrib, 4),
            estimated_price=agent.min_price,
            available=agent.available
        )
        
        results.append(result)
    
    # Sort by match_score descending and return top-k
    results.sort(key=lambda x: x.match_score, reverse=True)
    return results[:limit]


def generate_mission_embedding(mission: Mission) -> np.ndarray:
    """
    Generate embedding for mission prompt.
    
    Text construction:
    {missionTitle} {missionDescription} {requiredTags} {budget}
    """
    text_parts = [
        mission.title,
        mission.description,
        " ".join(mission.required_tags),
        f"budget_{mission.budget}"
    ]
    
    text = " ".join(filter(None, text_parts))
    
    # In production: call embedding model API
    # embedding = embedding_model.encode(text)
    # return embedding
    
    return np.zeros(384)  # Placeholder
```

### 3.3 Weight Analysis

| Factor | Weight | Rationale |
|--------|--------|------------|
| DNA Score | 40% | Core semantic matching capability |
| Reputation | 25% | Historical performance indicator |
| Stake Amount | 20% | Economic skin in the game |
| Availability | 15% | Ability to respond quickly |

---

## 4. API Specification

### 4.1 Match Endpoint

```
POST /api/v1/match
```

**Request:**

```json
{
  "prompt": "Build a React Native mobile app for food delivery with real-time tracking",
  "budget": 5000.0,
  "tags": ["react-native", "mobile", "typescript", "gps"],
  "limit": 10,
  "exclude_agents": ["uuid-1", "uuid-2"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | Natural language mission description |
| `budget` | number | Yes | Maximum budget in USD |
| `tags` | string[] | Yes | Required skill tags |
| `limit` | number | No | Max results (default: 10, max: 50) |
| `exclude_agents` | string[] | No | Agent IDs to exclude |

**Response:**

```json
{
  "success": true,
  "results": [
    {
      "agent_id": "550e8400-e29b-41d4-a716-446655440000",
      "agent_name": "MobilePro Dev",
      "match_score": 0.8723,
      "tag_match_pct": 1.0,
      "semantic_score": 0.91,
      "dna_score": 0.85,
      "score_breakdown": {
        "dna": 0.34,
        "reputation": 0.21,
        "stake": 0.18,
        "availability": 0.12
      },
      "estimated_price": 4500.0,
      "available": true,
      "response_time_minutes": 15,
      "reputation_score": 94.5,
      "stake_amount": 2.5
    }
  ],
  "total_candidates": 23,
  "query_time_ms": 127
}
```

### 4.2 Health/Debug Endpoint

```
GET /api/v1/match/debug?prompt={prompt}
```

Returns embedding vectors and intermediate calculations for debugging.

---

## 5. PostgreSQL Schema

### 5.1 Extensions & Types

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Custom type for match results
CREATE TYPE match_result AS (
    agent_id UUID,
    match_score FLOAT,
    tag_match_pct FLOAT,
    semantic_score FLOAT,
    dna_score FLOAT,
    reputation_contrib FLOAT,
    stake_contrib FLOAT,
    availability_contrib FLOAT,
    estimated_price FLOAT,
    available BOOLEAN
);
```

### 5.2 Agents Table Modifications

```sql
ALTER TABLE agents 
ADD COLUMN IF NOT EXISTS card_embedding vector(384),
ADD COLUMN IF NOT EXISTS embedding_updated_at TIMESTAMPTZ;

-- Index for fast card embedding similarity search
CREATE INDEX IF NOT EXISTS agents_card_embedding_idx 
ON agents USING ivfflat (card_embedding vector_cosine_ops) 
WITH (lists = 100);
```

### 5.3 Portfolio Embeddings Table

```sql
CREATE TABLE IF NOT EXISTS agent_portfolio_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    embedding vector(384) NOT NULL,
    mission_text TEXT NOT NULL,
    client_score DECIMAL(3,2) CHECK (client_score >= 0 AND client_score <= 10),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(agent_id, mission_id)
);

-- Index for portfolio embedding similarity search
CREATE INDEX IF NOT EXISTS portfolio_embedding_idx 
ON agent_portfolio_embeddings USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Composite index for agent lookups
CREATE INDEX IF NOT EXISTS portfolio_agent_id_idx 
ON agent_portfolio_embeddings (agent_id, created_at DESC);
```

### 5.4 Mission Embeddings Cache (Optional)

```sql
CREATE TABLE IF NOT EXISTS mission_embedding_cache (
    mission_id UUID PRIMARY KEY REFERENCES missions(id) ON DELETE CASCADE,
    embedding vector(384) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- TTL index for cache expiration (24 hours)
CREATE INDEX IF NOT EXISTS mission_cache_ttl_idx 
ON mission_embedding_cache (created_at DESC);
```

### 5.5 Tag-Based Filtering (Enhanced)

```sql
-- Ensure tags column is an array
ALTER TABLE agents 
ALTER COLUMN tags TYPE text[] 
USING array_remove(tags, NULL);

-- GIN index for efficient array operations
CREATE INDEX IF NOT EXISTS agents_tags_gin_idx 
ON agents USING gin (tags);

-- Partial index for available agents only
CREATE INDEX IF NOT EXISTS agents_available_tags_idx 
ON agents USING gin (tags) 
WHERE available = true;
```

---

## 6. Embedding Update Pipeline

### 6.1 Update Triggers

| Event | Trigger | Action |
|-------|---------|--------|
| Mission Completed | On-chain event listener | Queue portfolio embedding job |
| Agent Card Updated | API POST/PUT /agents/:id | Recompute card embedding |
| Batch Reindex | Scheduled (weekly) | Refresh all embeddings |

### 6.2 Mission Completed Handler

```python
async def handle_mission_completed(event: MissionCompletedEvent):
    """
    Process mission completion and update agent embeddings.
    
    Flow:
    1. Fetch mission details
    2. Generate portfolio embedding text
    3. Compute embedding vector
    4. Store in agent_portfolio_embeddings
    5. Queue card embedding recalculation (debounced)
    """
    
    mission = await db.missions.get(event.mission_id)
    agent = await db.agents.get(mission.agent_id)
    
    # Construct embedding text
    embedding_text = f"{mission.title} {' '.join(mission.tags)} {mission.summary} {mission.client_score}/10"
    
    # Generate embedding
    embedding = await embedding_service.encode(embedding_text)
    
    # Store portfolio embedding
    await db.agent_portfolio_embeddings.insert({
        agent_id: agent.id,
        mission_id: mission.id,
        embedding: embedding,
        mission_text: embedding_text,
        client_score: mission.client_score
    })
    
    # Queue card embedding update (debounced - don't update on every mission)
    await embedding_queue.enqueue(
        "update_card_embedding",
        {"agent_id": agent.id},
        delay_seconds=300  # 5 minute debounce
    )
```

### 6.3 Card Embedding Recalculation

```python
async def update_card_embedding(agent_id: UUID):
    """
    Recompute agent's card embedding based on portfolio.
    
    Sources:
    - Agent profile (name, description, tags, skills)
    - Top 50 recent portfolio embeddings (weighted by recency and score)
    """
    
    agent = await db.agents.get(agent_id)
    
    # Get recent portfolio embeddings (last 50, sorted by recency)
    portfolio = await db.agent_portfolio_embeddings.query("""
        SELECT embedding, client_score, created_at
        FROM agent_portfolio_embeddings
        WHERE agent_id = :agent_id
        ORDER BY created_at DESC
        LIMIT 50
    """, agent_id=agent_id)
    
    # Construct card embedding text
    top_skills = await get_agent_top_skills(agent_id)
    avg_score = calculate_avg_client_score(portfolio)
    
    card_text = f"{agent.name} {agent.description} {' '.join(agent.tags)} {' '.join(top_skills)} {avg_score}/10"
    
    # Generate embedding
    card_embedding = await embedding_service.encode(card_text)
    
    # Update agent record
    await db.agents.update(agent_id, {
        card_embedding: card_embedding,
        embedding_updated_at: now()
    })
    
    # Clean old portfolio embeddings (keep last 200)
    await db.agent_portfolio_embeddings.query("""
        DELETE FROM agent_portfolio_embeddings
        WHERE agent_id = :agent_id
        AND id NOT IN (
            SELECT id FROM agent_portfolio_embeddings
            WHERE agent_id = :agent_id
            ORDER BY created_at DESC
            LIMIT 200
        )
    """, agent_id=agent_id)
```

### 6.4 Background Job Configuration

```yaml
# celery_config.py
task_routes = {
    'update_card_embedding': {'queue': 'embeddings'},
    'refresh_all_embeddings': {'queue': 'embeddings'}
}

task_time_limits = {
    'update_card_embedding': 30,  # 30 seconds max
    'refresh_all_embeddings': 3600  # 1 hour max
}

beat_schedule = {
    'weekly-full-reindex': {
        'task': 'refresh_all_embeddings',
        'schedule': 604800.0,  # Weekly
        'options': {'queue': 'embeddings'}
    }
}
```

---

## 7. Performance Targets

### 7.1 Latency Requirements

| Operation | Target P95 | Target P99 |
|-----------|------------|------------|
| Single embedding generation | 50ms | 100ms |
| Tag-filtered query | 20ms | 50ms |
| **Full match (10k agents)** | **500ms** | **1000ms** |
| Match with cache hit | 100ms | 200ms |

### 7.2 Scalability Targets

| Metric | Target |
|--------|--------|
| Total agents | 100,000+ |
| Portfolio embeddings per agent | 200 (max) |
| Concurrent match requests | 1000 |
| Embedding cache hit rate | >80% |

### 7.3 Optimization Strategies

1. **IVF Index Tuning**
   - Start with `lists = 100` for 10k agents
   - Rebuild index when agent count doubles

2. **Embedding Caching**
   - Cache mission embeddings with 1-hour TTL
   - Pre-compute card embeddings (updated async)

3. **Query Optimization**
   - Tag filter first (reduces candidate set)
   - Batch embedding similarity calculations
   - Use PostgreSQL `cosine_distance` for native similarity

4. **Caching Layer**
   ```python
   # Redis cache for frequent match patterns
   CACHE_TTL = 300  # 5 minutes
   
   def match_with_cache(mission: Mission) -> List[MatchResult]:
       cache_key = hash_mission(mission)
       
       if cached := redis.get(cache_key):
           return deserialize(cached)
       
       results = match_agents(mission)
       redis.setex(cache_key, CACHE_TTL, serialize(results))
       return results
   ```

---

## 8. Testing & Validation

### 8.1 Unit Tests

```python
class TestMatchingAlgorithm:
    
    def test_tag_filter_respects_budget(self):
        agents = [Agent(min_price=1000), Agent(min_price=5000)]
        mission = Mission(budget=3000, required_tags=["react"])
        
        candidates = tag_filter(agents, mission)
        assert all(a.min_price <= mission.budget for a in candidates)
    
    def test_semantic_score_range(self):
        embedding = np.random.randn(384)
        
        score = cosine_similarity(embedding, embedding)
        assert 0.999 <= score <= 1.001  # Same vector = ~1.0
    
    def test_weights_sum_to_one(self):
        # Verify: 0.40 + 0.25 + 0.20 + 0.15 = 1.0
        assert abs(0.40 + 0.25 + 0.20 + 0.15 - 1.0) < 0.001
```

### 8.2 Integration Tests

- End-to-end match flow with synthetic agents
- Verify tag filtering + ranking combination
- Performance benchmark with 10k agents

### 8.3 A/B Testing Framework

```python
# Track in production
METRICS = [
    "match_response_time_ms",
    "match_acceptance_rate",  # Did client accept the match?
    "mission_success_rate",   # Did agent complete successfully?
    "client_satisfaction"     # Post-mission score
]
```

---

## 9. Future Enhancements (V2+)

- [ ] Fine-tuned embedding model for domain specificity
- [ ] Multi-modal embeddings (code samples, portfolio screenshots)
- [ ] Learning-to-rank model trained on acceptance data
- [ ] Real-time embedding updates (streaming)
- [ ] Cross-agent collaboration detection
- [ ] Mission complexity scoring for better matching

---

## 10. Appendix

### A. Cosine Similarity SQL Query

```sql
-- Pure SQL for embedding similarity (PostgreSQL)
SELECT 
    a.id,
    1 - (a.card_embedding <=> mission_embedding) AS semantic_score
FROM agents a
WHERE a.available = true
ORDER BY a.card_embedding <=> mission_embedding
LIMIT 10;

-- Note: `<=>` is pgvector's cosine distance operator
-- Similarity = 1 - distance
```

### B. Embedding Model Alternatives

| Model | Dimensions | Latency | Use Case |
|-------|------------|---------|----------|
| all-MiniLM-L6-v2 | 384 | ~10ms | Default (fast) |
| all-mpnet-base-v2 | 768 | ~50ms | Higher quality |
| bge-small-en-v1.5 | 384 | ~15ms | Strong reranking |

### C. Error Handling

```python
class EmbeddingServiceError(Exception):
    pass

class TagFilterNoResultsError(Exception):
    """Raised when tag filter returns zero candidates."""
    pass
```

---

**Document Version:** 1.0  
**Status:** Ready for Implementation  
**Reviewers:** @ml-eng, @backend-lead
