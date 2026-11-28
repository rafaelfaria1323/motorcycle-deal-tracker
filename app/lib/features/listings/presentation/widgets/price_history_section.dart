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
                  _PriceChartView(chart: chart),
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
    // The tiles share the tallest one's height, whichever wraps its title
    // or caption.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
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

/// The chart with what it means: a tap, a drag or the mouse picks a
/// recorded price and shows its date, price and move (N.129).
class const _PriceChartView({required final PriceChart chart})
    extends StatefulWidget {
  @override
  State<_PriceChartView> createState() => _PriceChartViewState();
}

class _PriceChartViewState extends State<_PriceChartView> {
  static const _height = 200.0;

  int? _selected;

  void _pick(_PriceChartPainter painter, Size size, Offset at) {
    final i = nearestChange(widget.chart, painter.chartX(size, at.dx));
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final chart = widget.chart;
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, _height);
            final painter = _PriceChartPainter(
              language: context.language,
              chart: chart,
              selected: selected != null && selected < chart.changes.length
                  ? selected
                  : null,
              colours: (
                neutral: scheme.onSurfaceVariant,
                drop: colors.positive,
                rise: colors.negative,
                surface: scheme.surface,
                grid: scheme.outlineVariant,
                guide: scheme.outline,
                tip: scheme.inverseSurface,
                onTip: scheme.onInverseSurface,
              ),
              labelStyle: AppTheme.figureLabel(context),
            );
            return MouseRegion(
              onHover: (event) => _pick(painter, size, event.localPosition),
              onExit: (_) => setState(() => _selected = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _pick(painter, size, details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    _pick(painter, size, details.localPosition),
                child: CustomPaint(size: size, painter: painter),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _ChartLegend(moves: chart.moves),
      ],
    );
  }
}

/// What the line's colours mean, only those it uses, and how to read a
/// price off it.
class const _ChartLegend({required final List<PriceMove> moves})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (moves.contains(PriceMove.drop))
          _LegendKey(colour: colors.positive, label: strings.priceChartDrop),
        if (moves.contains(PriceMove.rise))
          _LegendKey(colour: colors.negative, label: strings.priceChartRise),
        Text(strings.priceChartHint, style: AppTheme.figureLabel(context)),
      ],
    );
  }
}

class const _LegendKey({
  required final Color colour,
  required final String label,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppTheme.figureLabel(context)),
    ],
  );
}

typedef _ChartColours = ({
  Color neutral,
  Color drop,
  Color rise,
  Color surface,
  Color grid,
  Color guide,
  Color tip,
  Color onTip,
});

/// Draws a [PriceChart] (N.129): round prices on the left with light
/// gridlines, the dates along the bottom, and the step line over real
/// time, each stretch in its move's colour (drops green, rises red, the
/// first price grey) with a light fill of the same colour under it; a dot
/// per recorded price, today's price labelled at the right, the picked
/// price's date, price and move in a label, and the site's earlier price
/// as a dashed line.
class _PriceChartPainter({
  required final AppLanguage language,
  required final PriceChart chart,
  required final int? selected,
  required final _ChartColours colours,
  required final TextStyle labelStyle,
}) extends CustomPainter {
  /// Room for the biggest dot at either edge.
  static const _dot = 7.0;

  /// Space above the plot, between the prices and the plot, and between
  /// the plot and the dates.
  static const _top = 8.0;
  static const _gap = 8.0;

  TextPainter _layout(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  String _price(double price) => Formatters.price(price, language: language);

  /// The width of the price labels on the left.
  double get _axisWidth {
    var widest = 0.0;
    for (final tick in chart.ticks) {
      final text = _layout(_price(tick.price), labelStyle);
      widest = max(widest, text.width);
      text.dispose();
    }
    return widest;
  }

  double get _dateHeight {
    final text = _layout(Formatters.date(chart.start), labelStyle);
    final height = text.height;
    text.dispose();
    return height;
  }

  /// Where the line is drawn within [size].
  Rect _plot(Size size) => Rect.fromLTRB(
    _axisWidth + _gap + _dot,
    _top,
    size.width - _dot,
    size.height - _dateHeight - _gap,
  );

  /// A point of the widget, as the chart's x (0 to 1).
  double chartX(Size size, double dx) {
    final plot = _plot(size);
    return ((dx - plot.left) / plot.width).clamp(0, 1).toDouble();
  }

  Color _colourOf(PriceMove move) => switch (move) {
    .drop => colours.drop,
    .rise => colours.rise,
    _ => colours.neutral,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plot(size);
    final axis = _axisWidth;
    Offset at(ChartPoint p) =>
        Offset(plot.left + p.x * plot.width, plot.bottom - p.y * plot.height);
    double yOf(double y) => plot.bottom - y * plot.height;
    final lineLeft = axis + _gap;

    // Round prices, right-aligned on the left, with their gridlines.
    final grid = Paint()
      ..color = colours.grid
      ..strokeWidth = 1;
    for (final tick in chart.ticks) {
      final dy = yOf(tick.y);
      canvas.drawLine(Offset(lineLeft, dy), Offset(size.width, dy), grid);
      final text = _layout(_price(tick.price), labelStyle);
      text
        ..paint(canvas, Offset(axis - text.width, dy - text.height / 2))
        ..dispose();
    }
    canvas.drawLine(
      Offset(lineLeft, plot.bottom + _dot / 2),
      Offset(size.width, plot.bottom + _dot / 2),
      grid,
    );

    // The site's earlier price: a dashed line, its label above it.
    if ((chart.reference, chart.referenceY) case (
      final reference?,
      final referenceY?,
    )) {
      final dy = yOf(referenceY);
      for (var x = lineLeft; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, dy),
          Offset(min(x + 4, size.width), dy),
          grid,
        );
      }
      final text = _layout(
        language.messages.previouslyAt(price: _price(reference)),
        labelStyle,
      );
      final above = dy - text.height - 2;
      text
        ..paint(canvas, Offset(plot.left, above < 0 ? dy + 2 : above))
        ..dispose();
    }

    // Each price's stretch: from its change to the next one, the last to
    // now, in its move's colour, with a fill fading to the bottom.
    final n = chart.changes.length;
    final points = [for (final p in chart.changes) at(p)];
    double endOf(int i) => i + 1 < n ? points[i + 1].dx : plot.right;
    for (var i = 0; i < n; i++) {
      final colour = _colourOf(chart.moves[i]);
      canvas.drawRect(
        Rect.fromLTRB(points[i].dx, points[i].dy, endOf(i), plot.bottom),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.18),
              colour.withValues(alpha: 0.02),
            ],
          ).createShader(plot),
      );
    }
    for (var i = 0; i < n; i++) {
      final path = Path();
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path
          ..moveTo(points[i].dx, points[i - 1].dy)
          ..lineTo(points[i].dx, points[i].dy);
      }
      path.lineTo(endOf(i), points[i].dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = _colourOf(chart.moves[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // The picked price's guide, under the dots.
    final picked = selected;
    if (picked != null) {
      final guide = Paint()
        ..color = colours.guide
        ..strokeWidth = 1;
      final dx = points[picked].dx;
      for (var y = plot.top; y < plot.bottom; y += 6) {
        canvas.drawLine(
          Offset(dx, y),
          Offset(dx, min(y + 3, plot.bottom)),
          guide,
        );
      }
    }

    // Each dot ringed in the card's colour, so it stands out of the line;
    // the picked one bigger.
    final ring = Paint()..color = colours.surface;
    for (var i = 0; i < n; i++) {
      final big = i == picked;
      canvas
        ..drawCircle(points[i], big ? 7 : 5.5, ring)
        ..drawCircle(
          points[i],
          big ? 5.5 : 4,
          Paint()..color = _colourOf(chart.moves[i]),
        );
    }
    // Today's price, at the right edge.
    final now = Offset(plot.right, points.last.dy);
    final nowColour = _colourOf(chart.moves.last);
    canvas
      ..drawCircle(now, 6.5, ring)
      ..drawCircle(now, 5, Paint()..color = nowColour);

    _paintDates(canvas, size, plot);

    if (picked != null) {
      _paintTip(canvas, size, points[picked], picked);
    } else {
      _paintNow(canvas, size, now, nowColour);
    }
  }

  /// The first date under the first price, "Agora" at the right, and the
  /// date halfway when there is room for it.
  void _paintDates(Canvas canvas, Size size, Rect plot) {
    final y = plot.bottom + _gap;
    final first = _layout(Formatters.date(chart.start), labelStyle);
    final firstLeft = max(0.0, plot.left - first.width / 2);
    first.paint(canvas, Offset(firstLeft, y));
    final now = _layout(language.messages.priceHistoryNow, labelStyle);
    final nowLeft = size.width - now.width;
    now.paint(canvas, Offset(nowLeft, y));

    final span = chart.end.difference(chart.start);
    if (span >= const Duration(days: 2)) {
      final middle = _layout(
        Formatters.date(chart.start.add(span ~/ 2)),
        labelStyle,
      );
      final left = plot.center.dx - middle.width / 2;
      if (left > firstLeft + first.width + 12 &&
          left + middle.width + 12 < nowLeft) {
        middle.paint(canvas, Offset(left, y));
      }
      middle.dispose();
    }
    first.dispose();
    now.dispose();
  }

  /// A rounded label with its text, above [anchor] or, without room
  /// there, below it; kept within the chart.
  void _paintBubble(
    Canvas canvas,
    Size size,
    Offset anchor,
    List<TextPainter> lines, {
    required Color fill,
    Color? border,
    bool alignRight = false,
  }) {
    const padH = 8.0;
    const padV = 5.0;
    final width = lines.map((l) => l.width).reduce(max) + 2 * padH;
    final height = lines.fold(0.0, (sum, l) => sum + l.height) + 2 * padV;
    final above = anchor.dy - 12 - height;
    final top = above >= 0 ? above : anchor.dy + 12;
    final left = alignRight
        ? size.width - width
        : (anchor.dx - width / 2)
              .clamp(0.0, max(0.0, size.width - width))
              .toDouble();
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(box, Paint()..color = fill);
    if (border != null) {
      canvas.drawRRect(
        box,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    var y = top + padV;
    for (final line in lines) {
      line
        ..paint(canvas, Offset(left + padH, y))
        ..dispose();
      y += line.height;
    }
  }

  /// Today's price beside its dot, in its move's colour.
  void _paintNow(Canvas canvas, Size size, Offset now, Color colour) {
    final price = chart.points.last.price;
    _paintBubble(
      canvas,
      size,
      now,
      [
        _layout(
          _price(price),
          labelStyle.copyWith(color: colour, fontWeight: FontWeight.w700),
        ),
      ],
      fill: colours.surface,
      border: colour,
      alignRight: true,
    );
  }

  /// The picked price: its price, then its date and how it moved.
  void _paintTip(Canvas canvas, Size size, Offset anchor, int i) {
    final point = chart.points[i];
    final date = Formatters.date(point.observedAt);
    final before = i > 0 ? chart.points[i - 1].price : point.price;
    final change = point.price - before;
    final detail = switch (chart.moves[i]) {
      .first => '$date · ${language.messages.priceHistoryFirst}',
      .drop || .rise =>
        '$date · ${priceMoveText(change, change / before * 100, language: language)}',
      _ => date,
    };
    _paintBubble(canvas, size, anchor, [
      _layout(
        _price(point.price),
        labelStyle.copyWith(
          color: colours.onTip,
          fontWeight: FontWeight.w700,
          fontSize: (labelStyle.fontSize ?? 11) + 2,
        ),
      ),
      _layout(
        detail,
        labelStyle.copyWith(color: colours.onTip.withValues(alpha: 0.85)),
      ),
    ], fill: colours.tip);
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) =>
      old.chart != chart ||
      old.selected != selected ||
      old.language != language ||
      old.colours != colours ||
      old.labelStyle != labelStyle;
}
