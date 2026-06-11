import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Currency'),
            subtitle: Text(app.currency),
            onTap: () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => ListView(
                  children: [
                    for (final c in ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'])
                      ListTile(
                        title: Text(c),
                        selected: c == app.currency,
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                  ],
                ),
              );
              if (picked != null) await app.setCurrency(picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Export all transactions (CSV)'),
            subtitle: const Text('Copies CSV to the clipboard'),
            onTap: () async {
              final rows = StringBuffer(
                  'date,merchant,amount,category,account,notes\n');
              for (final t in app.txns) {
                final account = app.accountById(t.accountId)?.name ?? '';
                String esc(String s) => '"${s.replaceAll('"', '""')}"';
                rows.writeln([
                  t.date,
                  esc(t.merchant),
                  (t.amountCents / 100).toStringAsFixed(2),
                  Categories.get(t.categoryId).name,
                  esc(account),
                  esc(t.notes),
                ].join(','));
              }
              await Clipboard.setData(ClipboardData(text: rows.toString()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${app.txns.length} transactions copied as CSV')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('Learned category rules'),
            subtitle: Text(
                '${app.categorizer.userOverrides.length} merchant rules'),
            onTap: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (ctx) => app.categorizer.userOverrides.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          'No rules yet. Correct a transaction\'s category and '
                          'choose "Always" to create one.'),
                    )
                  : ListView(
                      children: [
                        for (final e in app.categorizer.userOverrides.entries)
                          ListTile(
                            title: Text(e.key),
                            trailing: Text(
                                '${Categories.get(e.value).emoji} '
                                '${Categories.get(e.value).name}'),
                          ),
                      ],
                    ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text('Erase all data',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Deletes everything on this device'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Erase all data?'),
                  content: const Text(
                      'All accounts, transactions, budgets and goals will be '
                      'permanently deleted from this device.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(ctx).colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Erase everything')),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AppState>().wipeEverything();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Lumen · local-first personal finance\n'
              'All data stays on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
