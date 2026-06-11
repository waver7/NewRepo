import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/stats.dart';
import '../state/app_state.dart';
import '../ui/charts.dart';
import '../ui/format.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late String _month = monthKey(DateTime.now());
  bool _byMerchant = false;

  void _shiftMonth(int delta) {
    final d = DateTime(
        int.parse(_month.substring(0, 4)), int.parse(_month.substring(5, 7)));
    final next = DateTime(d.year, d.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _month = monthKey(next));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stats = app.monthStats(_month);
    final cats = app.categorySpend(_month);
    final merchants = app.merchantSpend(_month).take(12).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // Month selector.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left)),
              SizedBox(
                width: 170,
                child: Center(
                  child: Text(Fmt.monthName(_month),
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _stat(context, 'Income',
                      Fmt.money(stats.incomeCents, app.currency),
                      scheme.primary),
                  _stat(context, 'Expenses',
                      Fmt.money(stats.expenseCents, app.currency),
                      scheme.error),
                  _stat(
                      context,
                      'Net',
                      Fmt.signedMoney(stats.netCents, app.currency),
                      stats.netCents >= 0 ? scheme.primary : scheme.error),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No spending this month',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            )
          else ...[
            // Donut of category spend.
            SizedBox(
              height: 220,
              child: DonutChart(
                slices: [
                  for (var i = 0; i < cats.length; i++)
                    DonutSlice(cats[i].cents.toDouble(),
                        chartPalette[i % chartPalette.length]),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Fmt.money(stats.expenseCents, app.currency),
                        style: text.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('spent',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('By category')),
                ButtonSegment(value: true, label: Text('By merchant')),
              ],
              selected: {_byMerchant},
              onSelectionChanged: (s) =>
                  setState(() => _byMerchant = s.first),
            ),
            const SizedBox(height: 8),
            if (!_byMerchant)
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < cats.length; i++)
                      _categoryRow(context, app, cats[i],
                          chartPalette[i % chartPalette.length],
                          stats.expenseCents),
                  ],
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final m in merchants)
                      ListTile(
                        title: Text(m.merchant,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${m.count} purchase${m.count > 1 ? 's' : ''}'),
                        trailing: Text(Fmt.money(m.cents, app.currency),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value,
              style: text.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _categoryRow(BuildContext context, AppState app, CategorySpend c,
      Color color, int totalExpense) {
    final cat = Categories.get(c.categoryId);
    final delta = Stats.categoryDelta(app.txns, _month, c.categoryId);
    final scheme = Theme.of(context).colorScheme;
    final pct = totalExpense <= 0 ? 0 : (c.cents / totalExpense * 100).round();

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text('${cat.emoji} ${cat.name}'),
      subtitle: Text(
        '$pct% of spend'
        '${delta != 0 ? ' · ${delta > 0 ? '↑' : '↓'}${Fmt.money(delta, app.currency)} vs last month' : ''}',
        style: TextStyle(
            color: delta > 0 ? scheme.error : scheme.onSurfaceVariant),
      ),
      trailing: Text(Fmt.money(c.cents, app.currency),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }
}
