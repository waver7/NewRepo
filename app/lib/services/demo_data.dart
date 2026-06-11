/// Deterministic synthetic ledger for demo mode and manual testing: 6 months
/// of paychecks, rent, utilities, subscriptions (including a planted price
/// increase), groceries, restaurants, gas, transfers and a duplicate pair —
/// so every feature of the app can be exercised without linking anything.
library;

import 'dart:math';

import '../models/models.dart';
import 'categorizer.dart';
import 'dedup.dart';

class DemoData {
  static ({List<Account> accounts, List<Txn> txns}) generate({DateTime? now}) {
    now ??= DateTime.now();
    final rnd = Random(42); // deterministic
    final checking = Account(
        id: 'acc-checking',
        name: 'Everyday Checking',
        type: AccountType.checking,
        startingBalanceCents: 412000);
    final card = Account(
        id: 'acc-card',
        name: 'Rewards Visa',
        type: AccountType.creditCard,
        startingBalanceCents: 0);
    final savings = Account(
        id: 'acc-savings',
        name: 'High-Yield Savings',
        type: AccountType.savings,
        startingBalanceCents: 580000);

    final categorizer = Categorizer();
    final txns = <Txn>[];

    void add(String accountId, DateTime date, int cents, String rawDesc) {
      if (date.isAfter(now!)) return;
      final d = dateKey(date);
      final cat = categorizer.categorize(rawDesc, cents);
      final isTransfer =
          Categories.get(cat.categoryId).kind == CategoryKind.transfer;
      txns.add(Txn(
        id: newId(),
        accountId: accountId,
        amountCents: cents,
        date: d,
        merchant: cat.cleanedMerchant,
        rawDesc: rawDesc,
        categoryId: cat.categoryId,
        categorySource: cat.source,
        isTransfer: isTransfer,
        source: 'demo',
        fingerprint: Dedup.fingerprint(accountId, cents, d, rawDesc),
      ));
    }

    final monthStart = DateTime(now.year, now.month - 5, 1);

    // Biweekly paycheck, anchored to a Friday.
    var pay = monthStart;
    while (pay.weekday != DateTime.friday) {
      pay = pay.add(const Duration(days: 1));
    }
    while (!pay.isAfter(now)) {
      add(checking.id, pay, 245000, 'ACME CORP PAYROLL DIRECT DEP');
      pay = pay.add(const Duration(days: 14));
    }

    for (var m = 0; m < 6; m++) {
      final mo = DateTime(monthStart.year, monthStart.month + m, 1);

      // Fixed monthly bills from checking.
      add(checking.id, DateTime(mo.year, mo.month, 1), -145000,
          'OAKWOOD APARTMENTS RENT');
      add(checking.id, DateTime(mo.year, mo.month, 5),
          -(8200 + rnd.nextInt(4500)), 'PG&E ELECTRIC UTILITY');
      add(checking.id, DateTime(mo.year, mo.month, 8), -6999,
          'COMCAST XFINITY INTERNET');
      add(checking.id, DateTime(mo.year, mo.month, 12), -4500,
          'MINT MOBILE PAYMENT');
      add(checking.id, DateTime(mo.year, mo.month, 16), -15400,
          'GEICO AUTO INSURANCE');
      // Monthly transfer to savings (both legs -> excluded from spend math).
      add(checking.id, DateTime(mo.year, mo.month, 2), -40000,
          'ONLINE TRANSFER TO SAVINGS XXXX8821');
      add(savings.id, DateTime(mo.year, mo.month, 2), 40000,
          'ONLINE TRANSFER FROM CHECKING XXXX1044');
      // Card autopay pair.
      add(checking.id, DateTime(mo.year, mo.month, 20), -52000,
          'CREDIT CARD PAYMENT AUTOPAY VISA');
      add(card.id, DateTime(mo.year, mo.month, 20), 52000,
          'PAYMENT THANK YOU');

      // Subscriptions on the card — Spotify gets a price hike 2 months ago.
      add(card.id, DateTime(mo.year, mo.month, 3), -1799, 'NETFLIX.COM');
      final spotifyPrice = m >= 4 ? -1199 : -1099;
      add(card.id, DateTime(mo.year, mo.month, 7), spotifyPrice,
          'SPOTIFY USA');
      add(card.id, DateTime(mo.year, mo.month, 11), -999, 'ICLOUD STORAGE');
      add(card.id, DateTime(mo.year, mo.month, 15), -1495, 'AUDIBLE*MEMBERSHIP');
      add(card.id, DateTime(mo.year, mo.month, 22), -2999,
          'PLANET FIT MEMBERSHIP');

      // Weekly-ish groceries.
      for (final day in [4, 11, 18, 25]) {
        add(card.id, DateTime(mo.year, mo.month, day),
            -(6500 + rnd.nextInt(5500)), 'TRADER JOE S #553');
      }
      // Restaurants / coffee / delivery, a handful per month.
      final eats = [
        'CHIPOTLE ONLINE', 'SQ *BLUEBTL COFFEE 4421', 'STARBUCKS STORE 0091',
        'DOORDASH*THAI PALACE', 'SWEETGREEN NOMAD', 'SHAKE SHACK #1102',
      ];
      for (var i = 0; i < 8; i++) {
        final day = 1 + rnd.nextInt(27);
        add(card.id, DateTime(mo.year, mo.month, day),
            -(900 + rnd.nextInt(4200)), eats[rnd.nextInt(eats.length)]);
      }
      // Gas + rideshare.
      add(card.id, DateTime(mo.year, mo.month, 9),
          -(4200 + rnd.nextInt(2200)), 'CHEVRON 0204955');
      add(card.id, DateTime(mo.year, mo.month, 19),
          -(1400 + rnd.nextInt(1800)), 'UBER *TRIP');
      // Shopping & pharmacy.
      add(card.id, DateTime(mo.year, mo.month, 13),
          -(2500 + rnd.nextInt(9000)), 'AMZN MKTP US*RT4G87');
      add(card.id, DateTime(mo.year, mo.month, 26),
          -(1200 + rnd.nextInt(2800)), 'CVS/PHARMACY #04821');
      // Savings interest.
      add(savings.id, DateTime(mo.year, mo.month, 28),
          2100 + rnd.nextInt(400), 'INTEREST PAYMENT');
    }

    // A planted same-day duplicate pair (possible double charge) last month.
    final lastMonth = DateTime(now.year, now.month - 1, 17);
    add(card.id, lastMonth, -1250, 'SHELL OIL 5744');
    add(card.id, lastMonth, -1250, 'SHELL OIL 5744');

    txns.sort((a, b) => b.date.compareTo(a.date));
    return (accounts: [checking, card, savings], txns: txns);
  }
}
