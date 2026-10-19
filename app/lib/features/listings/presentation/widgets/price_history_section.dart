import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/repositories/listings_repository.dart';
import '../price_history_text.dart';

class PriceHistorySection extends StatefulWidget {
  const PriceHistorySection({super.key, required this.listing});

  final Listing listing;

  @override
  State<PriceHistorySection> createState() => _PriceHistorySectionState();
}

class _PriceHistorySectionState extends State<PriceHistorySection> {
  late final Future<List<PricePoint>> _future = getIt<ListingsRepository>()
      .getPriceHistory(widget.listing.id);

  String? _seenLine() {
    final first = widget.listing.firstSeenAt;
    final last = widget.listing.lastSeenAt;
    if (first == null) return null;
    final firstText = 'Visto pela primeira vez em ${Formatters.date(first)}';
    if (last == null) return firstText;
    return '$firstText · última vez ${Formatters.daysAgo(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seenLine = _seenLine();
    final siteLine = siteDropLine(widget.listing);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico de preço', style: theme.textTheme.titleMedium),
            if (seenLine != null) ...[
              const SizedBox(height: 4),
              Text(seenLine, style: theme.textTheme.bodySmall),
            ],
            if (siteLine != null) ...[
              const SizedBox(height: 8),
              Text(siteLine, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            FutureBuilder<List<PricePoint>>(
              future: _future,
              builder: (context, snapshot) {
                final points = snapshot.data;
                if (points == null) {
                  return const SizedBox(height: 24);
                }
                if (points.length < 2) {
                  return Text(
                    'O preço ainda não mudou desde que foi visto pela primeira vez.',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PriceChartPainter(
                          points: points,
                          lineColor: theme.colorScheme.primary,
                          gridColor: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = points.length - 1; i >= 0; i--)
                      _ChangeRow(
                        point: points[i],
                        previous: i == 0 ? null : points[i - 1],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.point, required this.previous});

  final PricePoint point;
  final PricePoint? previous;

  @override
  Widget build(BuildContext context) {
    final delta = previous == null ? null : point.price - previous!.price;
    final colors = AppColors.of(context);
    final color = delta == null
        ? null
        : (delta < 0 ? colors.positive : colors.negative);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(Formatters.date(point.observedAt))),
          if (delta != null && delta != 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${delta < 0 ? '↓' : '↑'} ${Formatters.price(delta.abs())}',
                style: TextStyle(color: color),
              ),
            ),
          Text(Formatters.price(point.price)),
        ],
      ),
    );
  }
}

/// A step line: the price holds until it changes. Observations are evenly
/// spaced, so the shape stays readable however close together they are.
class _PriceChartPainter extends CustomPainter {
  _PriceChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<PricePoint> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 8.0;
    final prices = points.map((p) => p.price);
    var minP = prices.reduce((a, b) => a < b ? a : b);
    var maxP = prices.reduce((a, b) => a > b ? a : b);
    if (maxP - minP < 1) {
      minP -= 1;
      maxP += 1;
    }

    double x(int i) => pad + (size.width - 2 * pad) * i / (points.length - 1);
    double y(double price) =>
        pad + (size.height - 2 * pad) * (1 - (price - minP) / (maxP - minP));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(pad, y(minP)),
      Offset(size.width - pad, y(minP)),
      grid,
    );
    canvas.drawLine(
      Offset(pad, y(maxP)),
      Offset(size.width - pad, y(maxP)),
      grid,
    );

    final path = Path()..moveTo(x(0), y(points[0].price));
    for (var i = 1; i < points.length; i++) {
      path
        ..lineTo(x(i), y(points[i - 1].price))
        ..lineTo(x(i), y(points[i].price));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = lineColor;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].price)), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.points != points ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor;
}
