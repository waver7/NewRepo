# Lumen Finance 💡

**The personal finance app that thinks for you.**

Lumen automatically tracks, organizes, and analyzes every transaction across all of a user's
bank accounts, credit cards, and financial institutions — then turns that data into clear,
actionable insight: where money goes, what's recurring, what's unusual, and how to hit your goals faster.

This repository contains the complete product and engineering design for Lumen, covering
vision, features, UX, data model, backend architecture, AI systems, security, and roadmap.

## Document Index

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [Product Vision](docs/01-product-vision.md) | Mission, positioning, target users, principles, monetization |
| 2 | [Complete Feature List](docs/02-feature-list.md) | Every feature, grouped by domain, with priority tiers |
| 3 | [User Flows](docs/03-user-flows.md) | Onboarding, linking, importing, budgeting, goal flows |
| 4 | [Mobile App Screens](docs/04-app-screens.md) | Full screen inventory with layout and interaction specs |
| 5 | [Database Schema](docs/05-database-schema.md) | PostgreSQL schema (DDL) for all core entities |
| 6 | [Backend Architecture](docs/06-backend-architecture.md) | Services, pipelines, queues, infra, scaling |
| 7 | [AI Categorization Logic](docs/07-ai-categorization.md) | Multi-stage categorization engine + dedup logic |
| 8 | [Security Model](docs/08-security-model.md) | Auth, encryption, secrets, compliance, threat model |
| 9 | [Bank Connection Strategy](docs/09-bank-connections.md) | Plaid/MX/Finicity abstraction, webhooks, fallbacks |
| 10 | [File Upload / Import Strategy](docs/10-file-import.md) | CSV/Excel/PDF/OFX parsing, column mapping, AI extraction |
| 11 | [Subscription & Bill Detection](docs/11-subscription-detection.md) | Recurring-pattern detection algorithm |
| 12 | [Savings & Goals System](docs/12-goals-system.md) | Savings, debt payoff, emergency fund, spending limits |
| 13 | [MVP Version](docs/13-mvp.md) | Scoped v1 — what ships first and why |
| 14 | [Advanced Version](docs/14-advanced-version.md) | The full "best in the world" build-out |
| 15 | [Tech Stack](docs/15-tech-stack.md) | Recommended stack with rationale and alternatives |
| 16 | [Roadmap](docs/16-roadmap.md) | Phased 18-month delivery plan |
| 17 | [Beyond the Brief](docs/17-beyond-ideas.md) | Ideas that make Lumen category-defining |

## The Pitch in 30 Seconds

Most finance apps are **ledgers** — they show you what happened. Lumen is a **copilot**:

- **Zero-effort tracking.** Connect accounts once (Plaid/MX/Finicity), or drop in a CSV/PDF —
  Lumen ingests, deduplicates, and categorizes everything automatically with >95% accuracy.
- **It notices things.** Forgotten free trials, a subscription that quietly raised its price,
  a duplicate charge, a bill due in 3 days against a low balance, spending 40% above your norm.
- **It coaches.** Savings rate, safe-to-spend, goal forecasting ("at this pace you'll hit your
  emergency fund in March — move $40/week more and make it January").
- **It's trustworthy.** Read-only bank access, no credential storage, field-level encryption,
  biometric lock, and a business model that never sells user data.

## Core KPIs

| Metric | Target |
|--------|--------|
| Auto-categorization accuracy | ≥ 95% (after personalization) |
| Time from signup → first insight | < 3 minutes |
| Duplicate detection precision | ≥ 99% |
| Recurring detection recall | ≥ 90% of true subscriptions |
| D30 retention | ≥ 40% |
| Free → paid conversion | 5–8% |
