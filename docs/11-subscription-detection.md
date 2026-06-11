# 11. Subscription & Recurring Bill Detection

Detect every recurring money flow — subscriptions, bills, income, transfers — with high
recall, then let one-tap user feedback drive precision. This powers the Subscription Hub,
bill calendar, cash-flow forecasting, and price-change/forgotten-subscription alerts.

## 11.1 Algorithm Overview

Runs incrementally on new transactions + a nightly per-user batch.

### Step 1 — Group candidate series
Group a user's transactions by `(merchant_id, account_id, sign)`; when merchant resolution
failed, fall back to clustering normalized descriptors (trigram similarity ≥ 0.85).
Variable-amount merchants (utilities) stay in one group; multi-product merchants
(two different Amazon subscriptions) are sub-split by amount clustering (±10% bands).

### Step 2 — Score periodicity
For each group with ≥2 occurrences, compute the gap sequence between charge dates and test
against known cadences (tolerances absorb weekends/holidays/posting lag):

| Cadence | Expected gap | Tolerance |
|---------|-------------|-----------|
| Weekly | 7d | ±2d |
| Biweekly | 14d | ±3d |
| Semi-monthly | 15.2d avg (1st/15th pattern) | day-of-month match |
| Monthly | 29–31d | ±4d, or same day-of-month ±3 |
| Quarterly | 91d | ±7d |
| Yearly | 365d | ±15d |

```
periodicity_score = matching_gaps / total_gaps          (regularity)
amount_score      = 1 − min(1, coeff_of_variation(amounts) / 0.5)
count_score       = min(1, (occurrences − 1) / 3)        (3+ gaps ≈ certainty)

confidence = 0.5·periodicity + 0.3·amount + 0.2·count
```

### Step 3 — Classify and prior-boost
- **Known-subscription merchant list** (Netflix, Spotify, gyms, SaaS, insurers, telecoms —
  a curated global table): confidence boost +0.2 and detection allowed at **just 2
  occurrences** (or even 1 for unambiguous merchants like Netflix at a standard plan price).
- Classify `kind`: positive amounts → income (paycheck detection: employer descriptor,
  biweekly/semimonthly, large stable amount); transfer-flagged → transfer; fixed-amount
  consumer merchant → subscription; variable-amount essential category → bill.

### Step 4 — Thresholds
- confidence ≥ 0.8 → auto-create `recurring_series`, tag member transactions.
- 0.5–0.8 → shown in Subscription Hub under "Is this recurring?" with one-tap Yes/No;
  the answer is stored (`user_confirmed`) and used as a global prior signal.
- < 0.5 → ignored, re-evaluated as occurrences accumulate.

### Step 5 — Maintain
On every new matching charge: update `last_seen`, `occurrences`, learned `interval_days`,
re-predict `next_expected_date` and `next_expected_amount` (variable bills: seasonal
estimate from same-month-last-year blended with trailing mean).

## 11.2 Derived Detections

| Detection | Logic | User-facing result |
|-----------|-------|--------------------|
| **Price increase** | new amount > typical by >2% and > $0.50, sustained (not a one-off) | "Spotify went $10.99 → $11.99 (+9%)" + yearly impact |
| **New subscription** | first auto-created series, kind=subscription | "New subscription detected: Audible $14.95/mo" |
| **Free-trial conversion risk** | $0/`$1` auth at known-trial merchant → timer | "Your Paramount+ trial likely converts ~Mar 14" |
| **Forgotten / unused** | subscription active ≥4 months + low engagement signal (user never opens its insights, or service in 'rarely used' user answer) → periodic check-in | "Still using Crunchyroll? $7.99/mo, $96/yr" |
| **Missed bill** | `next_expected_date` passed by > tolerance with no charge | "Your gym didn't charge this month — canceled, or card declined?" |
| **Canceled-but-still-charging** | user marked canceled, new charge matches series | high-severity alert |
| **Duplicate subscription** | two active series in same service category (e.g. two music streaming) | "You pay for both Spotify and Apple Music ($23/mo)" |
| **Upcoming bills & risk** | next 7 days of `next_expected_*` vs projected balance | bill calendar + low-balance warning (doc 3 §3.10) |

## 11.3 Honest Failure Modes & Mitigations

- **Erratic posting dates** (annual charges drifting, monthly on "last business day"):
  day-of-month matching + wide yearly tolerance.
- **Merchant descriptor changes** ("NETFLIX.COM" → "Netflix US LLC"): series keyed on
  merchant_id; alias table absorbs descriptor churn; orphaned series re-linked by
  amount+cadence match.
- **Shared merchants** (Amazon = shopping + Prime + AWS): amount-band sub-splitting +
  known-product price tables for major services.
- **User edits are ground truth:** "not recurring" dismissals are remembered forever;
  user-confirmed series never silently disappear.

## 11.4 Cancellation Assistance

Per-merchant cancellation playbook table (deep link, web URL, phone, required notice,
difficulty rating), community-maintained + curated. Plus tier shows instructions;
Premium offers concierge cancellation via partner. After "marked canceled," the series is
monitored — if it charges again, the user gets the high-severity alert above. We measure and
display **"Lumen has saved you $X/yr"** from confirmed cancellations — the single best
retention/conversion stat in the app.
