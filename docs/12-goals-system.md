# 12. Savings & Goals System

Four goal types, one engine: every goal has a **target**, a **measured progress source**,
a **computed pace**, and a **feasibility check against real cash flow**. Goals are never
just thermometers — they forecast, nudge, and adapt.

## 12.1 Savings Goal

- **Setup:** name + emoji, target amount, optional target date, currency.
- **Progress source (two modes):**
  - *Linked mode:* progress = balance of linked account(s) (optionally minus a baseline,
    "count only growth from today"). Zero manual work.
  - *Tracked mode:* user logs contributions, or a rule auto-counts matching transfers
    ("any transfer to Marcus ••8821 counts toward House Fund").
- **Math:** `required_monthly = (target − current) / months_remaining`;
  `eta = today + (target − current) / trailing_3mo_contribution_rate`.
- **Feasibility:** compared against the user's actual savings rate —
  *"You need $208/mo; you've averaged $310/mo saved. Doable."* If required pace > realistic
  capacity (savings rate + slack from non-essential categories), say so honestly and offer:
  extend date, lower target, or show where the money could come from
  ("$95/mo of your delivery spend would close the gap").
- **Nudges:** behind-pace alert (monthly, gentle), milestone celebrations (25/50/75/100%),
  what-if slider ("+$25/wk → done 2 months sooner").

## 12.2 Emergency Fund Goal

A specialized savings goal where **Lumen computes the target**:

```
essential_monthly = trailing-6-month average spend across is_essential categories
                    (rent, utilities, groceries, insurance, minimum debt payments, transport)
target = months_chosen (default 3, slider 1–12) × essential_monthly
```

- Target **auto-adjusts** as the user's essential spending changes (with notification:
  "Your rent went up, so your 3-month fund target moved to $9,600").
- Education layer: why 3–6 months, what counts as essential (editable).
- Priority logic: if no emergency fund exists, goal creation suggests starting one first.

## 12.3 Debt Payoff Goal

- **Setup:** select liability accounts (credit cards/loans; balances + APRs from
  aggregator or entered manually), set a monthly debt budget.
- **Strategies, explained in plain language with real numbers:**
  - *Avalanche* (highest APR first): "saves you $412 in interest"
  - *Snowball* (smallest balance first): "first card gone in 3 months — best if momentum
    keeps you going"
  - Side-by-side comparison; user picks; plan generates the payoff order and a month-by-month
    amortization schedule → **debt-free date** + **total interest saved vs. minimums**.
- **Automatic progress:** credit-card payment transactions (detected by the transfer
  matcher, doc 7 §7.3) count toward the plan without any logging. Balance syncs reconcile
  reality vs. plan monthly: "You're 2 months ahead" / "New spending on the Visa added
  $340 — updated payoff date: October."
- **Guardrails:** warns when new spending on a card outpaces the payoff plan; celebrates
  every account hitting zero (the single most motivating event in the app — make it big).

## 12.4 Spending Limits (budgets)

- Per-category monthly/weekly limits; progress bars with **pace awareness** — alert at
  75%/90%/100% *and* "on day 10 you've used 60% of your dining budget" (pace > calendar).
- **Auto-budget:** one tap builds a complete budget from 3-month median spending per
  category, gently shaved (−5%) on non-essentials. Editable, of course.
- Optional **rollover** (unused budget carries forward) for envelope-style users.
- Limits integrate with Safe-to-Spend (below) rather than living in a silo.

## 12.5 Safe-to-Spend (the unifying number)

The home-screen hero metric that makes all goals real:

```
safe_to_spend_this_week =
    expected_income_remaining_this_month
  + current_liquid_balances
  − upcoming_bills (recurring_series predictions, rest of month)
  − planned_goal_contributions (all active goals' monthly pace)
  − essential_spend_remaining (estimated from baseline)
  ───────────────────────────────────────────────
  ÷ weeks remaining in month
```

Tappable breakdown shows every term. This converts abstract goals into a daily-felt
constraint — the behavioral core of the product.

## 12.6 Engagement Mechanics (calm, not casino)

- Weekly digest includes one goal sentence max ("House fund: 64%, on pace for June").
- Milestones use celebration, never shame; falling behind gets *options*, not red badges.
- Round-up accumulator (P2): virtual round-ups tallied per goal → "your spare change this
  month: $23" → one-tap real transfer when money movement ships.
- Shared goals (P2): two users fund one goal (couples saving for a house) with both
  contribution streams visible.
