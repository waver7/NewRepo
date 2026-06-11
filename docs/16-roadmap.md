# 16. Roadmap (18 months)

## Phase 0 — Foundations (Month 0–1)
- Architecture setup: repo, CI/CD, Terraform, environments, observability
- Auth (Apple/Google/email + MFA), security baseline (KMS envelope encryption, audit log)
- Postgres schema (doc 5), Plaid sandbox integration, aggregator abstraction interface
- App shell: navigation, design system, dark mode, biometric lock, demo mode data
- **Exit:** linked sandbox account → transactions visible in app

## Phase 1 — MVP Build (Months 2–4) → **v1.0 Launch**
- Ingestion pipeline end-to-end (normalize → dedup → enrich → categorize → recurring)
- Categorization cascade + corrections → rules; merchant enrichment
- CSV/XLSX import with smart mapping; manual entry; transfer detection
- Dashboard, transactions, insights (category/merchant/account), subscription hub
- Savings goals + spending limits; core alerts; weekly digest
- Paywall (Free/Plus), data export, account deletion
- Security review + pentest; Plaid production approval; App Store / Play submission
- Closed beta (500 users) weeks 14–16 → public launch
- **Exit metrics:** doc 13 success criteria

## Phase 2 — Intelligence & Stickiness (Months 5–9) → **v1.5–v2.0**
- PDF + OFX/QFX import (balance-verified extraction) — marketing moment
- Anomaly detection, price-increase alerts, fee radar, duplicate-charge alerts
- Debt payoff + emergency fund goals; safe-to-spend hero metric; auto-budget
- Multi-currency unified view; rules engine UI; tags/notes/receipts; splits
- Widgets; trends (12-mo charts); report exports; second aggregator (MX or Finicity)
- Subscription cancellation playbooks + "Lumen saved you $X" counter
- **Targets:** D30 retention ≥ 40%, categorization ≥ 95%, conversion ≥ 5%

## Phase 3 — Premium & Forecasting (Months 9–13) → **v2.5**
- Cash-flow forecasting (30/60/90d) + bill-risk warnings
- AI advisor chat (tool-grounded, Premium); monthly narrative report
- Net worth: investments, loans, manual assets; balance-history analytics
- Household sharing v1 (partner, per-account visibility); accountant share links
- Email-forwarding ingestion + item-level receipts (beta)
- HYSA marketplace + card optimizer (opt-in, net-benefit-ranked)
- SOC 2 Type I complete
- **Targets:** Premium attach ≥ 25% of paid; advisor weekly usage ≥ 30% of Premium

## Phase 4 — Expansion & Action Layer (Months 13–18) → **v3.0**
- EU/UK launch: TrueLayer/GoCardless, EU data region, localization (top 5 languages)
- Web companion app; watch app; Siri/Assistant shortcuts
- Money movement (sweep rules, round-ups) via payment partner — per-action consent
- Bill negotiation concierge partner; Year in Money campaign (growth)
- Benchmarks (opt-in); export API/Zapier; SOC 2 Type II underway
- **Targets:** 250k MAU, ≥ 6% paid conversion, NPS ≥ 50

## Always-On Tracks (run through every phase)
- **Categorization quality:** weekly model retrains from corrections, accuracy dashboards
- **Connection health:** per-institution success-rate monitoring, routing-table tuning
- **Trust:** quarterly security reviews, transparency page, support SLAs
- **Performance:** cold-start < 1.5s, webhook→app p95 < 60s, crash-free > 99.8%

## Biggest Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Aggregator cost eats margin at free tier | 2-connection free cap, dormant-item reaping, multi-provider pricing leverage |
| Categorization not "magic" enough at launch | LLM fallback + global cache covers cold start; corrections compound fast |
| App-store finance category is crowded | Wedge on the two underserved jobs: best-in-class file import + proactive subscription/waste detection |
| Plaid production approval delays | Start security questionnaire in Phase 0, not Phase 1 |
| Trust incident | Doc 8 controls + practiced incident runbook; transparency-first comms |
