import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/listing.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import '../score_explanation.dart';
import 'deal_score_badge.dart';
import 'price_change_tag.dart';

/// The top of the ad's summary: the site, the bike, its price, the key
/// facts and the Deal Score.
class const ListingHeader({
  required final Listing listing,

  /// On the bike's name, so the page knows when it has scrolled away.
  required final Key nameKey,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final score = listing.dealScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sourceLabel(listing.source, language: context.language).toUpperCase(),
          style: AppTheme.eyebrow(context),
        ),
        const SizedBox(height: 8),
        Text(
          listing.name,
          key: nameKey,
          style: textTheme.headlineLarge?.copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              listing.priceLabel(language: context.language),
              style: textTheme.displaySmall?.copyWith(
                fontSize: 42,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            PriceChangeTag(listing: listing),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          keyFactsLine(listing, language: context.language),
          style: textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                DealScoreBadge(score: score, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ScoreExplainer.label(score, language: context.language),
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.strings.dealScore0To100,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The bar's title once the page's own heading has scrolled away: the
/// bike, then its year and price (F.4).
class const ListingCompactTitle({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: listing.name, style: theme.textTheme.titleLarge),
          TextSpan(
            text: '\n${compactTitleLine(listing, language: context.language)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
