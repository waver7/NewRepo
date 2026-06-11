import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/csv_importer.dart';
import '../state/app_state.dart';
import '../ui/format.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title:
              const Text('Plan', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: const TabBar(tabs: [
            Tab(text: 'Budgets'),
            Tab(text: 'Goals'),
            Tab(text: 'Subscriptions'),
          ]),
        ),
        body: const TabBarView(
          children: [_BudgetsTab(), _GoalsTab(), _SubscriptionsTab()],
        ),
      ),
    );
  }
}

// ===================== Budgets =====================

class _BudgetsTab extends StatelessWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (app.budgets.isEmpty)
          _EmptyState(
            emoji: '🎯',
            title: 'No spending limits yet',
            subtitle: 'Set a monthly limit per category and Lumen will track '
                'your pace and warn you before you blow through it.',
          ),
        for (final b in app.budgets) _budgetCard(context, app, b),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add spending limit'),
          onPressed: () => _editBudget(context, app, null),
        ),
      ],
    );
  }

  Widget _budgetCard(BuildContext context, AppState app, Budget b) {
    final scheme = Theme.of(context).colorScheme;
    final cat = Categories.get(b.categoryId);
    final spent = app.budgetSpent(b.categoryId);
    final ratio = b.limitCents <= 0 ? 0.0 : (spent / b.limitCents);
    final color = ratio >= 1
        ? scheme.error
        : ratio >= 0.75
            ? Colors.orange
            : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _editBudget(context, app, b),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat.emoji,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(cat.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    Text(
                      '${Fmt.money(spent, app.currency)} / '
                      '${Fmt.money(b.limitCents, app.currency)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBudget(
      BuildContext context, AppState app, Budget? existing) async {
    final amountCtrl = TextEditingController(
        text: existing != null
            ? (existing.limitCents / 100).toStringAsFixed(0)
            : '');
    var categoryId = existing?.categoryId ?? Categories.expense.first.id;

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
              Text(existing == null ? 'New spending limit' : 'Edit limit',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in Categories.expense)
                    DropdownMenuItem(
                        value: c.id, child: Text('${c.emoji} ${c.name}')),
                ],
                onChanged: (v) =>
                    setSheetState(() => categoryId = v ?? categoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Monthly limit', prefixText: r'$ '),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final cents = CsvImporter.parseAmountCents(amountCtrl.text);
                  if (cents == null || cents <= 0) return;
                  await app.saveBudget(Budget(
                    id: existing?.id ?? newId(),
                    categoryId: categoryId,
                    limitCents: cents.abs(),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await app.removeBudget(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Delete limit'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Goals =====================

class _GoalsTab extends StatelessWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (app.goals.isEmpty)
          _EmptyState(
            emoji: '🏆',
            title: 'No goals yet',
            subtitle:
                'Create a savings goal — Lumen computes the monthly pace you '
                'need and tracks your progress.',
          ),
        for (final g in app.goals) _goalCard(context, app, g),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New goal'),
          onPressed: () => _editGoal(context, app, null),
        ),
      ],
    );
  }

  Widget _goalCard(BuildContext context, AppState app, Goal g) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final required = g.requiredMonthly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _editGoal(context, app, g),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: g.progress,
                        strokeWidth: 5,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      Center(child: Text(g.emoji, style: text.titleLarge)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${Fmt.money(g.savedCents, app.currency)} of '
                        '${Fmt.money(g.targetCents, app.currency)}'
                        ' · ${(g.progress * 100).round()}%',
                        style: text.bodySmall,
                      ),
                      if (required != null && required > 0)
                        Text(
                          '${Fmt.money(required, app.currency)}/mo to hit '
                          '${g.targetDate}',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.primary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add contribution',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _contribute(context, app, g),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _contribute(BuildContext context, AppState app, Goal g) async {
    final ctrl = TextEditingController();
    final cents = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${g.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Amount', prefixText: r'$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, CsvImporter.parseAmountCents(ctrl.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (cents == null || cents == 0) return;
    g.savedCents = (g.savedCents + cents.abs()).clamp(0, 1 << 62);
    await app.saveGoal(g);
    if (context.mounted && g.savedCents >= g.targetCents) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 ${g.name} reached — congratulations!')));
    }
  }

  Future<void> _editGoal(
      BuildContext context, AppState app, Goal? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
        text: existing != null
            ? (existing.targetCents / 100).toStringAsFixed(0)
            : '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🏠');
    DateTime? targetDate = existing?.targetDate != null
        ? DateTime.parse(existing!.targetDate!)
        : null;

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
              Text(existing == null ? 'New goal' : 'Edit goal',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: emojiCtrl,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Emoji'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Target amount', prefixText: r'$ '),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(targetDate == null
                    ? 'Target date (optional)'
                    : dateKey(targetDate!)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate:
                        targetDate ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setSheetState(() => targetDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final cents = CsvImporter.parseAmountCents(amountCtrl.text);
                  final name = nameCtrl.text.trim();
                  if (cents == null || cents <= 0 || name.isEmpty) return;
                  await app.saveGoal(Goal(
                    id: existing?.id ?? newId(),
                    name: name,
                    emoji: emojiCtrl.text.trim().isEmpty
                        ? '🎯'
                        : emojiCtrl.text.trim(),
                    targetCents: cents.abs(),
                    savedCents: existing?.savedCents ?? 0,
                    targetDate:
                        targetDate != null ? dateKey(targetDate!) : null,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await app.removeGoal(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Delete goal'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Subscriptions =====================

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final series = app.recurring;
    final subs = series.where((s) => !s.isIncome).toList();
    final income = series.where((s) => s.isIncome).toList();
    final monthlyTotal =
        subs.fold(0, (sum, s) => sum + s.monthlyCostCents);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (subs.isEmpty && income.isEmpty)
          _EmptyState(
            emoji: '🔁',
            title: 'Nothing recurring detected yet',
            subtitle: 'Once Lumen sees the same merchant charge you on a '
                'regular rhythm, it shows up here automatically.',
          ),
        if (subs.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECURRING SPEND',
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    '${Fmt.money(monthlyTotal, app.currency)}/mo',
                    style: text.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                      '${subs.length} detected subscriptions & bills · '
                      '≈ ${Fmt.money(monthlyTotal * 12, app.currency)}/yr',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final s in subs) _seriesTile(context, app, s),
        ],
        if (income.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recurring income',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final s in income) _seriesTile(context, app, s),
        ],
      ],
    );
  }

  Widget _seriesTile(BuildContext context, AppState app, RecurringSeries s) {
    final scheme = Theme.of(context).colorScheme;
    final cat = Categories.get(s.categoryId);
    final hasPriceChange = s.previousAmountCents != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: Text(cat.emoji),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(s.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (hasPriceChange)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('PRICE ↑',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer)),
                ),
            ],
          ),
          subtitle: Text(
            '${s.cadence.label} · next ~${s.nextExpectedDate}'
            '${hasPriceChange ? ' · was ${Fmt.money(s.previousAmountCents!, app.currency)}' : ''}',
          ),
          trailing: Text(
            Fmt.money(s.typicalAmountCents, app.currency),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: s.isIncome ? scheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(emoji, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
