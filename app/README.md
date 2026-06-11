# Lumen — Flutter App (iOS + Android)

A real, runnable implementation of the Lumen personal finance app from the
[design docs](../README.md). One Flutter codebase produces **both** the Android
and iOS apps (the native projects live in `android/` and `ios/`).

**Local-first:** all data is stored on-device in SQLite. No backend, no account,
no bank keys required — which means you can run and test everything immediately.

## What's implemented

| Area | Details |
|------|---------|
| Onboarding | Demo mode (6-month realistic synthetic ledger) or start fresh |
| Home dashboard | Net cash flow, income/expenses, savings rate, 6-month chart, top categories, attention cards |
| Insight engine | Subscription price-increase alerts, bills due this week, duplicate-charge detection, budget overrun warnings |
| Transactions | Day-grouped list, full-text search, category filter chips, swipe-to-delete, detail sheet with original descriptor |
| Auto-categorization | Normalizer + 150-entry merchant knowledge base + amount heuristics; explains every decision |
| Learning loop | Correct a category once → "Always?" → applied retroactively to the whole merchant, persisted as a rule |
| CSV import | Robust parser (quoted fields, delimiters), automatic column mapping, date-format disambiguation, debit/credit layouts, preview, duplicate-skipping on import |
| Subscriptions | Automatic recurring detection (gap-sequence cadence scoring), monthly cost rollup, next-charge prediction, PRICE ↑ badges |
| Budgets | Per-category monthly limits with pace-aware progress bars |
| Goals | Savings goals with progress rings, required-monthly pace math, contributions |
| Accounts | Checking/savings/credit/cash, live balances, add/edit/delete |
| Insights | Month selector, category donut, by-category and by-merchant breakdowns with month-over-month deltas |
| Settings | Currency, CSV export (clipboard), learned-rules viewer, full data wipe |

The money-critical logic (categorizer, dedup, recurring detector, CSV importer,
stats, goal math) is pure Dart with **29 passing unit/widget tests**.

## Run it

Prereqs: [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
(`flutter doctor` to verify your setup).

```bash
cd app
flutter pub get

# Android (emulator or device with USB debugging)
flutter run

# iOS (macOS with Xcode; simulator or device)
open -a Simulator && flutter run

# Quickest sanity check without any device setup:
flutter test          # 29 tests, all domain logic
flutter analyze       # zero issues
```

## Build release binaries

```bash
# Android APK (installable directly on any Android device)
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode + Apple developer signing)
flutter build ipa --release
```

## 5-minute manual test script

1. Launch → **Explore with demo data** → dashboard appears populated.
2. Home: check the **Needs attention** cards — you should see the planted
   *Spotify price increase* and the *duplicate Shell charge*.
3. Plan → Subscriptions: Netflix/Spotify/iCloud/Audible/gym detected with
   monthly total and next-charge dates; Spotify wears a **PRICE ↑** badge.
4. Activity: search "coffee"; tap a transaction → change category → **Always**
   → see it applied to every past transaction of that merchant.
5. Activity → import icon: import `sample_data/chase_checking.csv` → mapping
   auto-detected → import → re-import the same file → **all rows skipped as
   duplicates**.
6. Plan → Budgets: add a Restaurants limit of $200 → progress bar reflects
   demo spending.
7. Plan → Goals: create "House fund", $12,000 by next year → pace math shows
   required $/month.
8. Settings → Erase all data → onboarding returns.

## Architecture

```
lib/
  models/models.dart         pure-Dart domain: accounts, txns, categories, goals…
  services/
    categorizer.dart         descriptor normalization + categorization cascade
    dedup.dart               fingerprint + fuzzy duplicate detection
    recurring_detector.dart  cadence scoring, next-charge prediction, price changes
    csv_importer.dart        CSV parsing + smart column mapping
    stats.dart               monthly stats, breakdowns, balances
    demo_data.dart           deterministic synthetic ledger
    db.dart                  SQLite persistence (sqflite)
  state/app_state.dart       ChangeNotifier facade (provider)
  screens/                   home, activity, plan, insights, accounts, import…
  ui/                        custom-painted charts, money/date formatting
test/                        29 unit + widget tests
```

The cloud architecture (Plaid linking, multi-user backend, AI categorization
with LLM fallback) is specified in [`../docs/`](../docs/) and slots in behind
the same domain layer.
