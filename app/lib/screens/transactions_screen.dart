import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../ui/format.dart';
import 'import_csv_screen.dart';
import 'transaction_detail_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();

    final filtered = app.txns.where((t) {
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.merchant.toLowerCase().contains(q) ||
          t.rawDesc.toLowerCase().contains(q) ||
          t.notes.toLowerCase().contains(q) ||
          Categories.get(t.categoryId).name.toLowerCase().contains(q);
    }).toList();

    // Group by day.
    final groups = <String, List<Txn>>{};
    for (final t in filtered) {
      groups.putIfAbsent(t.date, () => []).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final usedCategories = {for (final t in app.txns) t.categoryId};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportCsvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search merchant, category, notes…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                ),
                for (final c in Categories.all
                    .where((c) => usedCategories.contains(c.id)))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${c.emoji} ${c.name}'),
                      selected: _categoryFilter == c.id,
                      onSelected: (sel) => setState(
                          () => _categoryFilter = sel ? c.id : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🪙', style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 8),
                        const Text('No transactions yet'),
                        const SizedBox(height: 4),
                        Text('Add one with + or import a CSV',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: days.length,
                    itemBuilder: (context, i) {
                      final day = days[i];
                      final dayTxns = groups[day]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                            child: Text(
                              Fmt.dayLabel(day),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          for (final t in dayTxns) _TxnRow(txn: t),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final Txn txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final cat = Categories.get(txn.categoryId);
    final account = app.accountById(txn.accountId);

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete transaction?'),
              content: Text('${txn.merchant} · '
                  '${Fmt.signedMoney(txn.amountCents, app.currency)}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => app.removeTxn(txn.id),
      child: ListTile(
        onTap: () => showTransactionDetail(context, txn),
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Text(cat.emoji),
        ),
        title: Text(txn.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${cat.name}${account != null ? ' · ${account.name}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          Fmt.signedMoney(txn.amountCents, app.currency),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: txn.amountCents > 0 && !txn.isTransfer
                ? scheme.primary
                : txn.isTransfer
                    ? scheme.onSurfaceVariant
                    : null,
          ),
        ),
      ),
    );
  }
}
