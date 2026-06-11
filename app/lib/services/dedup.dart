/// Duplicate detection (docs/07 §7.4): exact fingerprint tier plus a fuzzy
/// tier for the cross-source case (same purchase arriving via CSV import and
/// manual entry with slightly different dates/descriptors).
library;

import '../models/models.dart';
import 'categorizer.dart';

class Dedup {
  /// Exact-tier fingerprint: account + amount + date + descriptor prefix.
  static String fingerprint(
      String accountId, int amountCents, String date, String rawDesc) {
    final prefix = Categorizer.normalize(rawDesc);
    final p = prefix.length > 12 ? prefix.substring(0, 12) : prefix;
    return '$accountId|$amountCents|$date|$p';
  }

  /// Token-overlap similarity between two descriptors (0..1). Uses the
  /// overlap coefficient (intersection / smaller set) rather than Jaccard so
  /// that bank-added decorations ("STORE", city names) don't mask a match.
  static double descriptorSimilarity(String a, String b) {
    final ta = Categorizer.normalize(a).split(' ').where((t) => t.isNotEmpty).toSet();
    final tb = Categorizer.normalize(b).split(' ').where((t) => t.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0;
    final inter = ta.intersection(tb).length;
    final smaller = ta.length < tb.length ? ta.length : tb.length;
    return inter / smaller;
  }

  /// Fuzzy tier: same account, same amount, dates within [dayTolerance],
  /// similar descriptor -> considered the same real-world transaction.
  static bool isLikelyDuplicate(Txn a, Txn b, {int dayTolerance = 3}) {
    if (a.accountId != b.accountId) return false;
    if (a.amountCents != b.amountCents) return false;
    final dayDiff = a.dateTime.difference(b.dateTime).inDays.abs();
    if (dayDiff > dayTolerance) return false;
    if (dayDiff == 0 && a.fingerprint == b.fingerprint) return true;
    return descriptorSimilarity(a.rawDesc, b.rawDesc) >= 0.5;
  }

  /// Splits [incoming] into rows to import and rows that duplicate something
  /// in [existing] (or earlier rows of the same batch).
  static ({List<Txn> fresh, List<Txn> duplicates}) partition(
      List<Txn> incoming, List<Txn> existing) {
    final fresh = <Txn>[];
    final duplicates = <Txn>[];
    final seenFingerprints = {for (final t in existing) t.fingerprint};
    // Index existing txns by amount for cheap fuzzy candidate lookup.
    final byAmount = <int, List<Txn>>{};
    for (final t in existing) {
      byAmount.putIfAbsent(t.amountCents, () => []).add(t);
    }

    for (final t in incoming) {
      if (t.fingerprint.isNotEmpty && seenFingerprints.contains(t.fingerprint)) {
        duplicates.add(t);
        continue;
      }
      final candidates = byAmount[t.amountCents] ?? const [];
      final isDup = candidates.any((c) => isLikelyDuplicate(t, c));
      if (isDup) {
        duplicates.add(t);
      } else {
        fresh.add(t);
        seenFingerprints.add(t.fingerprint);
        byAmount.putIfAbsent(t.amountCents, () => []).add(t);
      }
    }
    return (fresh: fresh, duplicates: duplicates);
  }
}
