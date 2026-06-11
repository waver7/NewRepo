/// Application state: a ChangeNotifier facade over the database and the
/// domain services. Screens read from here and call mutating methods; all
/// derived data (stats, recurring series, insights) is computed on demand
/// from the in-memory ledger, which is plenty fast at personal-ledger scale.
library;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/categorizer.dart';
import '../services/db.dart';
import '../services/dedup.dart';
import '../services/demo_data.dart';
import '../services/recurring_detector.dart';
import '../services/stats.dart';

class AttentionItem {
  final String emoji;
  final String title;
  final String body;
  const AttentionItem(this.emoji, this.title, this.body);
}

class AppState extends ChangeNotifier {
  final LumenDb db;
  AppState(this.db);

  bool loaded = false;
  bool onboarded = false;
  String currency = 'USD';

  List<Account> accounts = [];
  List<Txn> txns = [];
  List<Budget> budgets = [];
  List<Goal> goals = [];
  late Categorizer categorizer = Categorizer();

  Future<void> load() async {
    final overrides = await db.categoryOverrides();
    categorizer = Categorizer(userOverrides: overrides);
    accounts = await db.accounts();
    txns = await db.transactions();
    budgets = await db.budgets();
    goals = await db.goals();
    onboarded = (await db.getMeta('onboarded')) == '1';
    currency = (await db.getMeta('currency')) ?? 'USD';
    loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding({required bool withDemoData}) async {
    if (withDemoData) {
      final demo = DemoData.generate();
      for (final a in demo.accounts) {
        await db.upsertAccount(a);
      }
      await db.insertTxns(demo.txns);
      accounts = demo.accounts;
      txns = demo.txns;
    } else if (accounts.isEmpty) {
      final a = Account(
          id: newId(), name: 'Checking', type: AccountType.checking);
      await db.upsertAccount(a);
      accounts = [a];
    }
    await db.setMeta('onboarded', '1');
    onboarded = true;
    notifyListeners();
  }

  // ---- accounts ----
  Future<void> saveAccount(Account a) async {
    await db.upsertAccount(a);
    final i = accounts.indexWhere((x) => x.id == a.id);
    if (i == -1) {
      accounts.add(a);
    } else {
      accounts[i] = a;
    }
    notifyListeners();
  }

  Future<void> removeAccount(String id) async {
    await db.deleteAccount(id);
    accounts.removeWhere((a) => a.id == id);
    txns.removeWhere((t) => t.accountId == id);
    notifyListeners();
  }

  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  int accountBalance(Account a) => Stats.accountBalance(a, txns);

  // ---- transactions ----
  Future<void> addTxn(Txn t) async {
    await db.upsertTxn(t);
    txns.insert(0, t);
    txns.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> updateTxn(Txn t) async {
    await db.upsertTxn(t);
    final i = txns.indexWhere((x) => x.id == t.id);
    if (i != -1) txns[i] = t;
    notifyListeners();
  }

  Future<void> removeTxn(String id) async {
    await db.deleteTxn(id);
    txns.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Recategorize + optionally learn the correction for this merchant
  /// (applies retroactively to all matching transactions).
  Future<int> recategorize(Txn t, String categoryId,
      {required bool always}) async {
    t.categoryId = categoryId;
    t.categorySource = 'user';
    t.isTransfer = Categories.get(categoryId).kind == CategoryKind.transfer;
    await db.upsertTxn(t);
    var applied = 1;
    if (always) {
      final key = Categorizer.merchantKey(t.rawDesc);
      categorizer.learn(t.rawDesc, categoryId);
      await db.saveOverride(key, categoryId);
      for (final other in txns) {
        if (other.id == t.id) continue;
        if (Categorizer.merchantKey(other.rawDesc) == key &&
            other.categorySource != 'user') {
          other.categoryId = categoryId;
          other.categorySource = 'user';
          other.isTransfer = t.isTransfer;
          await db.upsertTxn(other);
          applied++;
        }
      }
    }
    notifyListeners();
    return applied;
  }

  /// Imports already-parsed transactions with a dedup pass.
  Future<({int imported, int duplicates})> importTxns(List<Txn> incoming) async {
    final r = Dedup.partition(incoming, txns);
    await db.insertTxns(r.fresh);
    txns.addAll(r.fresh);
    txns.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return (imported: r.fresh.length, duplicates: r.duplicates.length);
  }

  // ---- budgets / goals ----
  Future<void> saveBudget(Budget b) async {
    await db.upsertBudget(b);
    final i = budgets.indexWhere((x) => x.categoryId == b.categoryId);
    if (i == -1) {
      budgets.add(b);
    } else {
      budgets[i] = b;
    }
    notifyListeners();
  }

  Future<void> removeBudget(String id) async {
    await db.deleteBudget(id);
    budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<void> saveGoal(Goal g) async {
    await db.upsertGoal(g);
    final i = goals.indexWhere((x) => x.id == g.id);
    if (i == -1) {
      goals.add(g);
    } else {
      goals[i] = g;
    }
    notifyListeners();
  }

  Future<void> removeGoal(String id) async {
    await db.deleteGoal(id);
    goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    currency = code;
    await db.setMeta('currency', code);
    notifyListeners();
  }

  Future<void> wipeEverything() async {
    await db.wipeAll();
    accounts = [];
    txns = [];
    budgets = [];
    goals = [];
    categorizer = Categorizer();
    onboarded = false;
    notifyListeners();
  }

  // ---- derived ----
  String get currentMonth => monthKey(DateTime.now());

  MonthStats monthStats([String? month]) =>
      Stats.forMonth(txns, month ?? currentMonth);

  List<MonthStats> recentMonths(int n) =>
      Stats.lastMonths(txns, currentMonth, n);

  List<CategorySpend> categorySpend([String? month]) =>
      Stats.byCategory(txns, month ?? currentMonth);

  List<MerchantSpend> merchantSpend([String? month]) =>
      Stats.byMerchant(txns, month ?? currentMonth);

  List<RecurringSeries> get recurring => RecurringDetector.detect(txns);

  int budgetSpent(String categoryId, [String? month]) {
    final m = month ?? currentMonth;
    var cents = 0;
    for (final t in txns) {
      if (t.month == m && t.categoryId == categoryId && t.isExpense) {
        cents += t.amountCents.abs();
      }
    }
    return cents;
  }

  /// Attention cards for the home screen — the local "insight engine".
  List<AttentionItem> get attentionItems {
    final items = <AttentionItem>[];

    // Price increases on detected subscriptions.
    for (final s in recurring) {
      if (s.previousAmountCents != null && !s.isIncome) {
        items.add(AttentionItem(
          '📈',
          '${s.displayName} price went up',
          'Was ${_fmt(s.previousAmountCents!.abs())}, now '
              '${_fmt(s.typicalAmountCents.abs())} per ${s.cadence.label.toLowerCase()}.',
        ));
      }
    }

    // Upcoming recurring charges in the next 7 days.
    final now = DateTime.now();
    final soon = recurring.where((s) {
      if (s.isIncome) return false;
      final d = parseDateKey(s.nextExpectedDate);
      final diff = d.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();
    if (soon.isNotEmpty) {
      final total = soon.fold(0, (sum, s) => sum + s.typicalAmountCents.abs());
      items.add(AttentionItem(
        '📅',
        '${soon.length} bill${soon.length > 1 ? 's' : ''} due this week',
        '${soon.map((s) => s.displayName).take(3).join(', ')} — about ${_fmt(total)} total.',
      ));
    }

    // Same-day duplicate charges in the last 35 days.
    final cutoff = dateKey(now.subtract(const Duration(days: 35)));
    final seen = <String, Txn>{};
    for (final t in txns) {
      if (t.date.compareTo(cutoff) < 0 || !t.isExpense) continue;
      final key = '${t.accountId}|${t.amountCents}|${t.date}|'
          '${Categorizer.merchantKey(t.rawDesc)}';
      if (seen.containsKey(key) && seen[key]!.id != t.id) {
        items.add(AttentionItem(
          '⚠️',
          'Possible duplicate charge',
          '${t.merchant} charged ${_fmt(t.amountCents.abs())} twice on ${t.date}.',
        ));
        seen.remove(key); // report each pair once
      } else {
        seen[key] = t;
      }
    }

    // Budgets at/over 90%.
    for (final b in budgets) {
      final spent = budgetSpent(b.categoryId);
      if (b.limitCents > 0 && spent >= b.limitCents * 0.9) {
        final c = Categories.get(b.categoryId);
        final pct = (spent / b.limitCents * 100).round();
        items.add(AttentionItem(
          spent >= b.limitCents ? '🔴' : '🟠',
          '${c.name} budget at $pct%',
          '${_fmt(spent)} of ${_fmt(b.limitCents)} this month.',
        ));
      }
    }

    return items.take(6).toList();
  }

  String _fmt(int cents) {
    final symbol = switch (currency) {
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      _ => r'$',
    };
    return '$symbol${(cents / 100).toStringAsFixed(2)}';
  }
}
