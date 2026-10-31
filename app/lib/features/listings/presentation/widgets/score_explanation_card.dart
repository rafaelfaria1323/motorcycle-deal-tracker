import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../score_explanation.dart';
import '../../../../core/localization/localizations.dart';

class const ScoreExplanationCard({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final explanation = ScoreExplainer.explain(
      listing,
      language: context.language,
    );
    if (explanation == null) return const SizedBox.shrink();

    final risk = listing.riskScore;
    final used = explanation.slicesUsed;
    final total = explanation.slicesTotal;

    return SectionCard(
      title: context.strings.whyThisScore,
      footnote: used != null && total != null
          ? context.strings.basedOnOfFactors(
              used: (used).toString(),
              total: (total).toString(),
            )
          : null,
      children: [
        for (final line in explanation.lines) _LineRow(line: line),
        if (risk != null) ...[
          const Divider(height: 28),
          _RiskMeter(risk: risk),
        ],
      ],
    );
  }
}

/// "Risco · Baixo   12/100" over a bar filled in the risk's colour.
class const _RiskMeter({required final int risk}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final color = risk >= 50
        ? colors.negative
        : risk >= 20
        ? colors.scoreInteresting
        : colors.positive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: context.strings.riskScoreExplanationCard),
                  TextSpan(
                    text: ScoreExplainer.riskLabel(
                      risk,
                      language: context.language,
                    ),
                    style: TextStyle(color: color),
                  ),
                ],
              ),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '$risk/100',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: risk.clamp(0, 100) / 100,
            minHeight: 6,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class const _LineRow({required final ExplanationLine line})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, semantic) = switch (line.tone) {
      ExplanationTone.positive => (
        Icons.add_circle_outline,
        AppColors.of(context).positive,
        context.strings.positive,
      ),
      ExplanationTone.negative => (
        Icons.remove_circle_outline,
        AppColors.of(context).negative,
        context.strings.negative,
      ),
      ExplanationTone.neutral => (
        Icons.info_outline,
        scheme.onSurfaceVariant,
        context.strings.information,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color, semanticLabel: semantic),
          const SizedBox(width: 8),
          Expanded(child: Text(line.text)),
        ],
      ),
    );
  }
}
