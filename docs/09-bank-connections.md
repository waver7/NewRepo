# 9. Bank Connection Strategy

## 9.1 Provider Strategy: Abstraction First

Build a thin **Aggregator Hub** with a provider-agnostic interface from day one, even though
we launch Plaid-only. This is cheap now and existential later: coverage gaps, per-connection
pricing leverage, institution-specific outages, and EU expansion all require multi-provider.

```ts
interface AggregatorProvider {
  createLinkSession(user, opts): LinkSession          // token for the native Link UI
  exchangePublicToken(publicToken): { itemRef }       // store token in vault, return ref
  fetchAccounts(itemRef): Account[]
  syncTransactions(itemRef, cursor): { added, modified, removed, nextCursor }
  refreshBalances(itemRef): Balance[]
  handleWebhook(headers, body): NormalizedEvent[]     // signature-verified
  createUpdateSession(itemRef): LinkSession           // re-auth / repair
  revoke(itemRef): void                               // user disconnect / deletion
}
```

| Provider | Role |
|----------|------|
| **Plaid** | Primary (US/CA): best Link UX, `/transactions/sync` cursor API, enrichment hints |
| **MX or Finicity** | Fallback for institutions where Plaid fails/unsupported; pricing leverage |
| **TrueLayer / GoCardless** | EU/UK open banking (PSD2) at expansion |

**Routing table:** per-institution provider preference, maintained from observed success
rates. A failed link on provider A automatically offers provider B; if all fail → guide the
user to file import (doc 10) so no one hits a dead end.

## 9.2 Linking UX Rules

- Use each provider's **native Link SDK** (handles OAuth, MFA, credential UI) — Lumen never
  proxies or sees credentials; OAuth-based connections preferred wherever the institution
  supports them (more durable, user-revocable at the bank).
- Ask for **read-only scopes**: accounts, balances, transactions. No auth/identity/payment
  scopes until a feature genuinely needs them (and then with separate consent).
- After linking: pull 24 months of history (institution permitting), show live ingestion
  progress, and push "ready" when the pipeline completes.

## 9.3 Sync Model

1. **Webhooks are the primary trigger** (`SYNC_UPDATES_AVAILABLE`, `DEFAULT_UPDATE`,
   `ITEM_LOGIN_REQUIRED`…): verify signature → persist raw event → enqueue sync job.
2. **Cursor-based incremental sync** (`/transactions/sync`): added/modified/removed deltas;
   cursor stored per connection; modified updates pending→posted; removed marks
   `status='removed'`.
3. **Scheduled safety net:** every connection refreshed at least every 12–24h even without
   webhooks; balance-only refresh more often for accounts feeding bill-risk forecasts.
4. **On-demand refresh:** pull-to-refresh triggers a rate-limited manual sync.
5. All sync jobs idempotent (provider_txn_id uniqueness) — webhook replays are harmless.

## 9.4 Connection Health & Repair

| State | Behavior |
|-------|----------|
| `active` | Normal; freshness dot in Accounts tab |
| `login_required` | Badge + gentle push (max 1/day, stop after 3) → update-mode Link (2-tap fix) |
| `error` (provider/institution outage) | No user blame; banner "Chase is having trouble at the moment — your data is current as of 2h ago"; auto-retry with backoff |
| `paused` (user choice) | No syncs; data retained |
| `revoked` | Tokens revoked at provider; historical data retained unless user deletes |

Connection-health dashboard internally: link success rate, sync latency, and error rates per
institution per provider — this data drives the routing table.

## 9.5 Cost Control

- Plaid bills per connected Item/month: enforce tier limits (free = 2 connections) in
  product, dedupe Items (same institution+user), and reap Items from deleted/dormant
  accounts (>90 days inactive → prompt, then pause).
- Prefer webhook-driven sync over polling (fewer API calls), batch balance refreshes.

## 9.6 Edge Cases

- **Duplicate item linking** (user links same bank twice): detect by institution + account
  masks → merge into the existing connection instead of double-ingesting.
- **Account number changes** (card reissued): match by institution + name + history overlap;
  continue the same logical account.
- **Closed accounts:** keep history, mark closed, exclude from balances.
- **Multi-currency institutions:** per-account currency honored end-to-end (doc 5).
- **Historical gap between file imports and live linking:** the dedup layer (doc 7 §7.4)
  makes "import old PDFs + link the same bank" seamless — this combination is a
  differentiator, most competitors handle it badly.
