/// CSV import with smart column mapping (docs/10): RFC-4180-ish parser,
/// header heuristics for date/amount/description columns, date-format
/// disambiguation by scanning the whole column, and support for both signed
/// single-amount and separate debit/credit layouts.
library;

import '../models/models.dart';
import 'categorizer.dart';
import 'dedup.dart';

class CsvTable {
  final List<String> header;
  final List<List<String>> rows;
  const CsvTable(this.header, this.rows);
}

class ColumnMapping {
  int? dateCol;
  int? amountCol; // single signed amount column
  int? debitCol; // separate debit column (positive numbers = money out)
  int? creditCol;
  int? descCol;
  String dateFormat; // 'ymd' | 'mdy' | 'dmy'
  bool flipSign; // some banks export expenses as positive in the amount col

  ColumnMapping({
    this.dateCol,
    this.amountCol,
    this.debitCol,
    this.creditCol,
    this.descCol,
    this.dateFormat = 'ymd',
    this.flipSign = false,
  });

  bool get isUsable =>
      dateCol != null &&
      descCol != null &&
      (amountCol != null || debitCol != null || creditCol != null);
}

class ImportPreviewRow {
  final String date;
  final int amountCents;
  final String description;
  const ImportPreviewRow(this.date, this.amountCents, this.description);
}

class CsvImporter {
  /// Parses CSV text handling quoted fields, embedded commas/newlines and
  /// both \n and \r\n line endings. Auto-detects ',' vs ';' vs tab delimiter.
  static CsvTable parse(String text) {
    final delimiter = _sniffDelimiter(text);
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == delimiter) {
        row.add(field.toString());
        field = StringBuffer();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
    }
    if (rows.isEmpty) return const CsvTable([], []);
    // Find the header row: first row where at least one cell looks like a
    // known header word (banks sometimes put a title/logo line above).
    var headerIdx = 0;
    for (var i = 0; i < rows.length && i < 5; i++) {
      if (rows[i].any((c) => _headerWords.contains(_norm(c)))) {
        headerIdx = i;
        break;
      }
    }
    final header = rows[headerIdx].map((h) => h.trim()).toList();
    return CsvTable(header, rows.sublist(headerIdx + 1));
  }

  static String _sniffDelimiter(String text) {
    final firstLine = text.split('\n').first;
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static const _headerWords = {
    'date', 'transactiondate', 'postdate', 'posteddate', 'postingdate',
    'amount', 'debit', 'credit', 'description', 'payee', 'memo', 'merchant',
    'details', 'transaction', 'name', 'category', 'fecha', 'montant', 'betrag',
  };

  static const _dateHeaders = [
    'transactiondate', 'postdate', 'posteddate', 'postingdate', 'date', 'fecha',
  ];
  static const _amountHeaders = ['amount', 'montant', 'betrag', 'importe'];
  static const _debitHeaders = ['debit', 'withdrawal', 'moneyout', 'paidout'];
  static const _creditHeaders = ['credit', 'deposit', 'moneyin', 'paidin'];
  static const _descHeaders = [
    'description', 'payee', 'merchant', 'details', 'memo', 'name',
    'transaction', 'narrative',
  ];

  /// Heuristic column mapping from header names, validated/refined against
  /// the data rows (date-format disambiguation, sign-convention detection).
  static ColumnMapping inferMapping(CsvTable table) {
    final m = ColumnMapping();
    final normHeader = table.header.map(_norm).toList();

    int? findCol(List<String> names) {
      for (final n in names) {
        final i = normHeader.indexWhere((h) => h == n);
        if (i != -1) return i;
      }
      for (final n in names) {
        final i = normHeader.indexWhere((h) => h.contains(n));
        if (i != -1) return i;
      }
      return null;
    }

    m.dateCol = findCol(_dateHeaders);
    m.amountCol = findCol(_amountHeaders);
    m.debitCol = findCol(_debitHeaders);
    m.creditCol = findCol(_creditHeaders);
    m.descCol = findCol(_descHeaders);
    // If both debit/credit exist, prefer them over a possibly-derived amount.
    if (m.debitCol != null && m.creditCol != null) m.amountCol = null;

    // Content-based fallback: find a column that parses as dates / numbers.
    final sample = table.rows.take(20).toList();
    if (m.dateCol == null) {
      for (var c = 0; c < table.header.length; c++) {
        final ok = sample
            .where((r) => c < r.length && _looksLikeDate(r[c]))
            .length;
        if (sample.isNotEmpty && ok >= sample.length * 0.8) {
          m.dateCol = c;
          break;
        }
      }
    }
    if (m.amountCol == null && m.debitCol == null && m.creditCol == null) {
      for (var c = 0; c < table.header.length; c++) {
        if (c == m.dateCol) continue;
        final ok = sample
            .where((r) => c < r.length && parseAmountCents(r[c]) != null)
            .length;
        if (sample.isNotEmpty && ok >= sample.length * 0.8) {
          m.amountCol = c;
          break;
        }
      }
    }
    if (m.descCol == null) {
      // Longest average text column that is neither date nor amount.
      var bestLen = 0.0;
      for (var c = 0; c < table.header.length; c++) {
        if (c == m.dateCol || c == m.amountCol) continue;
        final lens = sample
            .where((r) => c < r.length)
            .map((r) => r[c].trim().length)
            .toList();
        if (lens.isEmpty) continue;
        final avg = lens.reduce((a, b) => a + b) / lens.length;
        if (avg > bestLen) {
          bestLen = avg;
          m.descCol = c;
        }
      }
    }

    // Date-format disambiguation across the whole column: if any value has
    // first part > 12 it's day-first; if any second part > 12 it's month-first.
    if (m.dateCol != null) {
      m.dateFormat = _inferDateFormat(
          table.rows.map((r) => m.dateCol! < r.length ? r[m.dateCol!] : ''));
    }
    return m;
  }

  static bool _looksLikeDate(String s) => _parseDate(s.trim(), 'mdy') != null;

  static String _inferDateFormat(Iterable<String> values) {
    var sawIso = false;
    var firstGt12 = false;
    var secondGt12 = false;
    for (final v in values) {
      final t = v.trim();
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}').hasMatch(t)) {
        sawIso = true;
        continue;
      }
      final parts = t.split(RegExp(r'[/.\-]'));
      if (parts.length != 3) continue;
      final a = int.tryParse(parts[0]) ?? 0;
      final b = int.tryParse(parts[1]) ?? 0;
      if (a > 12 && a <= 31) firstGt12 = true;
      if (b > 12 && b <= 31) secondGt12 = true;
    }
    if (sawIso) return 'ymd';
    if (firstGt12) return 'dmy';
    if (secondGt12) return 'mdy';
    return 'mdy'; // US default when truly ambiguous
  }

  static DateTime? _parseDate(String s, String format) {
    final t = s.trim();
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    final parts = t.split(RegExp(r'[/.\-]'));
    if (parts.length != 3) return null;
    final nums = parts.map((p) => int.tryParse(p.trim())).toList();
    if (nums.any((n) => n == null)) return null;
    int y, mo, d;
    if (parts[0].length == 4) {
      y = nums[0]!;
      mo = nums[1]!;
      d = nums[2]!;
    } else if (format == 'dmy') {
      d = nums[0]!;
      mo = nums[1]!;
      y = nums[2]!;
    } else {
      mo = nums[0]!;
      d = nums[1]!;
      y = nums[2]!;
    }
    if (y < 100) y += 2000;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// Parses "$1,234.56", "(45.00)", "1.234,56", "45.00-", "−45" → cents.
  static int? parseAmountCents(String s) {
    var t = s.trim();
    if (t.isEmpty) return null;
    var negative = false;
    if (t.startsWith('(') && t.endsWith(')')) {
      negative = true;
      t = t.substring(1, t.length - 1);
    }
    if (t.endsWith('-')) {
      negative = true;
      t = t.substring(0, t.length - 1);
    }
    if (t.startsWith('-') || t.startsWith('−')) {
      negative = true;
      t = t.substring(1);
    }
    if (t.startsWith('+')) t = t.substring(1);
    t = t.replaceAll(RegExp(r'[^\d.,]'), '');
    if (t.isEmpty) return null;
    // European format "1.234,56" → comma is the decimal separator.
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma > lastDot) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
    final v = double.tryParse(t);
    if (v == null) return null;
    final cents = (v * 100).round();
    return negative ? -cents : cents;
  }

  /// Materializes preview rows using a mapping. Invalid rows are skipped.
  static List<ImportPreviewRow> buildRows(CsvTable table, ColumnMapping m) {
    final out = <ImportPreviewRow>[];
    if (!m.isUsable) return out;
    for (final r in table.rows) {
      String cell(int? c) => (c != null && c < r.length) ? r[c] : '';
      final date = _parseDate(cell(m.dateCol), m.dateFormat);
      if (date == null) continue;
      int? amount;
      if (m.amountCol != null) {
        amount = parseAmountCents(cell(m.amountCol));
        if (amount != null && m.flipSign) amount = -amount;
      } else {
        final debit = parseAmountCents(cell(m.debitCol)) ?? 0;
        final credit = parseAmountCents(cell(m.creditCol)) ?? 0;
        amount = credit.abs() - debit.abs();
      }
      if (amount == null) continue;
      final desc = cell(m.descCol).trim();
      if (desc.isEmpty && amount == 0) continue;
      out.add(ImportPreviewRow(dateKey(date), amount, desc));
    }
    return out;
  }

  /// Converts preview rows into transactions for [accountId], categorized and
  /// fingerprinted, ready for the dedup pass.
  static List<Txn> toTransactions(
      List<ImportPreviewRow> rows, String accountId, Categorizer categorizer) {
    return rows.map((r) {
      final cat = categorizer.categorize(r.description, r.amountCents);
      final isTransfer =
          Categories.get(cat.categoryId).kind == CategoryKind.transfer;
      return Txn(
        id: newId(),
        accountId: accountId,
        amountCents: r.amountCents,
        date: r.date,
        merchant: cat.cleanedMerchant.isEmpty ? r.description : cat.cleanedMerchant,
        rawDesc: r.description,
        categoryId: cat.categoryId,
        categorySource: cat.source,
        isTransfer: isTransfer,
        source: 'csv',
        fingerprint:
            Dedup.fingerprint(accountId, r.amountCents, r.date, r.description),
      );
    }).toList();
  }
}
