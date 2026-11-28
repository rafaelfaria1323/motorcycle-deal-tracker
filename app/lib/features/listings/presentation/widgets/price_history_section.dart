import 'dart:math';

import 'package:material_ui/material_ui.dart';

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
import '../price_history.dart';
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
            final rows = priceHistoryRows(points);
            final summary = priceHistorySummary(points);
            final chart = priceChart(
              points,
              now: DateTime.now(),
              siteBefore: widget.listing.referenceIsFromSite
                  ? widget.listing.priceBeforeDrop
                  : null,
            );
            final labelStyle = AppTheme.figureLabel(context);
            final colors = AppColors.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary == null)
                  Text(
                    context.strings.priceHasNotChangedSinceItWasFirst,
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  _SummaryStrip(summary: summary),
                if (chart != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PriceChartPainter(
                        language: context.language,
                        chart: chart,
                        lineColor: theme.colorScheme.primary,
                        dropColor: colors.positive,
                        riseColor: colors.negative,
                        surfaceColor: theme.colorScheme.surface,
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
                if (rows.length > 1) ...[
                  const SizedBox(height: 12),
                  for (final (i, row) in rows.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    _ChangeRow(row: row, newest: i == 0),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The history in three tiles: the first price, the lowest and how far
/// it has moved since the first (N.128).
class const _SummaryStrip({required final PriceHistorySummary summary})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final strings = context.strings;
    final colors = AppColors.of(context);
    final (euros, pct) = priceMoveParts(
      summary.change,
      summary.changePct,
      language: language,
    );
    final changes = strings.priceHistoryChanges(count: summary.changes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: _SummaryTile(
            title: strings.priceHistoryFirst,
            figure: Formatters.price(summary.first, language: language),
            caption: Formatters.date(summary.firstAt),
          ),
        ),
        Expanded(
          child: _SummaryTile(
            title: strings.priceHistoryLowest,
            figure: Formatters.price(summary.lowest, language: language),
            caption: Formatters.date(summary.lowestAt),
          ),
        ),
        Expanded(
          child: _SummaryTile(
            title: strings.priceHistoryChange,
            figure: euros,
            caption: pct == null ? changes : '$pct · $changes',
            color: summary.change < 0
                ? colors.positive
                : summary.change > 0
                ? colors.negative
                : null,
          ),
        ),
      ],
    );
  }
}

class const _SummaryTile({
  required final String title,
  required final String figure,
  required final String caption,
  final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTheme.groupLabel(context)),
          const SizedBox(height: 4),
          // A long price shrinks to the tile rather than wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              figure,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                fontFeatures: AppTheme.tabularFigures,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: AppTheme.figureLabel(context)),
        ],
      ),
    );
  }
}

/// A recorded price: its date (the newest also "Agora", the oldest real
/// one "Primeiro preço"), its move from the real price before it, and
/// the price, or "Preço por consultar" for a placeholder.
class const _ChangeRow({
  required final PriceHistoryRow row,
  required final bool newest,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = context.language;
    final colors = AppColors.of(context);
    final move = priceRowMoveText(row, language: language);
    final placeholder = row.move == .placeholder;
    final label = row.move == .first
        ? context.strings.priceHistoryFirst
        : newest
        ? context.strings.priceHistoryNow
        : null;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.date(row.point.observedAt),
                  style: theme.textTheme.bodyMedium,
                ),
                if (label != null)
                  Text(label, style: AppTheme.figureLabel(context)),
              ],
            ),
          ),
          if (move != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                move,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: row.move == .drop ? colors.positive : colors.negative,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ),
          Text(
            placeholder
                ? context.strings.priceOnRequest
                : Formatters.price(row.point.price, language: language),
            style: placeholder
                ? theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Draws a [PriceChart]: the step line over real time with a light fill
/// under it, a dot per recorded price (drops and rises in their colours),
/// hairlines with the highest and lowest prices, and the site's earlier
/// price as a dashed line.
class _PriceChartPainter({
  required final AppLanguage language,
  required final PriceChart chart,
  required final Color lineColor,
  required final Color dropColor,
  required final Color riseColor,
  required final Color surfaceColor,
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
    // The area under the line, fading towards the bottom.
    final bottom = size.height - _pad;
    final area = Path.from(path)
      ..lineTo(at(chart.line.last).dx, bottom)
      ..lineTo(at(chart.line.first).dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.16),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTRB(0, _pad, size.width, bottom)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Each dot ringed in the card's colour, so it stands out of the line.
    final ring = Paint()..color = surfaceColor;
    for (final (i, p) in chart.changes.indexed) {
      final colour = switch (chart.moves[i]) {
        .drop => dropColor,
        .rise => riseColor,
        _ => lineColor,
      };
      canvas
        ..drawCircle(at(p), 5.5, ring)
        ..drawCircle(at(p), 4, Paint()..color = colour);
    }
    // Today's price, at the right edge.
    canvas
      ..drawCircle(at(chart.line.last), 6.5, ring)
      ..drawCircle(at(chart.line.last), 5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.chart != chart ||
      old.language != language ||
      old.lineColor != lineColor ||
      old.dropColor != dropColor ||
      old.riseColor != riseColor ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
