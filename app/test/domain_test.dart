import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/models.dart';
import 'package:lumen/services/categorizer.dart';
import 'package:lumen/services/csv_importer.dart';
import 'package:lumen/services/dedup.dart';
import 'package:lumen/services/demo_data.dart';
import 'package:lumen/services/recurring_detector.dart';
import 'package:lumen/services/stats.dart';

Txn txn(String account, int cents, String date, String desc) => Txn(
      id: newId(),
      accountId: account,
      amountCents: cents,
      date: date,
      merchant: Categorizer.displayName(desc),
      rawDesc: desc,
      fingerprint: Dedup.fingerprint(account, cents, date, desc),
    );

void main() {
  group('Categorizer', () {
    final c = Categorizer();

    test('normalizes processor prefixes and store numbers', () {
      expect(Categorizer.normalize('SQ *BLUEBTL COFFEE 4421'),
          'BLUEBTL COFFEE');
      expect(Categorizer.normalize('AMZN Mktp US*RT4G87'), isNot(contains('*')));
    });

    test('categorizes known merchants', () {
      expect(c.categorize('NETFLIX.COM', -1799).categoryId, 'fun.streaming');
      expect(c.categorize('TRADER JOE S #553', -8200).categoryId,
          'food.groceries');
      expect(c.categorize('SHELL OIL 5744', -4500).categoryId, 'transport.gas');
      expect(c.categorize('SQ *BLUEBTL COFFEE 4421', -650).categoryId,
          'food.coffee');
      expect(c.categorize('ACME CORP PAYROLL DIRECT DEP', 245000).categoryId,
          'income.salary');
    });

    test('specific keywords beat generic ones (UBER EATS vs UBER)', () {
      expect(c.categorize('UBER EATS PENDING', -2300).categoryId,
          'food.delivery');
      expect(c.categorize('UBER *TRIP', -1400).categoryId,
          'transport.rideshare');
    });

    test('income keywords do not fire on outflows', () {
      // "REFUND" maps to income.refund but this is an outflow.
      final r = c.categorize('REFUND PROCESSING LLC', -5000);
      expect(Categories.get(r.categoryId).kind, isNot(CategoryKind.income));
    });

    test('transfers detected', () {
      expect(
          c.categorize('ONLINE TRANSFER TO SAVINGS', -40000).categoryId,
          'transfer.internal');
      expect(c.categorize('PAYMENT THANK YOU', 52000).categoryId,
          'transfer.cc_payment');
    });

    test('user corrections win and persist (learning loop)', () {
      final cc = Categorizer();
      expect(cc.categorize('TARGET 00123', -5000).categoryId,
          'shopping.general');
      cc.learn('TARGET 00123', 'food.groceries');
      final after = cc.categorize('TARGET 0088', -3000);
      expect(after.categoryId, 'food.groceries');
      expect(after.source, 'user');
    });
  });

  group('Dedup', () {
    test('identical rows share a fingerprint', () {
      final a = txn('acc', -1250, '2026-05-17', 'SHELL OIL 5744');
      final b = txn('acc', -1250, '2026-05-17', 'SHELL OIL 5744');
      expect(a.fingerprint, b.fingerprint);
    });

    test('fuzzy match catches differently-worded duplicates within 3 days',
        () {
      final a = txn('acc', -4599, '2026-05-10', 'STARBUCKS #1234 SEATTLE');
      final b = txn('acc', -4599, '2026-05-12', 'STARBUCKS STORE 1234');
      expect(Dedup.isLikelyDuplicate(a, b), isTrue);
    });

    test('different amounts are never duplicates', () {
      final a = txn('acc', -4599, '2026-05-10', 'STARBUCKS #1234');
      final b = txn('acc', -4598, '2026-05-10', 'STARBUCKS #1234');
      expect(Dedup.isLikelyDuplicate(a, b), isFalse);
    });

    test('partition: re-importing the same batch yields zero fresh rows', () {
      final batch = [
        txn('acc', -1000, '2026-05-01', 'COFFEE SHOP'),
        txn('acc', -2000, '2026-05-02', 'GROCERY MART'),
      ];
      final first = Dedup.partition(batch, []);
      expect(first.fresh.length, 2);
      final second = Dedup.partition(batch, first.fresh);
      expect(second.fresh, isEmpty);
      expect(second.duplicates.length, 2);
    });
  });

  group('RecurringDetector', () {
    test('detects monthly subscription with exact cadence', () {
      final now = DateTime(2026, 6, 10);
      final txns = [
        for (final m in [1, 2, 3, 4, 5])
          txn('card', -1799, '2026-0$m-03', 'NETFLIX.COM'),
      ];
      final series = RecurringDetector.detect(txns, now: now);
      expect(series, hasLength(1));
      expect(series.first.cadence, Cadence.monthly);
      expect(series.first.occurrences, 5);
      expect(series.first.nextExpectedDate, startsWith('2026-06'));
    });

    test('detects biweekly paycheck', () {
      final now = DateTime(2026, 3, 20);
      final dates = ['2026-01-02', '2026-01-16', '2026-01-30',
          '2026-02-13', '2026-02-27', '2026-03-13'];
      final txns = [
        for (final d in dates) txn('chk', 245000, d, 'ACME PAYROLL'),
      ];
      final series = RecurringDetector.detect(txns, now: now);
      expect(series, hasLength(1));
      expect(series.first.cadence, Cadence.biweekly);
      expect(series.first.isIncome, isTrue);
    });

    test('flags a price increase', () {
      final now = DateTime(2026, 6, 10);
      final txns = [
        txn('card', -1099, '2026-01-07', 'SPOTIFY USA'),
        txn('card', -1099, '2026-02-07', 'SPOTIFY USA'),
        txn('card', -1099, '2026-03-07', 'SPOTIFY USA'),
        txn('card', -1199, '2026-04-07', 'SPOTIFY USA'),
      ];
      // Use the most recent occurrence window.
      final series = RecurringDetector.detect(txns,
          now: DateTime(2026, 4, 20));
      expect(series, hasLength(1));
      expect(series.first.previousAmountCents, -1099);
      expect(series.first.typicalAmountCents, -1199);
      expect(now, isNotNull);
    });

    test('random one-off merchants are not recurring', () {
      final txns = [
        txn('card', -1234, '2026-01-03', 'RANDOM BISTRO'),
        txn('card', -8821, '2026-01-25', 'RANDOM BISTRO'),
        txn('card', -451, '2026-02-02', 'RANDOM BISTRO'),
      ];
      final series =
          RecurringDetector.detect(txns, now: DateTime(2026, 2, 10));
      expect(series, isEmpty);
    });
  });

  group('CsvImporter', () {
    test('parses quoted fields and commas', () {
      final t = CsvImporter.parse(
          'Date,Description,Amount\n'
          '01/15/2026,"COSTCO, WHSE #44",-128.53\n'
          '01/16/2026,PAYCHECK,"2,450.00"\n');
      expect(t.header, ['Date', 'Description', 'Amount']);
      expect(t.rows, hasLength(2));
      expect(t.rows[0][1], 'COSTCO, WHSE #44');
    });

    test('infers mapping from headers and imports rows', () {
      final t = CsvImporter.parse(
          'Posted Date,Payee,Amount\n'
          '2026-01-15,TRADER JOES,-82.10\n'
          '2026-01-16,ACME PAYROLL,2450.00\n');
      final m = CsvImporter.inferMapping(t);
      expect(m.dateCol, 0);
      expect(m.descCol, 1);
      expect(m.amountCol, 2);
      final rows = CsvImporter.buildRows(t, m);
      expect(rows, hasLength(2));
      expect(rows[0].amountCents, -8210);
      expect(rows[0].date, '2026-01-15');
      expect(rows[1].amountCents, 245000);
    });

    test('handles separate debit/credit columns', () {
      final t = CsvImporter.parse(
          'Date,Description,Debit,Credit\n'
          '01/15/2026,GROCERY,82.10,\n'
          '01/16/2026,DEPOSIT,,500.00\n');
      final m = CsvImporter.inferMapping(t);
      expect(m.debitCol, 2);
      expect(m.creditCol, 3);
      final rows = CsvImporter.buildRows(t, m);
      expect(rows[0].amountCents, -8210);
      expect(rows[1].amountCents, 50000);
    });

    test('disambiguates DD/MM dates from column contents', () {
      final t = CsvImporter.parse(
          'Date,Description,Amount\n'
          '25/01/2026,SHOP,-10.00\n'
          '03/02/2026,SHOP,-10.00\n');
      final m = CsvImporter.inferMapping(t);
      expect(m.dateFormat, 'dmy');
      final rows = CsvImporter.buildRows(t, m);
      expect(rows[0].date, '2026-01-25');
      expect(rows[1].date, '2026-02-03');
    });

    test('amount parsing handles every bank convention', () {
      expect(CsvImporter.parseAmountCents(r'$1,234.56'), 123456);
      expect(CsvImporter.parseAmountCents('(45.00)'), -4500);
      expect(CsvImporter.parseAmountCents('45.00-'), -4500);
      expect(CsvImporter.parseAmountCents('1.234,56'), 123456);
      expect(CsvImporter.parseAmountCents('-12'), -1200);
      expect(CsvImporter.parseAmountCents(''), isNull);
      expect(CsvImporter.parseAmountCents('abc'), isNull);
    });
  });

  group('Stats', () {
    test('transfers are excluded from income/expense', () {
      final txns = [
        txn('chk', 245000, '2026-05-01', 'ACME PAYROLL'),
        txn('chk', -100000, '2026-05-02', 'RENT'),
        txn('chk', -40000, '2026-05-03', 'TRANSFER TO SAVINGS')
          ..isTransfer = true,
        txn('sav', 40000, '2026-05-03', 'TRANSFER FROM CHECKING')
          ..isTransfer = true,
      ];
      final s = Stats.forMonth(txns, '2026-05');
      expect(s.incomeCents, 245000);
      expect(s.expenseCents, 100000);
      expect(s.netCents, 145000);
      expect(s.savingsRate, closeTo(145000 / 245000, 0.001));
    });

    test('category and merchant breakdowns rank by spend', () {
      final txns = [
        txn('c', -5000, '2026-05-01', 'A')..categoryId = 'food.groceries',
        txn('c', -3000, '2026-05-02', 'B')..categoryId = 'food.groceries',
        txn('c', -2000, '2026-05-03', 'C')..categoryId = 'fun.streaming',
      ];
      final cats = Stats.byCategory(txns, '2026-05');
      expect(cats.first.categoryId, 'food.groceries');
      expect(cats.first.cents, 8000);
      expect(cats[1].cents, 2000);
    });

    test('account balance = starting balance + transactions', () {
      final a = Account(
          id: 'x', name: 'X', type: AccountType.checking,
          startingBalanceCents: 10000);
      final txns = [
        txn('x', -2500, '2026-05-01', 'COFFEE'),
        txn('x', 5000, '2026-05-02', 'DEPOSIT'),
        txn('other', -99999, '2026-05-02', 'NOT MINE'),
      ];
      expect(Stats.accountBalance(a, txns), 12500);
    });
  });

  group('DemoData', () {
    final demo = DemoData.generate(now: DateTime(2026, 6, 10));

    test('generates a populated multi-account ledger', () {
      expect(demo.accounts, hasLength(3));
      expect(demo.txns.length, greaterThan(150));
    });

    test('detects the planted subscriptions including the price hike', () {
      final series = RecurringDetector.detect(demo.txns,
          now: DateTime(2026, 6, 10));
      final names = series.map((s) => s.displayName.toUpperCase()).toList();
      expect(names.any((n) => n.contains('NETFLIX')), isTrue);
      expect(names.any((n) => n.contains('SPOTIFY')), isTrue);
      final spotify = series.firstWhere(
          (s) => s.displayName.toUpperCase().contains('SPOTIFY'));
      expect(spotify.previousAmountCents, isNotNull,
          reason: 'the planted Spotify price increase should be flagged');
    });

    test('paycheck is detected as recurring income', () {
      final series = RecurringDetector.detect(demo.txns,
          now: DateTime(2026, 6, 10));
      expect(series.any((s) => s.isIncome && s.cadence == Cadence.biweekly),
          isTrue);
    });

    test('transfers are excluded so income reflects salary only', () {
      final months = Stats.lastMonths(demo.txns, '2026-05', 3);
      for (final m in months) {
        // Salary is 2450 x 2 or x3 per month; transfers (400/mo) must not
        // inflate income beyond paychecks + small interest.
        expect(m.incomeCents, lessThan(3 * 245000 + 5000));
        expect(m.incomeCents, greaterThan(2 * 245000 - 1));
      }
    });

    test('goal pace math', () {
      final g = Goal(
          id: 'g', name: 'House', targetCents: 1200000, savedCents: 600000,
          targetDate: '2026-12-10');
      // 6 months out from 2026-06-10, 6000.00 remaining -> 1000/mo.
      expect(g.requiredMonthly(DateTime(2026, 6, 10)), 100000);
    });
  });
}
