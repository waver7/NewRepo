import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../ui/charts.dart';
import '../ui/format.dart';
import 'settings_screen.dart';
import 'transaction_detail_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stats = app.monthStats();
    final months = app.recentMonths(6);
    final topCats = app.categorySpend().take(4).toList();
    final attention = app.attentionItems;
    final recent = app.txns.take(5).toList();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          // Hero: this month's net cash flow.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Fmt.monthName(app.currentMonth).toUpperCase(),
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(
                    Fmt.signedMoney(stats.netCents, app.currency),
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: stats.netCents >= 0
                          ? scheme.primary
                          : scheme.error,
                    ),
                  ),
                  Text('net cash flow',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _miniStat(context, 'In',
                          Fmt.money(stats.incomeCents, app.currency)),
                      _miniStat(context, 'Out',
                          Fmt.money(stats.expenseCents, app.currency)),
                      _miniStat(context, 'Savings rate',
                          '${(stats.savingsRate * 100).round()}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Attention cards (the local insight engine).
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Needs attention',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...attention.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: scheme.secondaryContainer.withValues(alpha: 0.5),
                    child: ListTile(
                      leading: Text(a.emoji, style: text.headlineSmall),
                      title: Text(a.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(a.body),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 20),
          Text('Last 6 months',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                height: 140,
                child: IncomeExpenseBarChart(
                  data: months
                      .map((m) => BarPair(Fmt.monthShort(m.month),
                          m.incomeCents / 100, m.expenseCents / 100))
                      .toList(),
                  incomeColor: scheme.primary,
                  expenseColor: scheme.error.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
          if (topCats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Top categories this month',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final c in topCats)
                    ListTile(
                      leading: Text(Categories.get(c.categoryId).emoji,
                          style: text.headlineSmall),
                      title: Text(Categories.get(c.categoryId).name),
                      subtitle: Text('${c.count} transactions'),
                      trailing: Text(
                        Fmt.money(c.cents, app.currency),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recent activity',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final t in recent)
                    ListTile(
                      onTap: () => showTransactionDetail(context, t),
                      leading: Text(Categories.get(t.categoryId).emoji,
                          style: text.titleLarge),
                      title: Text(t.merchant,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(Fmt.dayLabel(t.date)),
                      trailing: Text(
                        Fmt.signedMoney(t.amountCents, app.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: t.amountCents > 0 && !t.isTransfer
                              ? scheme.primary
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
