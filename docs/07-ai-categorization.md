# 7. AI Categorization Logic

Goal: **≥95% accuracy after personalization**, every prediction explainable, every
correction learned from — at a marginal cost near zero for the vast majority of transactions.

## 7.1 Category Taxonomy

Two-level system taxonomy (~14 top-level, ~55 leaf), plus user-defined categories.

```
Income:      Salary · Freelance · Interest & Dividends · Refunds · Other income
Housing:     Rent · Mortgage · Home maintenance · Property tax
Utilities:   Electricity · Gas · Water · Internet · Mobile phone · Trash
Food:        Groceries · Restaurants · Coffee shops · Delivery & takeout · Bars
Transport:   Gas/Fuel · Public transit · Rideshare · Parking · Car payment · Car insurance · Maintenance
Health:      Insurance · Pharmacy · Doctor & dental · Fitness
Shopping:    Clothing · Electronics · Home goods · Online marketplaces · Gifts
Entertainment: Streaming · Games · Events & movies · Hobbies · Books & music
Subscriptions: Software & apps · Memberships · News & media
Travel:      Flights · Hotels · Vacation rentals · Travel other
Family:      Childcare · Education · Pets · Kids
Financial:   Bank fees · ATM/FX fees · Loan payment · Credit card payment · Investments · Taxes
Personal:    Beauty & grooming · Laundry · Charity · Cash withdrawal
Transfers:   Internal transfer · P2P (Venmo/Zelle) — excluded from income/expense math
```

`is_essential` flags (rent, utilities, groceries, insurance, minimum debt payments…) feed
emergency-fund sizing and "needs vs wants" analytics.

## 7.2 The Five-Stage Cascade

Cheapest and most reliable signal wins; each stage only runs if the previous one didn't
produce a confident answer.

```
incoming transaction
  │
  ├─ STAGE 0 · Normalize descriptor
  │    uppercase → strip store #, dates, card suffixes, processor prefixes
  │    ("SQ *", "TST*", "PAYPAL *", "AMZN Mktp"), collapse whitespace
  │    "SQ *BLUEBTL COFFEE 4421 OAK" → "BLUEBTL COFFEE"
  │
  ├─ STAGE 1 · User rules & personal history          (~30–60% of volume, cost ≈ 0)
  │    a) user_rules engine (priority-ordered, first match wins)
  │    b) exact personal precedent: this user + same normalized descriptor
  │       → reuse their last category. confidence 0.99 · source 'user_rule'
  │
  ├─ STAGE 2 · Global merchant database               (~30–50% of volume)
  │    alias-pattern match → merchants.default_category
  │    + aggregator hints (Plaid personal_finance_category, MCC code) as tiebreakers
  │    confidence 0.90–0.97 · source 'merchant_db'
  │
  ├─ STAGE 3 · ML classifier                          (~5–15% of volume)
  │    Lightweight model (fastText/DistilBERT-class) over:
  │      normalized descriptor tokens + char n-grams, amount bucket, sign,
  │      MCC, account type, day-of-month, user's category prior
  │    Trained on global corpus + millions of category_corrections.
  │    accept if p ≥ 0.85 · source 'ml'
  │
  ├─ STAGE 4 · LLM fallback                           (~1–5% of volume)
  │    Batched calls (up to 50 txns/request) to a small model (Claude Haiku class):
  │    constrained JSON output {category_slug, merchant_guess, confidence, reason}
  │    against the fixed taxonomy. Results cached globally by normalized descriptor —
  │    each weird descriptor costs one LLM call *ever*, across all users.
  │    accept if confidence ≥ 0.7 · source 'llm'
  │
  └─ STAGE 5 · Needs review
       category = best guess, needs_review = true → appears in the app's
       "needs review" banner; user's answer becomes a personal precedent (→ Stage 1)
       and a labeled training example.
```

### Explainability
Every transaction stores `category_source` + `category_confidence`; the detail screen
renders it: *"Categorized as Coffee Shops because you always categorize Blue Bottle this
way"* / *"…because this merchant is a known grocery chain."*

### The Learning Loop
1. User corrects a category → `category_corrections` row written.
2. Instant: offer "Always?" → creates an `auto_from_correction` user rule, retroactively
   applied (with undo).
3. If ≥3 distinct users make the same correction for the same merchant → flag for global
   merchant-DB update (human-reviewed initially, automatic once trusted).
4. Weekly: corrections feed the next classifier training run; shadow-evaluate, promote only
   if accuracy improves on a held-out set.

### Privacy boundary
The global merchant DB and shared LLM cache contain only **merchant-level** facts
(descriptor patterns → merchant → category) — never amounts, balances, or anything tying a
pattern to a user. Per-user learning stays in that user's rules/precedents.

## 7.3 Transfer Detection

Transfers must not pollute income/expense math.

1. **Pair matching:** opposite-sign amounts (within FX/fee tolerance), different accounts,
   same user, within ±3 days, descriptor hints ("TRANSFER", "PAYMENT THANK YOU",
   "ZELLE TO…") → link both legs, `is_transfer = true`.
2. **Credit-card payments:** checking outflow matched to card inflow → categorized
   "Credit card payment", excluded from spending, but *counted* in debt-payoff progress.
3. **Single-leg transfers** (external savings not linked): descriptor + merchant heuristics;
   ambiguous cases asked once ("Is 'VANGUARD BUY' a transfer to your own investments?") and
   remembered.

## 7.4 Duplicate Detection (cross-source)

The hard case: the same real-world transaction arriving via bank link **and** a CSV/PDF
import **and/or** manual entry.

**Fingerprint (exact tier):**
```
fp = sha256(account_id · amount_minor_units · posted_date · normalized_descriptor_prefix(12))
```
Same fingerprint ⇒ duplicate, auto-skip (provider_txn_id uniqueness handles aggregator
re-sends even earlier).

**Fuzzy tier** — candidate pairs scored when fingerprints differ:

| Signal | Weight | Notes |
|--------|-------:|-------|
| Amount exact match | 0.40 | required (after currency normalization) |
| Date distance | 0.25 | full at same day, decaying to 0 at ±4 days (statement vs posted-date skew) |
| Descriptor trigram similarity | 0.20 | "STARBUCKS #1234" vs "Starbucks Store 1234" |
| Same account (or imported file targeted at that account) | 0.10 | |
| Source differs (link vs import) | 0.05 | imports overlap links constantly |

- score ≥ 0.85 → auto-merge (keep the richer record — usually the aggregator one — and
  remember the import row as consumed)
- 0.60–0.85 → "3 need your review" side-by-side UI
- < 0.60 → distinct

**Pending→posted:** pending txns are matched to their posted version (same account, similar
amount/descriptor, ≤7 days) and superseded via `superseded_by` — never double-counted.

**Same-merchant-same-day legit duplicates** (two identical coffees): same-source identical
pairs are kept but trigger a *duplicate-charge insight* ("Charged twice by Shell within
2 minutes — possible error?") rather than silent merging.

## 7.5 Anomaly Detection (unusual spending)

Per user, nightly + on-ingest:
- **Merchant-level:** amount z-score vs. that user's history with the merchant
  (≥5 priors) — "Your electric bill is $212, usually ~$95."
- **Category-level:** month-to-date pace vs. seasonal baseline (same month last year
  blended with trailing 3-month mean) — "Shopping is 41% above your typical March."
- **New-payee large debits:** first-ever merchant + amount > user's p95 → notable.
- **Fee radar:** known fee descriptors (OD fee, ATM, FX surcharge) → monthly fee report.
- Severity gates so users see at most a handful of high-quality anomalies per month —
  precision over recall; every alert has one-tap "expected, don't warn again" feedback that
  tunes thresholds.

## 7.6 AI Advisor (Premium)

LLM chat grounded by **tool calls against the user's own aggregates** (the model queries
`monthly_category_spend`, goals, recurring series — it is never handed the raw full ledger).
Every numeric claim in an answer links to the underlying query result so the user can verify.
Guardrails: no specific investment/tax/legal advice; clearly labeled as informational;
prompt-injection-resistant (merchant names and notes are treated as data, never instructions).
