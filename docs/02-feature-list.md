# 2. Complete Feature List

Priority key: **P0** = MVP, **P1** = fast-follow (months 4–9), **P2** = advanced (months 9–18).

## 2.1 Account Aggregation & Data Ingestion

| Feature | Priority | Notes |
|---------|----------|-------|
| Bank/card linking via Plaid (US/CA/EU) | P0 | OAuth-first; read-only scopes |
| Multi-aggregator support (MX, Finicity, TrueLayer/GoCardless for EU/UK) | P1 | Provider abstraction layer; auto-fallback when an institution fails on one provider |
| Manual transaction entry (amount, merchant, date, category, notes, photo of receipt) | P0 | Offline-capable, syncs later |
| CSV import with smart column mapping | P0 | AI-assisted header detection; saved mapping templates per bank |
| Excel (XLSX) import | P0 | Same pipeline as CSV |
| OFX/QFX/QIF import | P1 | Native parser, highest fidelity |
| PDF statement import (text + scanned/OCR) | P1 | LLM-based extraction with confidence scores and review step |
| Email-forwarding ingestion (receipts@lumen.app) | P2 | Parse e-receipts for item-level data |
| Cash account tracking | P0 | Manual balance + transactions |
| Investment & retirement accounts (read-only holdings, balances) | P2 | Via aggregator investment endpoints |
| Loans & mortgages (balance, rate, payoff tracking) | P2 | |
| Real assets & liabilities (home, car via VIN/Zillow-style estimate, private loans) | P2 | Completes net worth |
| Historical backfill (up to 24 months where the institution allows) | P0 | |
| Real-time webhook sync + scheduled refresh | P0 | New-transaction push notifications |

## 2.2 Transaction Intelligence

| Feature | Priority | Notes |
|---------|----------|-------|
| Auto-categorization (50+ categories, 2-level taxonomy) | P0 | Hybrid: rules → merchant DB → ML → LLM fallback (see doc 7) |
| Merchant name cleaning & enrichment (logo, website, location) | P0 | "SQ *BLUEBTL 4421" → "Blue Bottle Coffee" |
| User category corrections that train personal model | P0 | Correction → personal rule, instantly applied to similar txns |
| Custom rules engine (if merchant/amount/account/text → set category/tag/hide) | P1 | |
| Cross-source duplicate detection | P0 | Bank-link + file import + manual entry reconciliation |
| Transfer detection (excluded from income/expense) | P0 | Matched pairs across accounts |
| Split transactions (one charge → multiple categories) | P1 | |
| Tags, notes, receipt attachments | P1 | |
| Refund/return matching (links refund to original purchase) | P2 | |
| Pending → posted transaction reconciliation | P0 | |
| Item-level receipt breakdown (from e-receipts/photos) | P2 | "Groceries $84 → $12 of it was alcohol" |
| Search: full-text + natural language ("coffee last month over $5") | P1 | NL search is P2 |

## 2.3 Recurring & Subscriptions

| Feature | Priority |
|---------|----------|
| Automatic detection of subscriptions & recurring bills (see doc 11) | P0 |
| Subscription hub: monthly/annual cost totals, next charge dates | P0 |
| Price-increase alerts ("Netflix went from $15.49 → $17.99") | P1 |
| Forgotten/unused subscription flags (free trial about to convert; service unused) | P1 |
| Upcoming bill calendar + reminders ("Rent due in 3 days, balance is low") | P0 |
| Cancellation assistance (deep links, instructions, concierge in Premium) | P2 |
| Variable-bill forecasting (utilities estimated from seasonal history) | P2 |

## 2.4 Analytics & Reporting

| Feature | Priority |
|---------|----------|
| Home dashboard: net cash flow, safe-to-spend, alerts, top categories | P0 |
| Monthly income / expenses / savings rate | P0 |
| Spending by category, merchant, account/card — with month-over-month deltas | P0 |
| Credit vs debit vs cash spending breakdown | P0 |
| Trends: 12-month charts per category/merchant | P1 |
| Net worth tracking over time | P2 |
| Cash-flow forecast (30/60/90-day projected balance incl. known bills) | P2 |
| Annual "Year in Money" review (shareable, Spotify-Wrapped style) | P2 |
| Reports export (CSV, PDF), accountant share link | P1 |
| Multi-currency: per-account currency + unified home-currency view with historical FX rates | P1 |

## 2.5 Budgets, Goals & Planning

| Feature | Priority |
|---------|----------|
| Savings goals (target amount + date, linked account, auto progress) | P0 |
| Spending limits per category with progress + alerts at 75%/90%/100% | P0 |
| Auto-budget suggestion from 3-month history | P1 |
| Debt payoff goals (avalanche/snowball plans, interest saved, debt-free date) | P1 |
| Emergency fund goal (auto-computed from user's essential expenses, e.g. 3–6 months) | P1 |
| Safe-to-spend number (income − bills − goals − spent so far) | P1 |
| Round-up & sweep rules (virtual envelopes; real transfers in P2 via partner) | P2 |
| Shared/household budgets (partner sees shared accounts only) | P2 |

## 2.6 Alerts & Insights

| Feature | Priority |
|---------|----------|
| New large transaction alert (threshold configurable) | P0 |
| Low balance / overdraft risk warning | P0 |
| Unusual spending anomaly detection (per merchant/category/time pattern) | P1 |
| Duplicate-charge alert (same merchant, same amount, same day) | P1 |
| Fee detection (bank fees, ATM fees, FX fees) with monthly fee report | P1 |
| Savings opportunities (idle cash, cheaper-plan suggestions, fee avoidance) | P2 |
| Weekly digest (push + optional email): 30-second summary | P1 |
| AI advisor chat ("Can I afford a $1,400 flight in March?") | P2 |

## 2.7 Platform & UX

| Feature | Priority |
|---------|----------|
| iOS + Android apps (single codebase) | P0 |
| Biometric app lock (Face ID / fingerprint) + PIN fallback | P0 |
| Dark mode, dynamic type, full accessibility (VoiceOver/TalkBack) | P0 |
| Home-screen widgets (safe-to-spend, monthly spend, upcoming bills) | P1 |
| Offline mode (read cache + queue manual entries) | P1 |
| Privacy blur (hide amounts with a tap / on app-switcher) | P1 |
| Demo mode (explore with sample data before linking anything) | P0 |
| Localization & 30+ currencies | P1 |
| Web companion app (read-only dashboards, big-screen reports) | P2 |

## 2.8 Account & Data Control

| Feature | Priority |
|---------|----------|
| Email + Apple/Google sign-in, MFA | P0 |
| Full data export (CSV/JSON) — free for all tiers | P0 |
| One-tap account deletion with hard data purge | P0 |
| Per-institution connection management (pause, unlink, re-auth) | P0 |
| Session/device management | P1 |
