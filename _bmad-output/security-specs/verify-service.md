# Verify Service Spec

## GitHub App Configuration
- GitHub App token (auto-rotated 1h by GitHub)
- Rate limit: 5000 requests/hour
- Cache: verified results cached 7 days by commit SHA

## Webhook Authentication
- ALL webhooks must include valid X-Hub-Signature-256
- Invalid/missing signature → 401, zero API call made
- Rate limit per repo: max 10 verify calls/repo/hour

## EAL Verification Steps
1. Signature valid + runId exists in GitHub API
2. repo matches agent registered repo
3. event = workflow_dispatch
4. mission-binding artifact present with correct missionId
5. run created_at > mission.claimedAt

## Fallback: deferred-verify
- If GitHub down or rate limited → EAL status = deferred-verify, TTL 24h
- Client notified via webhook
- Verification retried every 5min during TTL
- After 24h unresolved → EAL rejected, mission stays IN_PROGRESS

## Anti-DDoS
- Webhook validation is pure HMAC (no DB, no API call) → O(1), cannot be exhausted
