/// Lightweight custom-painted charts (no external chart dependency):
/// a grouped income/expense bar chart and a category donut.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class BarPair {
  final String label;
  final double income;
  final double expense;
  const BarPair(this.label, this.income, this.expense);
}

/// Income vs expense bars per month.
class IncomeExpenseBarChart extends StatelessWidget {
  final List<BarPair> data;
  final Color incomeColor;
  final Color expenseColor;

  const IncomeExpenseBarChart({
    super.key,
    required this.data,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return CustomPaint(
      painter: _BarPainter(data, incomeColor, expenseColor,
          labelStyle?.color ?? Colors.grey),
      child: const SizedBox.expand(),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<BarPair> data;
  final Color incomeColor;
  final Color expenseColor;
  final Color labelColor;

  _BarPainter(this.data, this.incomeColor, this.expenseColor, this.labelColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final maxVal = data
        .map((d) => math.max(d.income, d.expense))
        .fold(0.0, math.max)
        .clamp(1.0, double.infinity);

    final groupWidth = size.width / data.length;
    final barWidth = math.min(14.0, groupWidth / 3);
    final incomePaint = Paint()..color = incomeColor;
    final expensePaint = Paint()..color = expenseColor;

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = groupWidth * i + groupWidth / 2;
      final ih = chartHeight * (d.income / maxVal);
      final eh = chartHeight * (d.expense / maxVal);
      final r = const Radius.circular(4);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barWidth - 2, chartHeight - ih, barWidth, ih),
            topLeft: r, topRight: r),
        incomePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
            Rect.fromLTWH(cx + 2, chartHeight - eh, barWidth, eh),
            topLeft: r, topRight: r),
        expensePaint,
      );
      final tp = TextPainter(
        text: TextSpan(
            text: d.label,
            style: TextStyle(fontSize: 10, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.data != data ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor;
}

class DonutSlice {
  final double value;
  final Color color;
  const DonutSlice(this.value, this.color);
}

class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final Widget? center;

  const DonutChart({super.key, required this.slices, this.center});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _DonutPainter(slices),
          child: const SizedBox.expand(),
        ),
        ?center,
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (s, x) => s + x.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final stroke = radius * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = s.color;
      canvas.drawArc(rect, start, math.max(sweep - 0.03, 0.01), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

/// Stable, pleasant palette for category slices.
const chartPalette = <Color>[
  Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFFF7675), Color(0xFFFDCB6E),
  Color(0xFF0984E3), Color(0xFFE17055), Color(0xFF00CEC9), Color(0xFFA29BFE),
  Color(0xFFFAB1A0), Color(0xFF55EFC4), Color(0xFFFD79A8), Color(0xFF74B9FF),
];
