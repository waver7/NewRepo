# 8. Security Model

Principle: **we hold the minimum, encrypt everything we hold, and can prove what happened.**
Lumen never sees or stores bank credentials — aggregators own that risk; we hold read-only
access tokens, and those live in a vault, not the database.

## 8.1 Authentication & Sessions

- **Sign-in:** Sign in with Apple / Google (preferred — no password to breach) or
  email+password hashed with **Argon2id**. Breached-password screening (k-anonymity HIBP)
  at signup and login.
- **MFA:** TOTP + platform passkeys; required for sensitive actions (export all data,
  delete account, changing email) regardless of session state — *step-up auth*.
- **Tokens:** short-lived access JWT (15 min) + rotating refresh token bound to the device;
  refresh-token reuse detection kills the whole family. Server-side revocation list.
- **Device layer:** biometric (Face ID / BiometricPrompt) or PIN gate on app open and on
  return from background; secrets in iOS Keychain / Android Keystore (hardware-backed,
  no backup flag).
- **Sessions screen:** users see and can revoke every active device.

## 8.2 Data Protection

| Layer | Control |
|-------|---------|
| In transit | TLS 1.3 everywhere; **certificate pinning** in the mobile apps; HSTS |
| At rest (DB) | Full-disk + RDS encryption; **field-level envelope encryption** (AES-256-GCM, per-user data keys wrapped by KMS) for high-sensitivity columns: aggregator token refs, account numbers/masks, MFA seeds |
| Files (S3) | SSE-KMS, bucket-private, short-lived signed URLs only; statements/receipts encrypted with the user's data key |
| Aggregator tokens | Stored in **Vault/KMS**, DB holds only an opaque reference; tokens never logged, never leave the Aggregator Hub service |
| Backups | Encrypted, access-logged, purged on user deletion within 30 days |
| Crypto-shredding | Account deletion destroys the user's data key → any residual ciphertext is unreadable |
| Mobile at rest | Encrypted local cache (SQLCipher/MMKV-encrypted); auto-wipe on logout; screenshot blocking on sensitive screens (Android FLAG_SECURE), blur in app switcher |

## 8.3 Application Security

- **Least privilege by construction:** request **read-only** aggregator scopes
  (transactions, balances) — never money movement in v1.
- Row-level security in Postgres as a second wall behind API authorization; every query
  scoped by `user_id`.
- Input handling: file imports parsed in a **sandboxed worker** (separate container, no
  network egress except S3) — malformed/hostile CSVs and PDFs can't touch anything.
  PDF parsing libraries are a classic RCE surface; isolate them.
- LLM safety: transaction text is untrusted input — strict output schemas, no
  tool-escalation from descriptor content (prompt-injection treated as a real threat model).
- Webhooks: signature verification (Plaid JWT/JWKS), replay protection, idempotency.
- Rate limiting & WAF at the gateway; per-account lockout with exponential backoff.
- Secrets: never in code or env files — cloud secret manager, rotated automatically.
- Supply chain: dependency scanning + lockfiles + Dependabot; signed releases; SAST in CI.
- Mobile hardening: no sensitive data in push payloads by default; jailbreak/root detection
  → warn-and-degrade (don't hard-block); obfuscation for release builds.

## 8.4 Privacy & Compliance

- **Data minimization:** we don't request identity/income endpoints unless a feature needs
  them; analytics events contain no financial values.
- **GDPR/CCPA:** export (machine-readable, free, all tiers), rectification, deletion
  (hard delete + crypto-shred + aggregator `item/remove` so the bank consent is revoked too).
- **No data selling. No advertising SDKs.** Third-party processors limited to: aggregator,
  cloud, push, crash reporting (scrubbed), payments (Stripe/RevenueCat).
- Consent records: per-institution consent with timestamps, surfaced in the app
  ("You connected Chase on Mar 3 via Plaid — read-only · [Disconnect]").
- Compliance track: SOC 2 Type I by launch+6mo, Type II by +18mo; aggregator due-diligence
  questionnaires (Plaid requires a security review) handled from day one.
- Regional data residency (EU home region) when launching in Europe.

## 8.5 Threat Model (abridged)

| Threat | Mitigation |
|--------|------------|
| DB exfiltration | Field-level encryption → tokens/account ids useless; RLS; no credentials stored at all |
| Stolen device | Biometric/PIN gate, encrypted cache, remote session revoke |
| Account takeover (credential stuffing) | Passkeys/social-auth default, breached-pw checks, MFA, anomalous-login detection + step-up |
| Malicious file upload | Sandboxed parsers, size/type limits, no execution paths |
| Insider access | No standing prod access; break-glass with approval + full audit; support tooling shows masked data only |
| Aggregator breach | Read-only scopes bound to our client; token revocation runbook; provider abstraction allows rapid migration |
| Prompt injection via merchant strings | Constrained LLM outputs, no instruction-following on data fields |
| Phishing of our users | Emails never contain links to "re-enter bank credentials"; in-app-only re-auth flows; clear comms policy |

## 8.6 Detection & Response

- Append-only `audit_log` for every security-relevant event (logins, exports, link/unlink,
  deletions, admin actions) — user-visible activity history.
- Alerting on anomalous patterns: mass export, geographic-impossible logins, token misuse.
- Incident response runbook: revoke tokens (global + per-provider), force re-auth, user
  notification obligations (state breach laws / GDPR 72h) pre-drafted.
- Annual third-party pentest + public vulnerability disclosure policy / bug bounty.
