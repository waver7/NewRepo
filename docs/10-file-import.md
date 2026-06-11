# 10. File Upload / Import Strategy

File import is a first-class citizen, not a fallback: it serves users whose banks aren't
linkable, privacy-conscious users who refuse linking, and historical backfill beyond
aggregator limits. **Goal: any file a bank can produce, imported correctly in under a minute.**

## 10.1 Supported Formats & Pipeline

```
Upload (Files / Drive / share-sheet / email-forward later)
  → S3 (encrypted) → sandboxed import-worker
     → format detection (magic bytes + extension + content sniff)
        ├─ OFX / QFX / QIF  → native parser (highest fidelity, has FITIDs → perfect dedup)
        ├─ CSV / TSV        → robust parser (encoding sniff: UTF-8/16, Latin-1; delimiter
        │                     sniff; quoted fields; thousands/decimal separators by locale)
        ├─ XLSX / XLS       → sheet picker if multiple; header-row autodetect (skips bank
        │                     logo/title rows above the table)
        └─ PDF              → text layer extraction; if scanned → OCR (Textract/Tesseract)
                              → LLM structured extraction
  → unified RawRow[] → column mapping → preview/review → ingestion pipeline (doc 6 §6.2)
```

## 10.2 Smart Column Mapping (CSV/XLSX)

1. **Template match:** hash the header row → if it matches a saved `import_template`
   (user's or global), apply instantly, skip to preview.
2. **Heuristics:** header-name dictionary (multi-language): date/fecha/datum…,
   amount/debit/credit/montant…, description/payee/memo…; cell-content validation
   (parseable dates, numerics).
3. **AI assist:** if heuristics are ambiguous, send the header + 5 sample rows (numbers
   masked where possible) to an LLM → proposed mapping with confidence.
4. **Format resolution:** date format disambiguation (01/02/2025 — MM/DD or DD/MM?) by
   scanning the whole column for impossible values; ask the user only if truly ambiguous.
   Amount sign conventions handled: single signed column, separate debit/credit columns,
   "CR/DR" suffix, parentheses negatives, trailing minus.
5. **User confirms** a mapped preview (first 10 rows). Confirmed mapping saved as a
   template ("Chase Checking CSV") keyed by header signature — next month's file imports
   with zero clicks. High-confidence global templates (same bank, many users) are shared
   (header structure only — never user data).

## 10.3 PDF Statements (the differentiator)

1. Extract text layer; detect scanned PDFs (no/garbage text) → OCR.
2. Chunk by page; LLM extraction with a strict JSON schema:
   `{date, description, amount, direction, balance_after?, page, bbox?}` plus statement
   metadata `{institution?, account_mask?, period_start, period_end, opening_balance?,
   closing_balance?}`.
3. **Self-verification:** if opening/closing balances were extracted, check
   `opening + Σ(txns) == closing`. Pass ⇒ high confidence. Fail ⇒ flag the residual and
   highlight the lowest-confidence rows for human review — this single check catches most
   OCR/extraction errors.
4. Review UI: extracted table side-by-side with the source page; low-confidence rows
   highlighted; tap a row to see the exact statement region it came from.
5. Password-protected PDFs: prompt for the password client-side; never stored.

## 10.4 Dedup & Account Targeting

- User picks the destination account (or "create manual account"); statement metadata
  (institution + mask) pre-selects it when detectable.
- Every imported row runs the standard dedup cascade (doc 7 §7.4). Typical result banner:
  *"1,032 new · 211 already known (skipped) · 3 need your review."*
- Overlapping re-import of the same file/period is always safe — idempotent by design.
- Imported rows then flow through the same enrich/categorize/recurring stages as linked
  data — file-import users get the full intelligence experience.

## 10.5 Safety & Limits

- Sandboxed parsing workers (no network egress; PDF/XLSX parsers are an attack surface).
- Limits: 25MB/file, 50k rows/file; streaming parse, never load-all-in-memory.
- Original files retained encrypted (user can re-process or delete them); auto-purge
  originals after 90 days on free tier.
- Full import history with per-batch rollback ("undo this import") via `import_batch_id`.

## 10.6 Manual Entry

Quick-add sheet (doc 4 §4.6): amount-first keypad, merchant typeahead backed by the global
merchant DB (instant logo + auto-category), offline queue with sync. Repeated manual
patterns get a shortcut suggestion ("You add 'Lunch $12–15' most weekdays — want a one-tap
shortcut or a Siri/Assistant phrase?").

## 10.7 Email-Forwarding Ingestion (P2)

Per-user address (`u-abc123@in.lumen.app`): forward e-receipts and statement emails;
attachments run the file pipeline, receipt bodies run LLM extraction for **item-level**
detail that card data can never provide ("$84 at Safeway → $61 food, $11 household, $12
alcohol"). Strict sender verification + the same sandboxing as uploads.
