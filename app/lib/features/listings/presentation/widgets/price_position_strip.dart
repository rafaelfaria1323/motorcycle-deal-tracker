import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../price_position_text.dart';
import '../../../../core/localization/localizations.dart';

/// The model's live asking prices on a line, lowest to highest: one dot per
/// listing, this one larger and in the primary colour.
class PricePositionStrip extends StatelessWidget {
  const PricePositionStrip({required this.position, super.key});

  final PricePosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = AppTheme.figureLabel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          width: double.infinity,
          child: CustomPaint(
            painter: _StripPainter(
              position: position,
              thisColor: theme.colorScheme.primary,
              otherColor: theme.colorScheme.onSurfaceVariant,
              lineColor: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        Row(
          children: [
            Text(
              Formatters.price(position.lowest, language: context.language),
              style: labelStyle,
            ),
            const Spacer(),
            Text(
              Formatters.price(position.highest, language: context.language),
              style: labelStyle,
            ),
          ],
        ),
        Text(context.strings.askingPricesUnadjusted, style: labelStyle),
      ],
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.position,
    required this.thisColor,
    required this.otherColor,
    required this.lineColor,
  });

  final PricePosition position;
  final Color thisColor;
  final Color otherColor;
  final Color lineColor;

  static const _thisRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Room for the larger dot at both ends.
    const left = _thisRadius;
    final width = size.width - 2 * _thisRadius;
    final y = size.height / 2;
    double x(double fraction) => left + fraction * width;

    canvas.drawLine(
      Offset(left, y),
      Offset(left + width, y),
      Paint()
        ..color = lineColor
        ..strokeWidth = 1,
    );
    final others = Paint()..color = otherColor.withValues(alpha: 0.45);
    for (final fraction in position.othersX) {
      canvas.drawCircle(Offset(x(fraction), y), 3.5, others);
    }
    canvas.drawCircle(
      Offset(x(position.thisX), y),
      _thisRadius,
      Paint()..color = thisColor,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.position != position ||
      old.thisColor != thisColor ||
      old.otherColor != otherColor ||
      old.lineColor != lineColor;
}
