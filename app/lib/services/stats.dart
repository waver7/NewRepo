/// Analytics over the ledger: monthly income/expense/savings-rate, category,
/// merchant and account breakdowns, month-over-month deltas. Transfers and
/// zero rows are always excluded from income/expense math (docs/05).
library;

import '../models/models.dart';

class MonthStats {
  final String month; // yyyy-MM
  final int incomeCents;
  final int expenseCents; // positive number (absolute spend)

  const MonthStats(this.month, this.incomeCents, this.expenseCents);

  int get netCents => incomeCents - expenseCents;
  double get savingsRate =>
      incomeCents <= 0 ? 0 : (netCents / incomeCents).clamp(-1.0, 1.0);
}

class CategorySpend {
  final String categoryId;
  final int cents; // absolute
  final int count;
  const CategorySpend(this.categoryId, this.cents, this.count);
}

class MerchantSpend {
  final String merchant;
  final int cents;
  final int count;
  const MerchantSpend(this.merchant, this.cents, this.count);
}

class Stats {
  static bool _countable(Txn t) => !t.isTransfer && t.amountCents != 0;

  static MonthStats forMonth(List<Txn> txns, String month) {
    var income = 0;
    var expense = 0;
    for (final t in txns) {
      if (t.month != month || !_countable(t)) continue;
      if (t.amountCents > 0) {
        income += t.amountCents;
      } else {
        expense += -t.amountCents;
      }
    }
    return MonthStats(month, income, expense);
  }

  /// Last [n] months ending at [month], oldest first. Months with no data
  /// appear as zeros so charts have a continuous axis.
  static List<MonthStats> lastMonths(List<Txn> txns, String month, int n) {
    final end = DateTime(
        int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    final out = <MonthStats>[];
    for (var i = n - 1; i >= 0; i--) {
      final m = DateTime(end.year, end.month - i);
      out.add(forMonth(txns, monthKey(m)));
    }
    return out;
  }

  static List<CategorySpend> byCategory(List<Txn> txns, String month,
      {bool expensesOnly = true}) {
    final cents = <String, int>{};
    final counts = <String, int>{};
    for (final t in txns) {
      if (t.month != month || !_countable(t)) continue;
      if (expensesOnly && t.amountCents >= 0) continue;
      cents[t.categoryId] = (cents[t.categoryId] ?? 0) + t.amountCents.abs();
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
    }
    final list = cents.entries
        .map((e) => CategorySpend(e.key, e.value, counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    return list;
  }

  static List<MerchantSpend> byMerchant(List<Txn> txns, String month,
      {bool expensesOnly = true}) {
    final cents = <String, int>{};
    final counts = <String, int>{};
    for (final t in txns) {
      if (t.month != month || !_countable(t)) continue;
      if (expensesOnly && t.amountCents >= 0) continue;
      cents[t.merchant] = (cents[t.merchant] ?? 0) + t.amountCents.abs();
      counts[t.merchant] = (counts[t.merchant] ?? 0) + 1;
    }
    final list = cents.entries
        .map((e) => MerchantSpend(e.key, e.value, counts[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    return list;
  }

  /// Spend per account for a month (absolute expense cents).
  static Map<String, int> byAccount(List<Txn> txns, String month) {
    final out = <String, int>{};
    for (final t in txns) {
      if (t.month != month || !_countable(t) || t.amountCents >= 0) continue;
      out[t.accountId] = (out[t.accountId] ?? 0) + t.amountCents.abs();
    }
    return out;
  }

  /// Current balance of an account = starting balance + all its transactions
  /// (transfers included — they move real money).
  static int accountBalance(Account a, List<Txn> txns) {
    var bal = a.startingBalanceCents;
    for (final t in txns) {
      if (t.accountId == a.id) bal += t.amountCents;
    }
    return bal;
  }

  /// Month-over-month delta for a category: (this month - prev month) cents.
  static int categoryDelta(List<Txn> txns, String month, String categoryId) {
    final cur = byCategory(txns, month)
        .where((c) => c.categoryId == categoryId)
        .fold(0, (s, c) => s + c.cents);
    final end = DateTime(
        int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    final prevMonth = monthKey(DateTime(end.year, end.month - 1));
    final prev = byCategory(txns, prevMonth)
        .where((c) => c.categoryId == categoryId)
        .fold(0, (s, c) => s + c.cents);
    return cur - prev;
  }
}
