# 5. Database Schema (PostgreSQL)

Conventions: UUID v7 primary keys (time-ordered), `timestamptz` everywhere, soft deletes via
`deleted_at` on user-facing entities, money as `NUMERIC(18,4)` plus ISO-4217 currency code
(never floats), multi-tenancy by `user_id` with row-level security enabled.

```sql
-- ============ IDENTITY ============

CREATE TABLE users (
    id                  UUID PRIMARY KEY,
    email               CITEXT UNIQUE NOT NULL,
    auth_provider       TEXT NOT NULL DEFAULT 'password',   -- password|apple|google
    password_hash       TEXT,                               -- argon2id; NULL for social auth
    mfa_secret_enc      BYTEA,                              -- encrypted TOTP seed
    home_currency       CHAR(3) NOT NULL DEFAULT 'USD',
    locale              TEXT NOT NULL DEFAULT 'en-US',
    tier                TEXT NOT NULL DEFAULT 'free',       -- free|plus|premium
    onboarded_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

CREATE TABLE devices (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    platform        TEXT NOT NULL,              -- ios|android|web
    push_token      TEXT,
    biometric_on    BOOLEAN NOT NULL DEFAULT false,
    last_seen_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ AGGREGATION / ACCOUNTS ============

-- One linked login at one institution via one aggregator (a Plaid "Item")
CREATE TABLE connections (
    id                   UUID PRIMARY KEY,
    user_id              UUID NOT NULL REFERENCES users(id),
    provider             TEXT NOT NULL,          -- plaid|mx|finicity|truelayer
    provider_item_id     TEXT NOT NULL,
    access_token_ref     TEXT NOT NULL,          -- pointer into vault/KMS, NEVER the token
    institution_id       TEXT NOT NULL,
    institution_name     TEXT NOT NULL,
    institution_logo_url TEXT,
    status               TEXT NOT NULL DEFAULT 'active', -- active|login_required|error|paused|revoked
    last_synced_at       TIMESTAMPTZ,
    error_code           TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at           TIMESTAMPTZ,
    UNIQUE (provider, provider_item_id)
);

CREATE TABLE accounts (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id),
    connection_id       UUID REFERENCES connections(id),    -- NULL ⇒ manual/imported account
    provider_account_id TEXT,
    name                TEXT NOT NULL,                      -- "Chase Freedom"
    nickname            TEXT,
    type                TEXT NOT NULL,   -- checking|savings|credit_card|investment|loan|mortgage|cash|other
    subtype             TEXT,
    mask                TEXT,                               -- "4421"
    currency            CHAR(3) NOT NULL DEFAULT 'USD',
    current_balance     NUMERIC(18,4),
    available_balance   NUMERIC(18,4),
    credit_limit        NUMERIC(18,4),
    apr                 NUMERIC(7,4),                       -- for debt planning
    is_hidden           BOOLEAN NOT NULL DEFAULT false,     -- excluded from analytics
    balance_as_of       TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

CREATE TABLE balance_snapshots (         -- daily, powers balance/net-worth charts & forecasting
    account_id      UUID NOT NULL REFERENCES accounts(id),
    as_of_date      DATE NOT NULL,
    balance         NUMERIC(18,4) NOT NULL,
    currency        CHAR(3) NOT NULL,
    PRIMARY KEY (account_id, as_of_date)
);

-- ============ CATEGORIES ============

CREATE TABLE categories (
    id              UUID PRIMARY KEY,
    user_id         UUID REFERENCES users(id),  -- NULL ⇒ system category
    parent_id       UUID REFERENCES categories(id),
    slug            TEXT NOT NULL,              -- 'food.groceries'
    name            TEXT NOT NULL,
    emoji           TEXT,
    kind            TEXT NOT NULL DEFAULT 'expense',  -- expense|income|transfer
    is_essential    BOOLEAN NOT NULL DEFAULT false,   -- feeds emergency-fund sizing
    sort_order      INT NOT NULL DEFAULT 0,
    UNIQUE (user_id, slug)
);

CREATE TABLE merchants (                 -- global, shared enrichment table
    id              UUID PRIMARY KEY,
    canonical_name  TEXT NOT NULL,       -- "Blue Bottle Coffee"
    website         TEXT,
    logo_url        TEXT,
    default_category_id UUID REFERENCES categories(id),
    mcc             TEXT
);

CREATE TABLE merchant_aliases (          -- raw descriptor patterns → merchant
    id              UUID PRIMARY KEY,
    merchant_id     UUID NOT NULL REFERENCES merchants(id),
    pattern         TEXT NOT NULL,       -- normalized prefix/regex: 'SQ *BLUEBTL%'
    confidence      REAL NOT NULL DEFAULT 1.0
);
CREATE INDEX ON merchant_aliases (pattern text_pattern_ops);

-- ============ TRANSACTIONS ============

CREATE TABLE transactions (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id),
    account_id          UUID NOT NULL REFERENCES accounts(id),
    source              TEXT NOT NULL,          -- aggregator|file_import|manual|email
    provider_txn_id     TEXT,                   -- aggregator's stable id
    import_batch_id     UUID REFERENCES import_batches(id),

    amount              NUMERIC(18,4) NOT NULL, -- negative = outflow (normalized at ingest)
    currency            CHAR(3) NOT NULL,
    amount_home         NUMERIC(18,4),          -- converted at txn-date FX rate
    posted_date         DATE NOT NULL,
    authorized_at       TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'posted',     -- pending|posted|removed

    raw_description     TEXT NOT NULL,          -- exactly as received, immutable
    merchant_id         UUID REFERENCES merchants(id),
    display_name        TEXT NOT NULL,          -- cleaned name shown in UI

    category_id         UUID REFERENCES categories(id),
    category_source     TEXT,        -- rule|merchant_db|ml|llm|user|user_rule
    category_confidence REAL,
    needs_review        BOOLEAN NOT NULL DEFAULT false,

    is_transfer         BOOLEAN NOT NULL DEFAULT false,
    transfer_pair_id    UUID REFERENCES transactions(id),   -- the matching leg
    is_recurring        BOOLEAN NOT NULL DEFAULT false,
    recurring_series_id UUID REFERENCES recurring_series(id),
    excluded            BOOLEAN NOT NULL DEFAULT false,     -- user-hidden from analytics

    dedup_fingerprint   TEXT NOT NULL,          -- see doc 7 §dedup
    superseded_by       UUID REFERENCES transactions(id),   -- pending → posted link

    notes               TEXT,
    location            JSONB,                  -- {lat,lon,city,...} when provided
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ,
    UNIQUE (account_id, provider_txn_id)
);
CREATE INDEX ON transactions (user_id, posted_date DESC);
CREATE INDEX ON transactions (user_id, category_id, posted_date);
CREATE INDEX ON transactions (user_id, merchant_id, posted_date);
CREATE INDEX ON transactions (user_id, dedup_fingerprint);
-- full-text search over display_name/notes/raw_description
ALTER TABLE transactions ADD COLUMN search_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('simple',
    coalesce(display_name,'') || ' ' || coalesce(notes,'') || ' ' || coalesce(raw_description,''))) STORED;
CREATE INDEX ON transactions USING GIN (search_tsv);

CREATE TABLE transaction_splits (
    id              UUID PRIMARY KEY,
    transaction_id  UUID NOT NULL REFERENCES transactions(id),
    category_id     UUID NOT NULL REFERENCES categories(id),
    amount          NUMERIC(18,4) NOT NULL,
    note            TEXT
);

CREATE TABLE tags (
    id        UUID PRIMARY KEY,
    user_id   UUID NOT NULL REFERENCES users(id),
    name      CITEXT NOT NULL,
    UNIQUE (user_id, name)
);
CREATE TABLE transaction_tags (
    transaction_id UUID REFERENCES transactions(id),
    tag_id         UUID REFERENCES tags(id),
    PRIMARY KEY (transaction_id, tag_id)
);

CREATE TABLE attachments (               -- receipt photos/PDFs; objects in S3, encrypted
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    transaction_id  UUID REFERENCES transactions(id),
    s3_key          TEXT NOT NULL,
    mime_type       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ IMPORTS ============

CREATE TABLE import_batches (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    account_id      UUID REFERENCES accounts(id),
    file_name       TEXT NOT NULL,
    file_type       TEXT NOT NULL,       -- csv|xlsx|pdf|ofx|qfx|qif
    s3_key          TEXT NOT NULL,
    mapping_template_id UUID REFERENCES import_templates(id),
    status          TEXT NOT NULL DEFAULT 'pending', -- pending|mapping|review|done|failed
    rows_total      INT, rows_imported INT, rows_duplicate INT, rows_review INT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE import_templates (          -- saved column mappings per bank format
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    name            TEXT NOT NULL,       -- "Chase checking CSV"
    header_signature TEXT NOT NULL,      -- hash of header row → auto-match next time
    mapping         JSONB NOT NULL       -- {date:{col:0,fmt:'MM/DD/YYYY'}, amount:{...}, ...}
);

-- ============ RULES & PERSONALIZATION ============

CREATE TABLE user_rules (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    priority        INT NOT NULL DEFAULT 100,
    conditions      JSONB NOT NULL,  -- {merchant_id|text_contains|amount_between|account_id...}
    actions         JSONB NOT NULL,  -- {set_category|set_merchant_name|add_tag|exclude|mark_transfer}
    source          TEXT NOT NULL DEFAULT 'user',   -- user|auto_from_correction
    applied_count   INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE category_corrections (      -- training signal for ML
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL,
    transaction_id  UUID NOT NULL REFERENCES transactions(id),
    from_category_id UUID, to_category_id UUID NOT NULL,
    predicted_source TEXT, predicted_confidence REAL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ RECURRING / SUBSCRIPTIONS ============

CREATE TABLE recurring_series (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    merchant_id     UUID REFERENCES merchants(id),
    display_name    TEXT NOT NULL,
    kind            TEXT NOT NULL,           -- subscription|bill|income|transfer
    cadence         TEXT NOT NULL,           -- weekly|biweekly|semimonthly|monthly|quarterly|yearly|irregular
    interval_days   REAL,                    -- learned average gap
    amount_typical  NUMERIC(18,4) NOT NULL,
    amount_variability REAL NOT NULL,        -- coefficient of variation; 0 = fixed
    currency        CHAR(3) NOT NULL,
    next_expected_date DATE,
    next_expected_amount NUMERIC(18,4),
    status          TEXT NOT NULL DEFAULT 'active',  -- active|paused|canceled|ended
    first_seen      DATE NOT NULL,
    last_seen       DATE NOT NULL,
    occurrences     INT NOT NULL,
    confidence      REAL NOT NULL,
    user_confirmed  BOOLEAN,                 -- NULL = unreviewed, true/false = user verdict
    canceled_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE price_changes (
    id              UUID PRIMARY KEY,
    series_id       UUID NOT NULL REFERENCES recurring_series(id),
    old_amount      NUMERIC(18,4) NOT NULL,
    new_amount      NUMERIC(18,4) NOT NULL,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged    BOOLEAN NOT NULL DEFAULT false
);

-- ============ GOALS & BUDGETS ============

CREATE TABLE goals (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id),
    type            TEXT NOT NULL,           -- savings|emergency_fund|debt_payoff|spending_limit
    name            TEXT NOT NULL,
    emoji           TEXT,
    target_amount   NUMERIC(18,4),
    target_date     DATE,
    currency        CHAR(3) NOT NULL,
    linked_account_ids UUID[],               -- funding/debt accounts
    category_id     UUID REFERENCES categories(id),  -- for spending limits
    period          TEXT,                    -- month|week (spending limits)
    config          JSONB NOT NULL DEFAULT '{}',  -- strategy:avalanche|snowball, months_of_expenses, ...
    status          TEXT NOT NULL DEFAULT 'active', -- active|paused|achieved|abandoned
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE goal_progress (                 -- periodic snapshots → progress charts & pace calc
    goal_id     UUID NOT NULL REFERENCES goals(id),
    as_of_date  DATE NOT NULL,
    amount      NUMERIC(18,4) NOT NULL,
    PRIMARY KEY (goal_id, as_of_date)
);

CREATE TABLE budgets (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id),
    category_id UUID NOT NULL REFERENCES categories(id),
    amount      NUMERIC(18,4) NOT NULL,
    period      TEXT NOT NULL DEFAULT 'month',
    rollover    BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ,
    UNIQUE (user_id, category_id, period)
);

-- ============ INSIGHTS & NOTIFICATIONS ============

CREATE TABLE insights (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id),
    type        TEXT NOT NULL,    -- price_increase|anomaly|low_balance|duplicate_charge|
                                  -- new_subscription|fee|savings_opportunity|goal_pace|bill_due
    severity    TEXT NOT NULL DEFAULT 'info',   -- info|warn|critical
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    evidence    JSONB NOT NULL,   -- txn ids, series id, computed numbers → renders the proof
    status      TEXT NOT NULL DEFAULT 'new',    -- new|seen|dismissed|acted
    expires_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, type, (evidence->>'dedupe_key'))   -- never repeat the same insight
);

CREATE TABLE notification_prefs (
    user_id     UUID PRIMARY KEY REFERENCES users(id),
    prefs       JSONB NOT NULL DEFAULT '{}',  -- per-type on/off, thresholds, quiet hours
    digest_day  SMALLINT NOT NULL DEFAULT 1   -- weekly digest weekday
);

-- ============ FX & AUDIT ============

CREATE TABLE fx_rates (
    base        CHAR(3) NOT NULL,
    quote       CHAR(3) NOT NULL,
    rate_date   DATE NOT NULL,
    rate        NUMERIC(18,8) NOT NULL,
    PRIMARY KEY (base, quote, rate_date)
);

CREATE TABLE audit_log (                  -- append-only; security-relevant events
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     UUID,
    actor       TEXT NOT NULL,            -- user|system|admin:<id>
    event       TEXT NOT NULL,            -- login, link_account, export_data, delete_account, ...
    ip          INET,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Derived / Materialized Layers

- `mv_monthly_user_stats(user_id, month, income, expenses, savings_rate, net_flow,
  credit_spend, debit_spend)` — refreshed incrementally on ingest; powers the dashboard
  without scanning transactions.
- `mv_monthly_category_spend(user_id, month, category_id, amount, txn_count)` and the
  merchant/account equivalents — power the Insights tab.
- Income/expense aggregates always exclude `is_transfer`, `excluded`, and `status='removed'`.

## Scaling Notes

- Partition `transactions` by hash(`user_id`) (or move hot aggregates to monthly range
  partitions) once past ~100M rows.
- Row-level security: `USING (user_id = current_setting('app.user_id')::uuid)` on every
  tenant table as defense-in-depth behind the API layer.
- All money math in `NUMERIC`; FX conversion stored per-transaction at the transaction-date
  rate so historical reports never drift.
