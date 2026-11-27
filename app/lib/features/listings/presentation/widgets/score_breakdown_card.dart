import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../score_breakdown_text.dart';

/// The Deal Score's whole calculation (N.126): each slice's score, weight
/// and points with how it was reached, then the weighted average, the
/// equipment bonus, any cap and the score.
class const ScoreBreakdownCard({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final breakdown = scoreBreakdownOf(listing, language: context.language);
    if (breakdown == null) return const SizedBox.shrink();

    return SectionCard(
      title: context.strings.scoreBreakdownTitle,
      footnote: context.strings.scoreBreakdownFootnote,
      children: [
        for (final (index, row) in breakdown.rows.indexed) ...[
          if (index > 0) const SizedBox(height: 14),
          _SliceRow(row: row),
        ],
        const Divider(height: 28),
        for (final total in breakdown.totals) _TotalRow(total: total),
      ],
    );
  }
}

class const _SliceRow({required final ScoreBreakdownRow row})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final score = row.score;
    final share = row.share;
    final points = row.points;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                row.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: row.counted ? null : muted,
                ),
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 12),
              Text(
                score,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ],
          ],
        ),
        if (share != null && points != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$share · $points',
              style: AppTheme.figureLabel(context),
            ),
          ),
        for (final detail in row.details)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class const _TotalRow({required final ScoreBreakdownTotal total})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (total.isResult
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyMedium)
            ?.copyWith(fontFeatures: AppTheme.tabularFigures);

    return Padding(
      padding: EdgeInsets.only(top: total.isResult ? 8 : 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(total.label, style: style)),
          const SizedBox(width: 12),
          Text(total.value, style: style),
        ],
      ),
    );
  }
}
