# 1. Product Vision

## Mission

**Give every person a financial copilot that does the bookkeeping for them and tells them
exactly what matters, before it matters.**

Money management fails for most people not because they lack discipline, but because the
work is tedious: dozens of accounts, hundreds of transactions, cryptic merchant names,
silent subscription renewals. Lumen removes the work. The user's only job is to glance at
the app and act on clear, personalized guidance.

## Product Thesis

1. **Aggregation is table stakes; intelligence is the product.** Mint, Copilot, Monarch,
   and YNAB all aggregate. Lumen wins on what it *does* with the data: proactive detection
   (price hikes, gray charges, anomalies), forecasting (cash-flow runway, goal ETAs), and
   plain-language coaching.
2. **Zero-effort by default, full control on demand.** Everything is automatic
   (categorization, dedup, recurring detection), but every automatic decision is visible,
   explainable ("categorized as Groceries because…"), and overridable — and the system
   learns from every correction.
3. **Trust is a feature.** Read-only access, no data selling ever, end-to-end encryption
   of sensitive fields, biometric lock, one-tap data export and account deletion. The
   business model (subscription) aligns with the user, not advertisers.

## Target Users

| Persona | Pain | Lumen's answer |
|---------|------|----------------|
| **The Juggler** (25–40, 5+ cards/accounts) | No single picture of money; surprise charges | Unified dashboard, anomaly + subscription radar |
| **The Goal-Setter** (saving for house/travel/debt-free) | Doesn't know if they're on pace | Goal forecasting, safe-to-spend, auto-budgets |
| **The Avoider** (anxious, checks balance rarely) | Finance apps feel like homework | 30-second weekly digest, gentle nudges, no shame UX |
| **The Optimizer** (FIRE/power user) | Wants depth: net worth, cash-flow, exports | Reports, rules engine, CSV/API export, multi-currency |

## Design Principles

1. **Glanceable first.** The home screen answers "Am I OK?" in under 5 seconds:
   safe-to-spend, cash flow, anything needing attention.
2. **Explain everything.** No black boxes — every insight shows its evidence.
3. **One tap to correct, never the same correction twice.** Corrections become rules.
4. **Calm, not gamified-anxious.** Progress and encouragement over red warnings and streak guilt.
5. **Privacy as UX.** Security controls are visible and simple, not buried.

## Monetization

**Freemium subscription. Never ads, never data sales.**

| Tier | Price | Includes |
|------|-------|----------|
| **Free** | $0 | 2 linked accounts, manual + file import, auto-categorization, dashboard, 1 goal, monthly summary |
| **Plus** | $7.99/mo or $59/yr | Unlimited accounts, subscription radar + cancellation help, anomaly alerts, unlimited goals & budgets, custom rules, multi-currency, CSV export, 24-month history |
| **Premium** | $14.99/mo or $99/yr | Everything in Plus + AI advisor chat, cash-flow forecasting, net-worth & investment tracking, bill negotiation referrals, household sharing (2 members), priority support |

Secondary (ethical) revenue, all opt-in and clearly labeled:
- **Savings/CD/HYSA marketplace referrals** ("your $8,200 idle balance could earn ~$370/yr at 4.5% APY").
- **Bill negotiation / cancellation concierge** (rev-share with partner, e.g. for internet/phone bills).
- **Credit card / refinance recommendations** driven by the user's actual spending mix — shown only when net benefit to the user is positive and quantified.

Explicit anti-goals: no selling anonymized data, no dark-pattern paywalls on the user's own data (export is always free), no interchange-driven push of a Lumen card before product-market fit.

## Competitive Positioning

| | Mint (RIP) | YNAB | Copilot | Monarch | **Lumen** |
|--|-----------|------|---------|---------|-----------|
| Auto tracking | ✅ | partial | ✅ | ✅ | ✅ |
| File import (CSV/PDF) | weak | CSV | weak | CSV | **CSV/XLSX/PDF/OFX with AI mapping** |
| Proactive detection | ads-driven | ❌ | some | some | **core product** |
| Explainable AI categorization | ❌ | n/a | partial | partial | ✅ |
| Forecasting & coaching | ❌ | manual | partial | partial | ✅ |
| Business model | ads/data | sub | sub | sub | sub |

**One-line positioning:** *Lumen is the finance app that watches your money so you don't have to.*
