import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

/// The Deal Score in its band colour (90+ excellent, 80+ very good,
/// 70+ interesting, 60+ normal, below 60 poor). [large] is the square
/// shown at the top of the score explanation.
class DealScoreBadge extends StatelessWidget {
  const DealScoreBadge({required this.score, this.large = false, super.key});

  final int score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).score(score);

    return Semantics(
      label: 'Deal Score $score',
      excludeSemantics: true,
      child: Container(
        constraints: large
            ? const BoxConstraints.tightFor(width: 56, height: 56)
            : const BoxConstraints(minWidth: 40),
        padding: large
            ? null
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        alignment: large ? Alignment.center : null,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(large ? 14 : 10),
          boxShadow: const [
            BoxShadow(
              color: AppColors.badgeShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$score',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: large ? 28 : 18,
            height: 1.1,
            color: AppColors.onPhoto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
