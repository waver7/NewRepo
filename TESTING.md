# Testing Guide

## Test the real app (it exists now)

The Flutter app lives in [`app/`](app/) and runs on both Android and iOS. The fastest
paths to seeing it work:

```bash
cd app
flutter test       # 29 unit/widget tests over the money-critical logic
flutter analyze    # zero issues
flutter run        # launches on a connected device/emulator/simulator
```

Then follow the **5-minute manual test script** in [app/README.md](app/README.md) —
it walks through demo mode, the planted price-increase and duplicate-charge insights,
category learning, CSV import with duplicate skipping (sample file included at
`app/sample_data/chase_checking.csv`), budgets, and goals.

---

## Testing the full cloud product (design reference)

The sections below describe how the complete backend-connected product from the
design docs gets tested once that phase is built.

---

## 1. How to validate the design today

| What to check | How |
|---------------|-----|
| Completeness | Walk the [README index](README.md) — all 17 deliverables map to a doc |
| Schema correctness | The DDL in [docs/05-database-schema.md](docs/05-database-schema.md) is valid PostgreSQL — paste it into a scratch database (`docker run -e POSTGRES_PASSWORD=pg -p 5432:5432 postgres:16`, then `psql`) to verify it creates cleanly (create the `citext` extension first and reorder the two forward-referenced tables, noted inline) |
| Flow coverage | Trace each user flow in [docs/03-user-flows.md](docs/03-user-flows.md) against the screens in [docs/04-app-screens.md](docs/04-app-screens.md) — every step should have a screen |
| Algorithm soundness | Hand-run the worked examples: dedup scoring (doc 7 §7.4) and recurring detection (doc 11 §11.1) against a sample of your own bank CSV |

---

## 2. How the built app will be tested

### 2.1 Test data — no real bank accounts needed

- **Plaid Sandbox** (free, no approval needed): create a Plaid account, use sandbox keys.
  In the Link flow, any institution accepts the test credentials
  `user_good` / `pass_good`; Plaid returns realistic fake accounts and transactions.
  Special test users simulate edge cases: `user_good`+`mfa_device` (MFA),
  `ITEM_LOGIN_REQUIRED` webhooks can be fired on demand from the sandbox API — this is how
  the re-auth flow (doc 3 §3.11) gets tested without ever touching a real bank.
- **Demo mode** (doc 3 §3.1) doubles as a manual-testing dataset: a curated 24-month
  synthetic ledger containing known subscriptions, transfers, duplicates, a price increase,
  and an anomaly — so every insight type can be triggered deterministically.
- **File-import fixtures:** a `fixtures/` directory with real-world-shaped exports —
  Chase/BoA/Amex CSV layouts, a multi-sheet XLSX, an OFX, a text-layer PDF and a scanned
  PDF — each paired with the expected parsed output (golden files).

### 2.2 Test pyramid

| Layer | Scope | Tooling (per doc 15 stack) |
|-------|-------|---------------------------|
| **Unit** | The money-critical pure logic: dedup fingerprint + fuzzy scorer, recurring-cadence scorer, transfer matcher, safe-to-spend math, debt amortization, CSV column-mapping heuristics, currency/sign normalization | Jest (backend), `flutter test` (app). These algorithms get exhaustive table-driven tests — they are the product |
| **Integration** | Ingestion pipeline end-to-end against a real Postgres + queue (Testcontainers); Plaid adapter against sandbox; import worker against the fixtures directory | Jest + Testcontainers |
| **Contract** | OpenAPI schema ↔ generated mobile client; webhook signature verification | Schemathesis / generated-client compile checks |
| **E2E (mobile)** | Onboarding → link sandbox bank → see categorized transactions → correct a category → rule applied; import CSV → dedup banner correct | Patrol/integration_test (Flutter) or Detox (RN), run on CI device farm |
| **Golden-file** | Every parser (CSV/XLSX/OFX/PDF) and the categorizer: input fixture → expected JSON; any diff fails CI | Plain snapshot tests |

### 2.3 Acceptance checks that gate a release

These mirror the MVP success criteria (doc 13):

1. **Dedup safety:** importing the same CSV twice yields zero new transactions; importing
   a statement overlapping a linked account yields zero double-counts. False-merge rate
   must be ~0 — this is the trust-killer check.
2. **Categorization accuracy:** ≥ 90% on the held-out labeled set (golden corpus of
   ~5k descriptors); no regression vs. the previous model (shadow evaluation, doc 6).
3. **Transfer exclusion:** synthetic ledger's income/expense totals match hand-computed
   values exactly (transfers and credit-card payments excluded).
4. **Recurring recall:** all 9 planted subscriptions in the demo dataset detected; the
   planted price increase raises exactly one insight.
5. **Security smoke:** no token/credential strings in logs; API rejects cross-user IDs
   (RLS test); biometric lock engages on background/foreground cycle.
6. **Pipeline latency:** sandbox webhook → transaction visible via API in < 60s (p95).

### 2.4 Manual test script (10 minutes, every release candidate)

```
1. Fresh install → sign up with email → enable Face ID
2. Tap "Explore demo" → verify dashboard, subscription hub, and 2 attention cards render
3. Link Plaid sandbox (user_good/pass_good) → wait for "ready" push → transactions appear
4. Recategorize one transaction → accept "Always?" → verify retroactive application
5. Import fixtures/chase_checking.csv → verify mapping preview → confirm →
   check "N new / M duplicates" banner
6. Create a savings goal ($5,000 by next June) → verify pace math
7. Fire ITEM_LOGIN_REQUIRED from Plaid dashboard → verify badge + repair flow
8. Settings → Export data → verify CSV contents; → Delete account → verify wipe
```

---

## 3. Want to test something running *now*?

The natural next step is scaffolding the codebase (NestJS API + Postgres schema +
Flutter shell per doc 15). Once that lands, this guide's section 2 becomes executable:
`docker compose up` for the backend, `flutter run` for the app, Plaid sandbox keys in
`.env`. Ask and it will be built on this repo.
