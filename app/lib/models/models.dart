/// Core domain models for Lumen. Pure Dart (no Flutter imports) so the whole
/// domain layer is unit-testable on the Dart VM.
library;

import 'dart:math';

String newId() {
  final rnd = Random().nextInt(0xFFFFFF).toRadixString(36);
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$rnd';
}

/// yyyy-MM-dd, the canonical date key used across the app.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) => DateTime.parse(s);

/// yyyy-MM, used for monthly aggregation.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

enum CategoryKind { expense, income, transfer }

class Category {
  final String id; // slug, e.g. 'food.groceries'
  final String name;
  final String emoji;
  final CategoryKind kind;
  final bool essential;

  const Category(this.id, this.name, this.emoji,
      {this.kind = CategoryKind.expense, this.essential = false});
}

/// The fixed two-level taxonomy (doc 7 of the design). Order matters for UI.
class Categories {
  static const uncategorized =
      Category('other.uncategorized', 'Uncategorized', '❓');

  static const all = <Category>[
    // Income
    Category('income.salary', 'Salary', '💼', kind: CategoryKind.income),
    Category('income.freelance', 'Freelance', '🧾', kind: CategoryKind.income),
    Category('income.interest', 'Interest', '🏦', kind: CategoryKind.income),
    Category('income.refund', 'Refunds', '↩️', kind: CategoryKind.income),
    Category('income.other', 'Other income', '💵', kind: CategoryKind.income),
    // Housing & utilities
    Category('housing.rent', 'Rent', '🏠', essential: true),
    Category('housing.mortgage', 'Mortgage', '🏡', essential: true),
    Category('utilities.electric', 'Electricity', '⚡', essential: true),
    Category('utilities.water', 'Water', '💧', essential: true),
    Category('utilities.internet', 'Internet', '🌐', essential: true),
    Category('utilities.phone', 'Mobile phone', '📱', essential: true),
    // Food
    Category('food.groceries', 'Groceries', '🛒', essential: true),
    Category('food.restaurants', 'Restaurants', '🍽️'),
    Category('food.coffee', 'Coffee shops', '☕'),
    Category('food.delivery', 'Delivery & takeout', '🛵'),
    // Transport
    Category('transport.gas', 'Gas & fuel', '⛽', essential: true),
    Category('transport.transit', 'Public transit', '🚇', essential: true),
    Category('transport.rideshare', 'Rideshare', '🚗'),
    Category('transport.parking', 'Parking', '🅿️'),
    Category('transport.insurance', 'Car insurance', '🚙', essential: true),
    // Health
    Category('health.insurance', 'Health insurance', '🩺', essential: true),
    Category('health.pharmacy', 'Pharmacy', '💊', essential: true),
    Category('health.fitness', 'Fitness', '🏋️'),
    // Shopping & fun
    Category('shopping.general', 'Shopping', '🛍️'),
    Category('shopping.electronics', 'Electronics', '🔌'),
    Category('shopping.gifts', 'Gifts', '🎁'),
    Category('fun.streaming', 'Streaming', '📺'),
    Category('fun.events', 'Events & movies', '🎟️'),
    Category('fun.games', 'Games', '🎮'),
    Category('subs.software', 'Software & apps', '🧩'),
    Category('subs.membership', 'Memberships', '🎫'),
    Category('subs.news', 'News & media', '📰'),
    // Travel
    Category('travel.flights', 'Flights', '✈️'),
    Category('travel.hotels', 'Hotels', '🏨'),
    Category('travel.other', 'Travel other', '🧳'),
    // Family & personal
    Category('family.pets', 'Pets', '🐾'),
    Category('family.education', 'Education', '🎓'),
    Category('personal.beauty', 'Beauty & grooming', '💈'),
    Category('personal.charity', 'Charity', '❤️'),
    Category('personal.cash', 'Cash withdrawal', '🏧'),
    // Financial
    Category('financial.fees', 'Bank fees', '🧾', essential: false),
    Category('financial.loan', 'Loan payment', '📉', essential: true),
    Category('financial.taxes', 'Taxes', '🏛️', essential: true),
    // Transfers
    Category('transfer.internal', 'Transfer', '🔁', kind: CategoryKind.transfer),
    Category('transfer.p2p', 'P2P payment', '🤝', kind: CategoryKind.transfer),
    Category('transfer.cc_payment', 'Card payment', '💳',
        kind: CategoryKind.transfer),
    uncategorized,
  ];

  static final Map<String, Category> byId = {for (final c in all) c.id: c};

  static Category get(String? id) => byId[id] ?? uncategorized;

  static List<Category> get expense =>
      all.where((c) => c.kind == CategoryKind.expense).toList();
  static List<Category> get income =>
      all.where((c) => c.kind == CategoryKind.income).toList();
}

enum AccountType { checking, savings, creditCard, cash }

extension AccountTypeLabel on AccountType {
  String get label => switch (this) {
        AccountType.checking => 'Checking',
        AccountType.savings => 'Savings',
        AccountType.creditCard => 'Credit card',
        AccountType.cash => 'Cash',
      };
}

class Account {
  final String id;
  String name;
  AccountType type;
  int startingBalanceCents;
  String currency;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.startingBalanceCents = 0,
    this.currency = 'USD',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'starting_balance_cents': startingBalanceCents,
        'currency': currency,
      };

  static Account fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountType.values.firstWhere((t) => t.name == m['type'],
            orElse: () => AccountType.checking),
        startingBalanceCents: (m['starting_balance_cents'] as num).toInt(),
        currency: (m['currency'] as String?) ?? 'USD',
      );
}

class Txn {
  final String id;
  String accountId;

  /// Negative = money out, positive = money in. Always minor units (cents).
  int amountCents;
  String date; // yyyy-MM-dd
  String merchant; // cleaned display name
  String rawDesc; // descriptor exactly as received
  String categoryId;
  String categorySource; // rule|keyword|user|llm|import|manual
  bool isTransfer;
  String notes;
  String source; // manual|csv|demo
  String fingerprint;

  Txn({
    required this.id,
    required this.accountId,
    required this.amountCents,
    required this.date,
    required this.merchant,
    String? rawDesc,
    this.categoryId = 'other.uncategorized',
    this.categorySource = 'manual',
    this.isTransfer = false,
    this.notes = '',
    this.source = 'manual',
    this.fingerprint = '',
  }) : rawDesc = rawDesc ?? merchant;

  DateTime get dateTime => parseDateKey(date);
  String get month => date.substring(0, 7);
  bool get isExpense => amountCents < 0 && !isTransfer;
  bool get isIncome => amountCents > 0 && !isTransfer;

  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'amount_cents': amountCents,
        'date': date,
        'merchant': merchant,
        'raw_desc': rawDesc,
        'category_id': categoryId,
        'category_source': categorySource,
        'is_transfer': isTransfer ? 1 : 0,
        'notes': notes,
        'source': source,
        'fingerprint': fingerprint,
      };

  static Txn fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as String,
        accountId: m['account_id'] as String,
        amountCents: (m['amount_cents'] as num).toInt(),
        date: m['date'] as String,
        merchant: m['merchant'] as String,
        rawDesc: m['raw_desc'] as String?,
        categoryId: (m['category_id'] as String?) ?? 'other.uncategorized',
        categorySource: (m['category_source'] as String?) ?? 'manual',
        isTransfer: (m['is_transfer'] as num?) == 1,
        notes: (m['notes'] as String?) ?? '',
        source: (m['source'] as String?) ?? 'manual',
        fingerprint: (m['fingerprint'] as String?) ?? '',
      );
}

class Budget {
  final String id;
  String categoryId;
  int limitCents; // per month

  Budget({required this.id, required this.categoryId, required this.limitCents});

  Map<String, Object?> toMap() =>
      {'id': id, 'category_id': categoryId, 'limit_cents': limitCents};

  static Budget fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        limitCents: (m['limit_cents'] as num).toInt(),
      );
}

class Goal {
  final String id;
  String name;
  String emoji;
  int targetCents;
  int savedCents;
  String? targetDate; // yyyy-MM-dd, optional

  Goal({
    required this.id,
    required this.name,
    this.emoji = '🎯',
    required this.targetCents,
    this.savedCents = 0,
    this.targetDate,
  });

  double get progress =>
      targetCents <= 0 ? 0 : (savedCents / targetCents).clamp(0.0, 1.0);

  /// Cents per month needed to hit target by targetDate (null if no date).
  int? requiredMonthly(DateTime now) {
    if (targetDate == null) return null;
    final end = parseDateKey(targetDate!);
    final months =
        (end.year - now.year) * 12 + (end.month - now.month);
    final remaining = targetCents - savedCents;
    if (remaining <= 0) return 0;
    return months <= 0 ? remaining : (remaining / months).ceil();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'target_cents': targetCents,
        'saved_cents': savedCents,
        'target_date': targetDate,
      };

  static Goal fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: (m['emoji'] as String?) ?? '🎯',
        targetCents: (m['target_cents'] as num).toInt(),
        savedCents: (m['saved_cents'] as num).toInt(),
        targetDate: m['target_date'] as String?,
      );
}

enum Cadence { weekly, biweekly, monthly, quarterly, yearly }

extension CadenceLabel on Cadence {
  String get label => switch (this) {
        Cadence.weekly => 'Weekly',
        Cadence.biweekly => 'Every 2 weeks',
        Cadence.monthly => 'Monthly',
        Cadence.quarterly => 'Quarterly',
        Cadence.yearly => 'Yearly',
      };

  /// Approximate cost multiplier to express the series as a monthly amount.
  double get perMonthFactor => switch (this) {
        Cadence.weekly => 52 / 12,
        Cadence.biweekly => 26 / 12,
        Cadence.monthly => 1,
        Cadence.quarterly => 1 / 3,
        Cadence.yearly => 1 / 12,
      };
}

/// A detected recurring money flow (subscription, bill, or paycheck).
class RecurringSeries {
  final String merchantKey;
  final String displayName;
  final Cadence cadence;
  final int typicalAmountCents; // most recent typical amount (signed)
  final String lastDate;
  final String nextExpectedDate;
  final int occurrences;
  final double confidence;
  final String categoryId;

  /// Non-null when the most recent amount differs from the prior typical
  /// amount — i.e. a detected price change. Value is the previous amount.
  final int? previousAmountCents;

  const RecurringSeries({
    required this.merchantKey,
    required this.displayName,
    required this.cadence,
    required this.typicalAmountCents,
    required this.lastDate,
    required this.nextExpectedDate,
    required this.occurrences,
    required this.confidence,
    required this.categoryId,
    this.previousAmountCents,
  });

  bool get isIncome => typicalAmountCents > 0;

  int get monthlyCostCents =>
      (typicalAmountCents.abs() * cadence.perMonthFactor).round();
}
