import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';

/// The Deal Score in its band colour (90+ excellent, 80+ very good,
/// 70+ interesting, 60+ normal, below 60 poor). [large] is the square
/// shown at the top of the score explanation.
class DealScoreBadge extends StatelessWidget {
  const DealScoreBadge({
    required this.score,
    this.large = false,
    this.showLabel = false,
    super.key,
  });

  final int score;
  final bool large;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).score(score);

    final badge = Container(
      constraints: BoxConstraints(
        minWidth: large ? 64 : 44,
        minHeight: large ? 64 : 32,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(large ? 12 : 7),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          '$score',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: large ? 32 : 22,
            height: 1.1,
            color: AppColors.onPhoto,
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
      ),
    );

    return Semantics(
      label: context.strings.dealScoreOutOf100(score: (score).toString()),
      excludeSemantics: true,
      child: showLabel
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.photoPillScrim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    badge,
                    const SizedBox(height: 3),
                    Text(
                      context.strings.dealScore,
                      style: AppTheme.onPhotoLabel.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            )
          : badge,
    );
  }
}
