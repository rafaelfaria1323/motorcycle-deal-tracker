import 'package:flutter/material.dart';

import '../../domain/entities/model_market.dart';

/// A small line of a model's weekly adjusted median asking price, oldest on
/// the left. Its text is the trend line beside it, so it is left out of
/// the semantics.
class PriceTrendSparkline extends StatelessWidget {
  const PriceTrendSparkline({super.key, required this.weeks});

  /// Weeks with enough ads, oldest first; at least two.
  final List<PriceTrendWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: 36,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: [for (final w in weeks) w.adjustedMedian],
            line: scheme.primary,
            baseline: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.line,
    required this.baseline,
  });

  final List<double> values;
  final Color line;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    // A flat line sits in the middle rather than on an edge.
    final range = high - low;
    const pad = 4.0;
    final height = size.height - 2 * pad;
    Offset point(int i) => Offset(
      size.width * i / (values.length - 1),
      range == 0
          ? size.height / 2
          : pad + height * (1 - (values[i] - low) / range),
    );

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
    canvas.drawCircle(point(values.length - 1), 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.line != line ||
      old.baseline != baseline ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
