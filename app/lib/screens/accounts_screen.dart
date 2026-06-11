import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../ui/format.dart';
import 'import_csv_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final balances = {
      for (final a in app.accounts) a.id: app.accountBalance(a)
    };
    // Cash position: asset balances minus credit-card debt.
    final net = app.accounts.fold(0, (sum, a) {
      final b = balances[a.id] ?? 0;
      return a.type == AccountType.creditCard ? sum + b : sum + b;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL',
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    '${net < 0 ? '−' : ''}${Fmt.money(net, app.currency)}',
                    style: text.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text('across ${app.accounts.length} accounts',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final a in app.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  onTap: () => _editAccount(context, app, a),
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Icon(switch (a.type) {
                      AccountType.checking => Icons.account_balance_outlined,
                      AccountType.savings => Icons.savings_outlined,
                      AccountType.creditCard => Icons.credit_card,
                      AccountType.cash => Icons.payments_outlined,
                    }),
                  ),
                  title: Text(a.name),
                  subtitle: Text(a.type.label),
                  trailing: Text(
                    '${(balances[a.id] ?? 0) < 0 ? '−' : ''}'
                    '${Fmt.money(balances[a.id] ?? 0, app.currency)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: (balances[a.id] ?? 0) < 0 ? scheme.error : null,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
            onPressed: () => _editAccount(context, app, null),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import transactions (CSV)'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportCsvScreen())),
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(
      BuildContext context, AppState app, Account? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final balanceCtrl = TextEditingController(
        text: existing != null
            ? (existing.startingBalanceCents / 100).toStringAsFixed(2)
            : '0');
    var type = existing?.type ?? AccountType.checking;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New account' : 'Edit account',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in AccountType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setSheetState(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                    labelText: 'Starting balance', prefixText: r'$ '),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final cents = double.tryParse(
                          balanceCtrl.text.replaceAll(',', '')) ??
                      0;
                  await app.saveAccount(Account(
                    id: existing?.id ?? newId(),
                    name: name,
                    type: type,
                    startingBalanceCents: (cents * 100).round(),
                    currency: app.currency,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Delete account?'),
                        content: const Text(
                            'This also deletes all of its transactions.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await app.removeAccount(existing.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Delete account'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
