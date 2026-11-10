import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../score_explanation.dart';

/// The Deal Score in its band colour (90+ excellent, 80+ very good,
/// 70+ interesting, 60+ normal, below 60 poor). [showBand] makes it the
/// cards' tile, with the band's name in small capitals under the figure
/// ("MUITO BOM"), as in the Stitch design.
class const DealScoreBadge({
  required final int score,
  final bool showBand = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).score(score);
    final figure = Text(
      '$score',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppTheme.displayFont,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.1,
        color: AppColors.onPhoto,
        fontFeatures: AppTheme.tabularFigures,
      ),
    );

    return Semantics(
      label: context.strings.dealScoreOutOf100(score: (score).toString()),
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(
          minWidth: showBand ? 56 : 44,
          maxWidth: showBand ? 80 : double.infinity,
          minHeight: showBand ? 48 : 32,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: showBand ? 6 : 8,
          vertical: showBand ? 5 : 4,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(showBand ? 10 : 7),
        ),
        child: showBand
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  figure,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      ScoreExplainer.label(
                        score,
                        language: context.language,
                      ).toUpperCase(),
                      maxLines: 1,
                      style: AppTheme.scoreBand,
                    ),
                  ),
                ],
              )
            : Center(widthFactor: 1, heightFactor: 1, child: figure),
      ),
    );
  }
}
