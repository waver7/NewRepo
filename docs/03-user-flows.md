# 3. User Flows

## 3.1 Onboarding (signup → first insight in < 3 minutes)

```
Launch
 └─ Welcome carousel (3 cards: "See everything", "Catch waste", "Hit goals")
     └─ Sign up: Apple / Google / email+password
         └─ Enable biometric lock (recommended, one tap)
             └─ "How do you want to start?"
                 ├─ A) Connect a bank  → Plaid Link flow (3.2)
                 ├─ B) Upload a file   → Import flow (3.4)
                 ├─ C) Add manually    → Quick-add sheet (3.5)
                 └─ D) Explore demo    → Full app with sample data, persistent
                                          "Connect your own accounts" banner
                     └─ (after A/B/C) Ingestion progress screen with live counts:
                        "Imported 1,243 transactions · Categorized 1,201 · Found 9 subscriptions"
                         └─ FIRST INSIGHT SCREEN (the aha moment):
                            "You spend ~$612/mo on food · 9 subscriptions cost $134/mo
                             · Your savings rate last month was 11%"
                             └─ Prompt: set one goal (optional) → Home dashboard
```

Design notes:
- Never ask for budgets/categories up front — show value first, configure later.
- Notification permission is requested *after* the first insight, framed by value
  ("Want to know when a bill is due or something looks off?").
- Each onboarding step is skippable; demo mode removes all risk from trying the app.

## 3.2 Connect a Bank Account

```
"Add account" → search institution (typeahead, logos)
 └─ Aggregator chosen automatically per institution (Plaid default)
     └─ Plaid Link opens (OAuth redirect to bank, or credentials inside Plaid's UI —
        Lumen never sees credentials)
         └─ User selects which accounts to share (checking, cards…)
             └─ Success → "Syncing… usually under a minute"
                 └─ Background: historical backfill (24 mo) → categorize → dedup →
                    recurring scan → push "Your Chase account is ready ✓"
Failure paths:
 - Institution unsupported on Plaid → auto-retry on MX/Finicity → else suggest file import
 - MFA/re-auth needed later → red badge on account + push "Chase needs you to reconnect (30s)"
```

## 3.3 Daily Use (the 20-second loop)

```
Open app → Face ID → Home
 ├─ Glance: Safe-to-spend $418 · Net flow +$230 · 2 attention items
 ├─ Attention card: "Hulu raised its price $2 → [See details] [Dismiss]"
 ├─ Swipe new uncategorized txn (rare): choose category → "Always do this? [Yes]"
 └─ Done.
```

## 3.4 File Import

```
"Import file" → pick source (Files / Drive / share-sheet from any app)
 └─ Detect type:
     ├─ CSV/XLSX → parse → AI column mapping ("Date=col A, Amount=col D, negative=expense")
     │             └─ Preview table (first 10 rows, mapped) → user confirms/adjusts
     │                 └─ Saved as a template for this bank ("Chase checking CSV")
     ├─ OFX/QFX  → parsed natively, no mapping needed
     └─ PDF      → text extraction (or OCR if scanned) → LLM transaction extraction
                   └─ Preview with per-row confidence; low-confidence rows highlighted for review
         └─ Choose target account (existing or "create new manual account")
             └─ Dedup pass: "1,032 new · 211 already known (skipped) · 3 need your review"
                 └─ Review screen for ambiguous duplicates (side-by-side, Keep both / Merge)
                     └─ Import complete → categorization + recurring scan run → summary
```

## 3.5 Manual Transaction

```
"+" anywhere → Quick-add sheet
 └─ Amount (big keypad) → merchant (typeahead w/ logos) → category auto-suggested
    → date (default today) → account → optional: note, tags, receipt photo
     └─ Save (works offline; queued for sync)
```

## 3.6 Fix a Wrong Category

```
Transaction row → tap category chip → category picker (recent + search)
 └─ Pick "Coffee Shops"
     └─ Toast: "Always categorize Blue Bottle as Coffee Shops? [Always] [Just this once]"
         └─ "Always" → personal rule created → retroactively applied to 14 past txns
            (undoable from the rule's detail screen)
```

## 3.7 Create a Savings Goal

```
Goals tab → "New goal" → type: Savings / Emergency fund / Debt payoff / Spending limit
 └─ Savings: name + emoji, target $, target date (either optional)
     └─ Link a funding account (progress = account balance) OR track contributions manually
         └─ Lumen computes required pace: "$208/mo to hit June 2027"
             └─ Feasibility check vs. current savings rate:
                "Doable — you averaged $310/mo saved. Want alerts if you fall behind?" → Done
```

## 3.8 Debt Payoff Plan

```
New goal → Debt payoff → select liability accounts (cards/loans w/ APRs)
 └─ Choose strategy: Avalanche (highest APR first) / Snowball (smallest first) — with
    plain-language explanation and projected interest difference between them
     └─ Set monthly payment budget → plan generated:
        order of payoff, debt-free date, total interest saved vs. minimums
         └─ Monthly check-in notification: "You paid $640 toward debt — 2 months ahead of plan"
```

## 3.9 Subscription Review (monthly ritual)

```
Push: "Your February subscription report is ready"
 └─ Subscription hub: total $/mo, sorted list, changes highlighted
     ├─ NEW: "Audible $14.95 — started Feb 3" → [Keep] [Help me cancel]
     ├─ PRICE ↑: "Spotify $10.99 → $11.99"
     └─ UNUSED?: "You've paid for Crunchyroll 6 months; want to keep it?"
         └─ "Help me cancel" → cancellation page deep-link + step-by-step instructions
            (Premium: concierge does it) → mark as canceled → watch for further charges,
            alert if it charges again
```

## 3.10 Bill-Risk Alert (proactive save)

```
Background job: upcoming bills (next 7 days) vs. current + projected balance
 └─ Risk detected → push: "Heads up: $1,450 rent hits ~Mar 1, projected balance $1,180"
     └─ Open → cash-flow screen: timeline of inflows/outflows, shortfall highlighted
         └─ Suggestions: "Move $300 from savings" / "Your paycheck usually lands Feb 28 —
            this may resolve itself; we'll re-check tomorrow"
```

## 3.11 Re-authentication (connection broken)

```
Webhook: ITEM_LOGIN_REQUIRED → account badged "Needs attention" + gentle push (max 1/day)
 └─ Tap → Plaid update-mode Link (usually 2 taps) → resync → badge cleared
     └─ If ignored 7 days → weekly digest notes: "Chase data is 9 days stale"
```

## 3.12 Cancel / Delete Account

```
Settings → "Delete my account" → explain consequences → export offer ("Download everything first?")
 └─ Confirm w/ biometric → aggregator tokens revoked (Plaid /item/remove) →
    all data hard-deleted within 24h (backups purged within 30 days) → confirmation email
```
