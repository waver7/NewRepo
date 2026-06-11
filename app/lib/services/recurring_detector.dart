/// Recurring/subscription detection — the local implementation of the
/// algorithm in docs/11: group by merchant, score gap-sequence periodicity
/// and amount stability, classify cadence, predict the next charge, and flag
/// price changes.
library;

import 'dart:math' as math;

import '../models/models.dart';
import 'categorizer.dart';

class RecurringDetector {
  /// Cadences with (expected gap in days, tolerance in days).
  static const _cadences = <(Cadence, int, int)>[
    (Cadence.weekly, 7, 2),
    (Cadence.biweekly, 14, 3),
    (Cadence.monthly, 30, 5),
    (Cadence.quarterly, 91, 10),
    (Cadence.yearly, 365, 20),
  ];

  static List<RecurringSeries> detect(List<Txn> txns, {DateTime? now}) {
    now ??= DateTime.now();
    final result = <RecurringSeries>[];

    // Group by merchant key + sign; transfers don't form subscriptions.
    final groups = <String, List<Txn>>{};
    for (final t in txns) {
      if (t.isTransfer || t.amountCents == 0) continue;
      final key =
          '${Categorizer.merchantKey(t.rawDesc)}|${t.amountCents > 0 ? '+' : '-'}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    for (final entry in groups.entries) {
      final group = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (group.length < 2) continue;

      // Collapse same-day charges (split shipments etc.) to one occurrence.
      final byDay = <String, Txn>{};
      for (final t in group) {
        byDay[t.date] = t;
      }
      final occ = byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      if (occ.length < 2) continue;

      final gaps = <int>[];
      for (var i = 1; i < occ.length; i++) {
        gaps.add(occ[i].dateTime.difference(occ[i - 1].dateTime).inDays);
      }

      // Find the cadence that matches the most gaps.
      Cadence? best;
      var bestMatches = 0;
      for (final (cadence, expected, tol) in _cadences) {
        final matches =
            gaps.where((g) => (g - expected).abs() <= tol).length;
        if (matches > bestMatches) {
          bestMatches = matches;
          best = cadence;
        }
      }
      if (best == null || bestMatches == 0) continue;

      final periodicityScore = bestMatches / gaps.length;

      // Amount stability: coefficient of variation of absolute amounts.
      final amounts = occ.map((t) => t.amountCents.abs().toDouble()).toList();
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance = amounts
              .map((a) => (a - mean) * (a - mean))
              .reduce((a, b) => a + b) /
          amounts.length;
      final cv = mean == 0 ? 1.0 : math.sqrt(variance) / mean;
      final amountScore = (1 - (cv / 0.5)).clamp(0.0, 1.0);

      final countScore = ((occ.length - 1) / 3).clamp(0.0, 1.0);

      final confidence =
          0.5 * periodicityScore + 0.3 * amountScore + 0.2 * countScore;
      // 2 occurrences with a perfect gap can pass; noise can't.
      if (confidence < 0.55) continue;

      final last = occ.last;
      final expectedGap = _cadences.firstWhere((c) => c.$1 == best).$2;
      final nextDate = last.dateTime.add(Duration(days: expectedGap));

      // Stale series: if the next expected charge is long past, it ended.
      if (now.difference(nextDate).inDays > expectedGap + 15) continue;

      // Price change: latest amount vs the mode of earlier amounts.
      int? previousAmount;
      if (occ.length >= 3) {
        final earlier = occ.sublist(0, occ.length - 1);
        final freq = <int, int>{};
        for (final t in earlier) {
          freq[t.amountCents] = (freq[t.amountCents] ?? 0) + 1;
        }
        final typicalEarlier =
            (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;
        final delta = (last.amountCents - typicalEarlier).abs();
        if (delta >= 50 && delta >= typicalEarlier.abs() * 0.02) {
          previousAmount = typicalEarlier;
        }
      }

      result.add(RecurringSeries(
        merchantKey: entry.key,
        displayName: last.merchant,
        cadence: best,
        typicalAmountCents: last.amountCents,
        lastDate: last.date,
        nextExpectedDate: dateKey(nextDate),
        occurrences: occ.length,
        confidence: double.parse(confidence.toStringAsFixed(2)),
        categoryId: last.categoryId,
        previousAmountCents: previousAmount,
      ));
    }

    result.sort((a, b) => b.monthlyCostCents.compareTo(a.monthlyCostCents));
    return result;
  }
}
