import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../ui/format.dart';

void showTransactionDetail(BuildContext context, Txn txn) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TransactionDetailSheet(txn: txn),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  final Txn txn;
  const _TransactionDetailSheet({required this.txn});

  String _sourceExplanation(Txn t) => switch (t.categorySource) {
        'user' => 'You set this category.',
        'keyword' => 'Matched a known merchant pattern.',
        'heuristic' => 'Guessed from the amount — please confirm.',
        _ => 'Not categorized yet — tap to choose.',
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cat = Categories.get(txn.categoryId);
    final account = app.accountById(txn.accountId);

    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  Fmt.signedMoney(txn.amountCents, app.currency),
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: txn.amountCents > 0 && !txn.isTransfer
                        ? scheme.primary
                        : null,
                  ),
                ),
                Text(txn.merchant, style: text.titleMedium),
                Text(Fmt.dayLabel(txn.date),
                    style:
                        text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(cat.emoji, style: text.headlineSmall),
            title: Text(cat.name),
            subtitle: Text(_sourceExplanation(txn)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCategory(context, app),
          ),
          if (account != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(account.name),
              subtitle: Text(account.type.label),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notes_outlined),
            title: Text(txn.rawDesc,
                style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace')),
            subtitle: const Text('Original descriptor'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, AppState app) async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        children: [
          for (final c in Categories.all)
            ListTile(
              leading: Text(c.emoji),
              title: Text(c.name),
              selected: c.id == txn.categoryId,
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;

    final always = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Always categorize ${txn.merchant} as ${picked.name}?'),
        content: const Text(
            'Lumen will apply this to all past and future transactions from '
            'this merchant.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Just this once')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Always')),
        ],
      ),
    );
    if (!context.mounted) return;
    final applied =
        await app.recategorize(txn, picked.id, always: always ?? false);
    if (!context.mounted) return;
    Navigator.pop(context); // close the detail sheet to show fresh data
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(applied > 1
          ? 'Applied to $applied transactions from this merchant'
          : 'Category updated'),
    ));
  }
}
