import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/csv_importer.dart';
import '../services/dedup.dart';
import '../state/app_state.dart';

void showAddTransactionSheet(BuildContext context) {
  final app = context.read<AppState>();
  if (app.accounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an account first (Accounts tab)')));
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddTransactionSheet(),
  );
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet();

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  bool _isExpense = true;
  String? _accountId;
  String? _categoryId; // null = let the categorizer decide
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _accountId ??= app.accounts.first.id;
    final suggested = _merchantCtrl.text.isEmpty
        ? null
        : app.categorizer
            .categorize(_merchantCtrl.text, _isExpense ? -100 : 100);
    final effectiveCategory =
        _categoryId ?? suggested?.categoryId ?? 'other.uncategorized';
    final cat = Categories.get(effectiveCategory);

    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add transaction',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Expense')),
              ButtonSegment(value: false, label: Text('Income')),
            ],
            selected: {_isExpense},
            onSelectionChanged: (s) => setState(() => _isExpense = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Amount', prefixText: r'$ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Merchant / payee'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    for (final a in app.accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                      '${_date.month}/${_date.day}/${_date.year}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(cat.emoji,
                style: Theme.of(context).textTheme.headlineSmall),
            title: Text(cat.name),
            subtitle: Text(_categoryId == null && suggested != null
                ? 'Auto-suggested'
                : 'Category'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showModalBottomSheet<Category>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => ListView(
                  children: [
                    for (final c in Categories.all)
                      ListTile(
                        leading: Text(c.emoji),
                        title: Text(c.name),
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                  ],
                ),
              );
              if (picked != null) setState(() => _categoryId = picked.id);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final cents = CsvImporter.parseAmountCents(_amountCtrl.text);
    final merchant = _merchantCtrl.text.trim();
    if (cents == null || cents == 0 || merchant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an amount and a merchant')));
      return;
    }
    final signed = _isExpense ? -cents.abs() : cents.abs();
    final result = app.categorizer.categorize(merchant, signed);
    final categoryId = _categoryId ?? result.categoryId;
    final d = dateKey(_date);
    final txn = Txn(
      id: newId(),
      accountId: _accountId!,
      amountCents: signed,
      date: d,
      merchant: merchant,
      rawDesc: merchant,
      categoryId: categoryId,
      categorySource: _categoryId != null ? 'user' : result.source,
      isTransfer: Categories.get(categoryId).kind == CategoryKind.transfer,
      source: 'manual',
      fingerprint: Dedup.fingerprint(_accountId!, signed, d, merchant),
    );
    await app.addTxn(txn);
    if (mounted) Navigator.pop(context);
  }
}
