import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/repositories/listings_repository.dart';
import '../price_chart.dart';
import '../price_history_text.dart';

class const PriceHistorySection({super.key, required final Listing listing})
    extends StatefulWidget {
  @override
  State<PriceHistorySection> createState() => _PriceHistorySectionState();
}

class _PriceHistorySectionState extends State<PriceHistorySection> {
  late final Future<List<PricePoint>> _future = getIt<ListingsRepository>()
      .getPriceHistory(widget.listing.id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seen = seenLine(widget.listing, language: context.language);
    final siteLine = siteDropLine(widget.listing, language: context.language);

    return SectionCard(
      title: context.strings.priceHistory,
      children: [
        if (seen != null)
          Text(
            seen,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
                context.strings.priceHasNotChangedSinceItWasFirst,
                style: theme.textTheme.bodyMedium,
              );
            }
            final chart = priceChart(
              points,
              now: DateTime.now(),
              siteBefore: widget.listing.referenceIsFromSite
                  ? widget.listing.priceBeforeDrop
                  : null,
            );
            final labelStyle = AppTheme.figureLabel(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chart != null) ...[
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PriceChartPainter(
                        language: context.language,
                        chart: chart,
                        lineColor: theme.colorScheme.primary,
                        gridColor: theme.colorScheme.outlineVariant,
                        labelStyle: labelStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(Formatters.date(chart.start), style: labelStyle),
                      const Spacer(),
                      Text(context.strings.todayHeading, style: labelStyle),
                    ],
                  ),
                ],
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
    );
  }
}

class const _ChangeRow({
  required final PricePoint point,
  required final PricePoint? previous,
}) extends StatelessWidget {
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
                '${delta < 0 ? '↓' : '↑'} ${Formatters.price(delta.abs(), language: context.language)}',
                style: TextStyle(color: color),
              ),
            ),
          Text(Formatters.price(point.price, language: context.language)),
        ],
      ),
    );
  }
}

/// Draws a [PriceChart]: the step line over real time, a dot per recorded
/// price, hairlines with the highest and lowest prices, and the site's
/// earlier price as a dashed line.
class _PriceChartPainter({
  required final AppLanguage language,
  required final PriceChart chart,
  required final Color lineColor,
  required final Color gridColor,
  required final TextStyle labelStyle,
}) extends CustomPainter {
  /// Space above the top label and below the bottom line.
  static const _pad = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 2 * _pad;
    Offset at(ChartPoint p) =>
        Offset(p.x * size.width, _pad + height * (1 - p.y));
    double yOf(double y) => _pad + height * (1 - y);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    // The highest price's label sits above its line, the lowest's below
    // (so close prices never overlap), the site's earlier price on the left.
    void hairline(
      double y,
      String label, {
      bool below = false,
      bool left = false,
      bool dashed = false,
    }) {
      final dy = yOf(y);
      if (dashed) {
        for (var x = 0.0; x < size.width; x += 8) {
          canvas.drawLine(
            Offset(x, dy),
            Offset(min(x + 4, size.width), dy),
            grid,
          );
        }
      } else {
        canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
      }
      final text = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final above = dy - text.height - 6;
      final under = dy + 4;
      final top = below
          ? (under + text.height > size.height ? above : under)
          : (above < 0 ? under : above);
      text
        ..paint(canvas, Offset(left ? 0 : size.width - text.width, top))
        ..dispose();
    }

    hairline(
      chart.highestY,
      Formatters.price(chart.highest, language: language),
    );
    if (chart.lowest != chart.highest) {
      hairline(
        chart.lowestY,
        Formatters.price(chart.lowest, language: language),
        below: true,
      );
    }
    if (chart.reference case final reference?) {
      hairline(
        chart.referenceY!,
        language.messages.previouslyAt(
          price: Formatters.price(reference, language: language),
        ),
        left: true,
        dashed: true,
      );
    }

    final path = Path()
      ..moveTo(at(chart.line.first).dx, at(chart.line.first).dy);
    for (final p in chart.line.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
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
    for (final p in chart.changes) {
      canvas.drawCircle(at(p), 3.5, dot);
    }
    // Today's price, at the right edge.
    canvas.drawCircle(at(chart.line.last), 5, dot);
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.chart != chart ||
      old.language != language ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
