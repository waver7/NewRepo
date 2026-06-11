# 13. MVP Version (v1.0 — months 0–4)

## Scope Philosophy

The MVP must prove the core loop: **connect/import → everything auto-organized → one
genuinely useful insight → user returns weekly.** Everything that doesn't serve that loop
waits. But the MVP must *not* cut the things users judge instantly: categorization accuracy,
dedup correctness, and security.

## In Scope

**Ingestion**
- Plaid linking (US): accounts, balances, 24-month backfill, webhook sync
- CSV/XLSX import with smart column mapping + saved templates
- Manual transactions (quick-add, offline-capable)
- Pending→posted reconciliation; cross-source dedup; transfer detection

**Intelligence**
- Full categorization cascade (rules → merchant DB → ML-lite* → LLM fallback)
  with corrections → personal rules (*MVP can ship Stage 3 as descriptor-prefix
  classifier; the LLM fallback covers the gap until the trained model lands)
- Recurring/subscription detection + Subscription Hub + upcoming-bill list
- Core alerts: large transaction, low balance, bill due, new subscription

**Experience**
- Home dashboard: monthly in/out/net, savings rate, top categories, attention cards
- Transactions list + detail + search/filter + recategorize/exclude
- Insights: spending by category / merchant / account, credit-vs-debit split, MoM deltas
- Goals: savings goals + per-category spending limits (the other two types are P1)
- Accounts tab with connection management
- Onboarding with demo mode; push notifications; dark mode; accessibility

**Trust**
- Biometric/PIN lock, Apple/Google/email auth + MFA
- Encryption model from doc 8 (field-level for tokens; this is not deferrable)
- Data export (CSV) + hard account deletion

**Monetization**
- Free (2 connections) vs Plus ($7.99) paywall via RevenueCat; 30-day trial

## Explicitly Out (and why)

| Cut | Why it can wait |
|-----|-----------------|
| PDF import | Highest build cost of the import formats; CSV covers most needs — fast-follow P1 |
| Multi-aggregator (MX/Finicity) | Plaid covers ~12k institutions; abstraction layer is built, adapters wait |
| Debt payoff + emergency fund goals | Savings goals + limits prove the engine first |
| Anomaly detection, price-increase alerts | Need months of per-user history to be precise; ship at P1 with data accrued |
| Multi-currency unified view | Per-account currency stored correctly from day 1; FX view at P1 |
| AI advisor chat, forecasting, net worth, investments | Premium-tier P2 |
| Household sharing, web app, widgets, email ingestion | P1/P2 |

## MVP Success Criteria (go/no-go for scaling spend)

| Metric | Bar |
|--------|-----|
| Signup → first insight | < 3 min median |
| Auto-categorization acceptance (uncorrected) | > 90% |
| Dedup false-merge rate | ~0 (this is a trust-killer) |
| W1 → W4 retention | > 30% |
| Plaid link success rate | > 85% of attempts |
| Trial → paid | > 4% |

## Team & Timeline (indicative)

2 mobile (Flutter or RN), 2 backend, 1 ML/data, 1 designer, 1 PM/founder.
M1: foundations (auth, schema, Plaid sandbox, app shell) → M2: ingestion pipeline +
categorization + transactions UI → M3: dashboard, subscriptions, goals, alerts, CSV import →
M4: hardening, security review, Plaid production approval, beta (TestFlight/Play), launch.
