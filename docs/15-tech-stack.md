# 15. Suggested Tech Stack

## Recommended Stack (with rationale)

### Mobile
| Choice | Pick | Why |
|--------|------|-----|
| Framework | **Flutter (Dart)** | One codebase, 60fps charts and custom UI (finance apps live and die on chart smoothness), excellent theming for the design-heavy brand. Alternative: **React Native + Expo** if the team is TypeScript-native — also fully viable; choose by team skills, not ideology. |
| Local storage | **Drift (SQLite) + SQLCipher** | Encrypted offline cache, relational queries for offline transaction browsing |
| State | Riverpod (Flutter) / Zustand+TanStack Query (RN) | |
| Charts | fl_chart / custom CustomPainter (Flutter); Victory Native (RN) | |
| Secure storage | Keychain / Android Keystore via flutter_secure_storage | Hardware-backed token storage |
| Bank linking | Plaid Link native SDK | Never hand-roll credential UI |
| Push | Firebase Cloud Messaging + APNs | |
| Payments | RevenueCat | Cross-platform subscriptions, trials, paywalls without rebuilding StoreKit/Billing |
| Crash/analytics | Sentry + PostHog (self-host option; no financial values in events) | |

### Backend
| Choice | Pick | Why |
|--------|------|-----|
| Language/runtime | **TypeScript on Node.js (NestJS)** | One language across API + import parsers + tooling; huge fintech SDK ecosystem (Plaid official SDK); NestJS gives the modular-monolith structure doc 6 calls for. Alternatives: Go (raw performance) or Python/FastAPI (if ML team dominates). |
| API style | REST + OpenAPI (generated mobile clients) | Contract-first, typed end to end |
| Database | **PostgreSQL 16 (AWS RDS/Aurora)** | RLS, partitioning, NUMERIC money math, GIN full-text — doc 5 is built for it |
| Cache | Redis (ElastiCache) | Sessions, hot dashboards, rate limits |
| Queue | **AWS SQS** (+ EventBridge schedules) | Managed, DLQs, exactly-what-doc-6-needs; Temporal later if pipeline orchestration outgrows queues |
| Object storage | S3 with SSE-KMS | Statements, receipts, exports |
| Secrets/tokens | AWS KMS + Secrets Manager (or Vault) | Envelope encryption, rotation |
| Search | Postgres FTS first; OpenSearch only if NL search demands it | Don't add infra early |

### ML / AI
| Choice | Pick | Why |
|--------|------|-----|
| Categorizer | fastText or DistilBERT-class model served via a small Python **FastAPI/gRPC** service | Tiny, fast, cheap; retrained weekly from corrections |
| LLM fallback & PDF extraction | **Claude Haiku class** (latest: claude-haiku-4-5) for high-volume categorization/cache-fill; **Claude Sonnet class** (claude-sonnet-4-6) for PDF statement extraction and the AI advisor | Batched, schema-constrained (tool use / JSON), globally cached by descriptor → near-zero marginal cost |
| OCR | AWS Textract (fallback Tesseract) | Scanned statements |
| Embeddings (NL search, P2) | Small open model or API embeddings + pgvector | |

### Infra & Ops
- **AWS** (us-east + eu-west at EU launch), Terraform IaC, ECS Fargate (or EKS later).
- GitHub Actions CI/CD: lint, tests, SAST (Semgrep), dependency scanning, canary deploys.
- OpenTelemetry → Grafana/Tempo (or Datadog if budget allows); Sentry across stack.
- Plaid sandbox in dev/staging; synthetic data only outside prod.

### Third Parties (deliberately few)
Plaid (→ +MX/Finicity later) · Stripe + RevenueCat · FCM/APNs · Anthropic API ·
Textract · merchant-logo enrichment (Brandfetch/Clearbit-style) · exchangerate API for FX.

## One-Paragraph Justification

This stack optimizes for **a small team shipping a trustworthy product fast**: managed
services everywhere ops isn't differentiating (RDS, SQS, Fargate, RevenueCat), one primary
language per layer (Dart UI, TypeScript backend, Python ML), Postgres doing triple duty
(OLTP, full-text, vectors) until scale forces specialization, and LLMs used surgically —
as a cached fallback and extraction tool with strict schemas — rather than as the
first-line categorizer, keeping AI costs near zero per user while preserving the magic.
