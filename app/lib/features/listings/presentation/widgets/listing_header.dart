import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/listing.dart';
import '../listing_card_text.dart';
import '../listing_detail_text.dart';
import '../score_explanation.dart';
import 'price_change_tag.dart';

/// The top of the ad's summary, after Stitch's ad page: the bike and its
/// price, its year, mileage and engine size as chips, who sells and
/// where, the box with the price against the median, and the Deal Score
/// and Risk Score side by side.
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
    final language = context.language;
    final specs = heroSpecs(listing, language: language);
    final seller = sellerText(listing, language: language);
    final place = placeText(listing, language: language);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The price beside the name while both fit, under it otherwise.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                listing.name,
                key: nameKey,
                style: textTheme.headlineMedium?.copyWith(height: 1.1),
              ),
              _Price(listing: listing),
            ],
          ),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final spec in specs) _SpecChip(spec)],
            ),
          ],
          if (seller != null || place != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (seller != null)
                  _IconText(
                    icon: listing.sellerType == .dealer
                        ? Icons.storefront_outlined
                        : Icons.person_outline,
                    text: seller,
                  ),
                if (place != null)
                  _IconText(icon: Icons.place_outlined, text: place),
              ],
            ),
          ],
          _MarketBox(listing: listing),
          _ScoreTiles(listing: listing),
        ],
      ),
    );
  }
}

/// The price, "Preço anunciado" under it and, when it changed, by how
/// much.
class const _Price({required final Listing listing}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          listing.priceLabel(language: context.language),
          style: textTheme.headlineLarge?.copyWith(
            height: 1.1,
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.strings.askingPriceLabel.toUpperCase(),
          style: AppTheme.groupLabel(context),
        ),
        if (listing.hasPriceChanged) ...[
          const SizedBox(height: 6),
          PriceChangeTag(listing: listing),
        ],
      ],
    );
  }
}

/// A fact of the bike in a filled box: "2023", "8 500 km", "690 cc".
class const _SpecChip(final String text) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
      ),
    );
  }
}

class const _IconText({
  required final IconData icon,
  required final String text,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Where the price sits against the median, as Stitch's tinted box:
/// an arrow and "11,4 % abaixo da mediana (860 €)", then the median for this bike's
/// year and mileage and how many ads it came from. Green below the
/// median, red above it; nothing without a market position.
class const _MarketBox({required final Listing listing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final position = cardMarketPositionText(listing, language: language);
    final pct = listing.marketPosition;
    if (position == null || pct == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final below = pct >= 0.05;
    final above = pct <= -0.05;
    final tone = below
        ? colors.positive
        : above
        ? colors.negative
        : theme.colorScheme.onSurface;
    final gap = marketGapText(listing, language: language);
    final notes = [
      ?estimatedValueText(listing, language: language),
      ?comparablesText(listing, language: language),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  if (below || above)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        below ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                        color: tone,
                        size: 20,
                      ),
                    ),
                  TextSpan(
                    text: [position, if (gap != null) '($gap)'].join(' '),
                  ),
                ],
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                color: tone,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                notes.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Deal Score and the Risk Score as two tiles, each with its figure
/// and its band on the band's colour; one above the other where two
/// don't fit.
class const _ScoreTiles({required final Listing listing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final score = listing.dealScore;
    final risk = listing.riskScore;
    if (score == null && risk == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final language = context.language;
    final tiles = [
      if (score != null)
        _ScoreTile(
          title: context.strings.dealScore,
          value: score,
          band: ScoreExplainer.label(score, language: language),
          color: colors.score(score),
        ),
      if (risk != null)
        _ScoreTile(
          title: context.strings.riskScore,
          value: risk,
          band: ScoreExplainer.riskLabel(risk, language: language),
          // The bands' own colours, which carry small white text (4.5:1)
          // in both themes.
          color: risk >= 50
              ? colors.scorePoor
              : risk >= 20
              ? colors.scoreInteresting
              : colors.scoreExcellent,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two tiles need about 140 px each at the reader's text size.
          final side = MediaQuery.textScalerOf(context).scale(300);
          if (tiles.length == 1 || constraints.maxWidth < side) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, tile) in tiles.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  tile,
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 12),
                Expanded(child: tiles[1]),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "DEAL SCORE  94 / 100" with the band ("EXCELENTE") on its colour.
class const _ScoreTile({
  required final String title,
  required final int value,
  required final String band,
  required final Color color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTheme.groupLabel(context)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$value',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    height: 1.05,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' / 100',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontFeatures: AppTheme.tabularFigures),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(band.toUpperCase(), style: AppTheme.scoreBand),
            ),
          ),
        ],
      ),
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
