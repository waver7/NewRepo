# 6. Backend Architecture

## 6.1 Shape: Modular Monolith → Services

Start as a **modular monolith** (one deployable, strict internal module boundaries) plus a
worker fleet — microservices on day one would slow a small team down. The module boundaries
below are designed so the heavy/independent parts (ingestion, ML) can be split out first
when scale demands.

```
                            ┌─────────────────────────────┐
   iOS / Android / Web ───▶ │  API Gateway (HTTPS, WAF,   │
   (TLS 1.3, cert pinning)  │  rate limiting, auth check) │
                            └──────────────┬──────────────┘
                                           │
                     ┌─────────────────────┴─────────────────────┐
                     │            Core API (modular)             │
                     │  auth · accounts · transactions · budgets │
                     │  goals · insights · imports · billing     │
                     └───────┬───────────────┬───────────────────┘
                             │ enqueue       │ read/write
                             ▼               ▼
        ┌──────────────────────────┐   ┌──────────────────┐   ┌─────────────┐
        │ Job queue (SQS/Redis)    │   │ PostgreSQL (RDS) │   │ Redis cache │
        └──────┬───────────────────┘   │ + read replicas  │   └─────────────┘
               ▼                       └──────────────────┘
   ┌──────────────────────────────────────────────────────┐
   │                    Worker fleet                      │
   │  sync-worker        — aggregator pulls, webhooks     │
   │  ingest-pipeline    — normalize→dedup→enrich→categorize→recurring│
   │  import-worker      — CSV/XLSX/PDF/OFX parsing       │
   │  insight-engine     — anomalies, bills, opportunities│
   │  notifier           — push (APNs/FCM), email digests │
   │  ml-service (gRPC)  — categorizer model + embeddings │
   └──────────────────────────────────────────────────────┘
               ▲                               │
   Webhooks ───┘ (Plaid/MX/Finicity,           ▼
   signature-verified, idempotent)      S3 (statements, receipts,
                                        exports — SSE-KMS encrypted)
```

## 6.2 The Ingestion Pipeline (the heart of the system)

Every transaction — from aggregator webhook, file import, or manual entry — flows through
the same ordered pipeline, implemented as idempotent queue stages:

```
1. NORMALIZE   sign convention (negative = outflow), currency, dates, trim raw descriptor
2. DEDUP       fingerprint match + fuzzy window (doc 7 §dedup); pending→posted reconciliation
3. ENRICH      merchant resolution (alias table → enrichment API), logo, MCC, location
4. FX          convert to home currency at posted-date rate
5. CATEGORIZE  rules → merchant DB → ML → LLM fallback (doc 7)
6. TRANSFER    cross-account pair matching → mark is_transfer
7. RECURRING   incremental series matching (doc 11)
8. AGGREGATE   update materialized monthly stats (incremental, not full refresh)
9. INSIGHT     run detectors on the delta (anomaly, large txn, duplicate charge, fee)
10. NOTIFY     fan out qualifying alerts respecting user prefs & quiet hours
```

Each stage is retry-safe (at-least-once delivery + idempotency keys = exactly-once effect).
A poison-message DLQ with alerting catches malformed data without blocking the pipeline.

## 6.3 Key Services

### Aggregator Hub (doc 9)
Provider-agnostic interface (`link`, `exchangeToken`, `fetchAccounts`, `fetchTransactions`,
`handleWebhook`, `revoke`) with Plaid/MX/Finicity adapters. Owns token vault references,
webhook signature verification, cursor-based incremental sync, and institution-level
provider routing/fallback.

### Import Service (doc 10)
Streams files from S3, detects format, runs the right parser, manages the mapping/review
state machine, then feeds rows into the standard ingestion pipeline.

### ML Service (doc 7)
Stateless gRPC service serving the categorization model and text embeddings. Versioned
models, shadow deployment (new model scores in parallel, compared offline before promotion).

### Insight Engine
Runs (a) on ingest deltas for real-time detections and (b) nightly per-user batch for
forecasts, bill-risk, subscription review, weekly digest assembly. Every insight is written
with a `dedupe_key` so users never get the same alert twice.

### Notifier
Single choke-point for all outbound push/email. Enforces per-user rate limits
(max N pushes/day), quiet hours, per-type preferences, and digest batching. Templates keep
sensitive details out of lock-screen previews by default ("New insight about a subscription"
vs. naming amounts).

## 6.4 API Design

- **REST + JSON** (`/v1/...`), OpenAPI-generated typed clients for the mobile app.
- Cursor pagination everywhere; sync endpoints expose `changed_since` deltas so the app
  maintains an offline cache cheaply.
- Idempotency keys on all mutating endpoints (mobile retries are a fact of life).
- Server-driven insight cards: the home-screen "attention" feed is a server-composed list,
  so new insight types ship without app releases.

## 6.5 Reliability & Operations

| Concern | Approach |
|---------|----------|
| DB | Multi-AZ Postgres, PITR backups, read replicas for analytics queries |
| Queues | DLQs + redrive; per-stage concurrency limits to protect the DB |
| Aggregator outages | Circuit breakers per provider/institution; stale-data banners in app rather than errors |
| Webhooks | Verified, persisted raw first, then processed async — never lose an event |
| Observability | OpenTelemetry traces across pipeline stages; per-stage latency/error SLOs; Sentry for mobile |
| Pipeline SLO | Webhook → visible in app p95 < 60s; file import (5k rows) p95 < 30s |
| Load shedding | Insight/forecast batch jobs are preemptible; user-facing API always wins |
| Environments | dev/staging/prod with Plaid sandbox; no real financial data outside prod |
| IaC | Terraform; immutable deploys; canary releases for the API |

## 6.6 Multi-Region & Data Residency (later)

EU expansion adds an EU data home (separate Postgres + S3, EU aggregators via
TrueLayer/GoCardless). Users are homed to a region at signup; no cross-region replication of
financial data. The provider abstraction (doc 9) makes regional aggregators a config concern,
not an architectural one.
