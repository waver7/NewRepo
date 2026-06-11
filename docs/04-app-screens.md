# 4. Mobile App Screens

Five-tab structure: **Home · Transactions · Plan · Insights · Accounts** (+ a floating "+" quick-add).
Design language: generous whitespace, one accent color (electric indigo) on a neutral base,
large rounded cards, big numerals for money, every chart tappable to drill in. Dark mode native.

## 4.1 Home (Dashboard)

The "Am I OK?" screen — answerable in 5 seconds.

```
┌──────────────────────────────────┐
│ Good morning, Sam        🔔 (2)  │
│                                  │
│  SAFE TO SPEND THIS WEEK         │
│  $418                            │  ← hero number, tap → how it's computed
│  ▓▓▓▓▓▓▓░░░  on track            │
│                                  │
│ ┌ Needs attention ─────────────┐ │
│ │ ⚠ Hulu price ↑ $2/mo         │ │  ← horizontally swipeable alert cards
│ │ 📅 Rent $1,450 due in 3 days │ │
│ └──────────────────────────────┘ │
│                                  │
│ March so far                     │
│ In $4,120 · Out $2,890 · +$1,230 │
│ [mini cash-flow bar chart]       │
│                                  │
│ Top categories     vs Feb        │
│ 🍔 Food        $612   ↑12%       │
│ 🚗 Transport   $240   ↓ 8%       │
│ 🛍 Shopping    $310   ↑41% ⚠     │
│                                  │
│ Goals    🏠 House fund 64% ▓▓▓░  │
│                                  │
│ Recent transactions (5) → See all│
└──────────────────────────────────┘
```

## 4.2 Transactions

- Infinite list grouped by day; each row: merchant logo, clean name, category chip,
  account icon, amount (green for income), pending state (italic).
- Sticky search bar: full-text + filter chips (account, category, date range, amount range,
  tags, "uncategorized", "recurring only"). P2: natural-language search.
- Swipe right → recategorize; swipe left → split / add note / hide.
- A thin "Needs review" banner appears only when something requires input
  (low-confidence categorization, possible duplicate).

**Transaction Detail:** big amount + merchant header (logo, location map if available),
category (tap to change), account, date/time, status, original raw descriptor
("CHASE: SQ *BLUEBTL…"), notes, tags, receipt photos, split editor, "Why this category?"
explainer, similar-transactions list ("12 from this merchant this year, $87 total"),
recurring linkage ("part of your Spotify subscription").

## 4.3 Plan (Budgets + Goals + Bills)

Three segments:

1. **Budget** — monthly category limits as progress bars (spent/limit, color shifts at
   75/90/100%), "Auto-set from my history" button, safe-to-spend math expander.
2. **Goals** — cards per goal: emoji, progress ring, amount, ETA ("on pace for June"),
   behind-pace nudge. Detail screen: contribution history chart, pace editor,
   what-if slider ("+$25/wk → 2 months sooner").
3. **Bills & Subscriptions** — calendar strip of upcoming charges; subscription hub list
   (monthly total headline, per-item: logo, price, cadence, next date, price-change badge,
   "unused?" badge); detail screen with charge history chart + cancel assistance.

## 4.4 Insights

- **Cash flow** — income vs expenses bars (12 mo), savings-rate line overlay.
- **Categories** — donut + ranked list, tap into a category → monthly trend, top merchants,
  every transaction.
- **Merchants** — ranked spend per merchant with visit counts ("Starbucks: 14 visits, $73").
- **Cards & accounts** — spend per card (credit vs debit split), fees paid per account.
- **Net worth** (P2) — assets vs liabilities stacked area chart.
- **Forecast** (P2) — 30/60/90-day projected balance line w/ known bills marked; shortfall
  windows shaded red.
- **Monthly report** — auto-generated narrative summary ("You spent $3,012 in March, 4% less
  than February…"), shareable as PDF.

## 4.5 Accounts

- Net summary header (cash − card balances; full net worth in P2).
- Sections: Cash, Credit cards, Savings, Investments, Loans, Manual.
- Each row: institution logo, masked number (••4421), balance, sync freshness dot,
  "needs attention" badge for broken connections.
- Account detail: balance history chart, account-only transaction list, connection
  management (refresh now, pause, unlink), per-account fee report.
- "Add account" hub: Connect a bank / Import a file / Create manual account.

## 4.6 Quick Add (floating "+")

Bottom sheet, optimized for ≤5 seconds: keypad-first amount → merchant typeahead →
auto-suggested category → save. Secondary: full form (date, account, tags, note, receipt photo).

## 4.7 AI Advisor (Premium, P2)

Chat screen with suggested prompts ("How much did I spend on travel this year?",
"Can I afford a $1,400 flight in May?"). Answers render inline mini-charts and cite the
underlying transactions; every number is tappable to verify. Clear disclaimer footer
(informational, not licensed financial advice).

## 4.8 Notifications Center

Chronological feed of all alerts (large txn, bill due, anomaly, price change, weekly digest),
each deep-linking to its evidence. Per-type toggles + quiet hours in settings.

## 4.9 Settings & Security

Profile, subscription/billing, linked institutions, notification preferences,
security (biometric lock, PIN, privacy-blur toggle, active sessions), rules manager
(every auto-rule listed, editable, with "applied to N transactions"), categories editor
(rename/add/merge, custom emojis), currencies (home currency, display preferences),
data (export everything, delete account), help & support.

## 4.10 Widgets & Watch

- **iOS/Android widgets:** Safe-to-spend (small), Month summary in/out (medium),
  Upcoming bills (medium), Goal progress ring (small).
- **Watch app (P2):** safe-to-spend glance + quick-add by voice ("$14 lunch").

## 4.11 Empty/Edge States

Every screen has a designed empty state with one clear CTA (e.g., Transactions empty →
"Connect a bank or import a file"). Skeleton loaders during sync; offline banner with
cached-data timestamp; error states always offer a retry and a fallback path
(bank link fails → "Try importing a statement instead").
