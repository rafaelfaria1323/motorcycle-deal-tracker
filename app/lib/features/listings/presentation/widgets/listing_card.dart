import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../listing_card_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import 'deal_score_badge.dart';
import 'listing_photo.dart';
import 'price_change_tag.dart';
import '../../../../core/localization/localizations.dart';

class const ListingCard({
  required final Listing listing,
  final VoidCallback? onTap,

  /// Picks the listing for the comparison.
  final VoidCallback? onLongPress,
  final bool selected = false,
  final bool favourite = false,
  final ListingCardPreferences preferences =
      const ListingCardPreferences.defaults(),
  super.key,
}) extends StatelessWidget {
  static const photoHeight = 180.0;
  static const _gridFactLines = 2;

  /// The height of every card in a grid: room for a two-line name, the
  /// year and mileage line when either is shown, the price and
  /// [_gridFactLines] lines per optional fact; a card that needs less
  /// leaves the space above its footer.
  static double gridHeight(
    BuildContext context, {
    ListingCardPreferences preferences =
        const ListingCardPreferences.defaults(),
  }) {
    final extraRows = ListingCardPreferences.additionalFields
        .where(preferences.shows)
        .length;
    final hasYearOrMileage =
        preferences.shows(ListingCardField.year) ||
        preferences.shows(ListingCardField.mileage);
    final scaler = MediaQuery.textScalerOf(context);
    final factStyle = Theme.of(context).textTheme.bodyMedium;
    final factLineHeight =
        (scaler.scale(factStyle?.fontSize ?? 14) * (factStyle?.height ?? 1.5))
            .ceilToDouble();
    return 410 -
        (hasYearOrMileage ? 0 : 25) +
        (extraRows > 0
            ? extraRows * (factLineHeight * _gridFactLines + 8) + 2
            : 0) +
        (scaler.scale(16) - 16) * 10;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape;
    final showLocation = preferences.shows(ListingCardField.location);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: selected && shape is RoundedRectangleBorder
          ? shape.copyWith(
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardPhoto(
                  listing: listing,
                  favourite: favourite,
                  preferences: preferences,
                ),
                _CardDetails(
                  listing: listing,
                  preferences: preferences,
                  maxFactLines: constraints.hasBoundedHeight
                      ? _gridFactLines
                      : null,
                ),
                if (constraints.hasBoundedHeight) const Spacer(),
                if (showLocation || onLongPress != null) ...[
                  const Divider(),
                  _CardFooter(
                    listing: listing,
                    selected: selected,
                    onCompare: onLongPress,
                    showLocation: showLocation,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class const _CardPhoto({
  required final Listing listing,
  required final bool favourite,
  required final ListingCardPreferences preferences,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preferredColour =
        preferences.shows(ListingCardField.preferredColour) && listing.myColour;
    final warnings = cardWarnings(
      listing.riskReasons,
      language: context.language,
    );
    return SizedBox(
      height: ListingCard.photoHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListingPhoto(
            url: listing.images.isEmpty ? null : listing.images.first,
          ),
          if (preferences.shows(ListingCardField.source))
            Positioned(
              top: 12,
              left: 12,
              right: favourite ? 52 : 12,
              child: Align(
                alignment: Alignment.topLeft,
                child: _PhotoPill(
                  sourceLabel(listing.source, language: context.language),
                ),
              ),
            ),
          if (listing.isRemoved || preferredColour || warnings.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (listing.isRemoved) _PhotoPill(context.strings.removed),
                  for (final warning in warnings)
                    _PhotoPill(warning, icon: Icons.warning_amber_rounded),
                  if (preferredColour)
                    _PhotoPill(
                      context.strings.preferredColour,
                      icon: Icons.palette_outlined,
                    ),
                ],
              ),
            ),
          if (favourite)
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.photoPillScrim,
                child: Icon(
                  Icons.star,
                  size: 16,
                  color: AppColors.onPhoto,
                  semanticLabel: context.strings.inFavourites,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class const _CardDetails({
  required final Listing listing,
  required final ListingCardPreferences preferences,
  final int? maxFactLines,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final score = preferences.shows(ListingCardField.dealScore)
        ? listing.dealScore
        : null;
    final yearAndMileage = yearAndMileageText(
      listing,
      preferences,
      language: context.language,
    );
    final extraFacts = listingCardExtraFacts(
      listing,
      preferences,
      language: context.language,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      listing.name,
                      style: textTheme.titleLarge?.copyWith(fontSize: 21),
                      maxLines: MediaQuery.textScalerOf(context).scale(16) > 20
                          ? null
                          : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (yearAndMileage != null)
                      Text(
                        yearAndMileage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: muted,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
              ),
              if (score != null) DealScoreBadge(score: score, showBand: true),
            ],
          ),
          const SizedBox(height: 10),
          _PriceLine(listing: listing, preferences: preferences),
          if (extraFacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium?.copyWith(color: muted),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: muted),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    for (final (field, text) in extraFacts)
                      Row(
                        spacing: 5,
                        children: [
                          Icon(switch (field) {
                            ListingCardField.riskScore => Icons.shield_outlined,
                            ListingCardField.sellerType => Icons.store_outlined,
                            ListingCardField.firstSeenAt => Icons.schedule,
                            ListingCardField.colour => Icons.palette_outlined,
                            ListingCardField.registrations =>
                              Icons.person_outline,
                            ListingCardField.serviceBook =>
                              Icons.menu_book_outlined,
                            ListingCardField.origin => Icons.public_outlined,
                            ListingCardField.warrantyUntil ||
                            ListingCardField.dealerWarrantyMonths =>
                              Icons.verified_user_outlined,
                            ListingCardField.sellerName =>
                              Icons.storefront_outlined,
                            ListingCardField.publishedAt =>
                              Icons.calendar_month_outlined,
                            ListingCardField.siteRefreshedAt => Icons.update,
                            ListingCardField.status => Icons.info_outline,
                            _ => throw ArgumentError.value(field),
                          }),
                          Expanded(
                            child: Text(
                              text,
                              maxLines: maxFactLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The price and its change on the left and, on the same row (below it
/// when there is no room), where the price sits against the estimated
/// value, in a filled box without a border, as in the Stitch list design.
class const _PriceLine({
  required final Listing listing,
  required final ListingCardPreferences preferences,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final pct = preferences.shows(ListingCardField.marketPosition)
        ? listing.marketPosition
        : null;
    final position = marketPositionText(pct, language: context.language);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    listing.priceLabel(language: context.language),
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      height: 1.1,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                  if (preferences.shows(ListingCardField.priceChange))
                    PriceChangeTag(listing: listing),
                ],
              ),
              if (position != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    if (pct!.round() != 0)
                      Icon(
                        pct > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: _marketPositionColour(context, pct),
                      ),
                    Flexible(
                      child: Text(
                        position,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: _marketPositionColour(context, pct),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _CardFooter({
  required final Listing listing,
  required final bool selected,
  required final VoidCallback? onCompare,
  required final bool showLocation,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          if (showLocation) ...[
            Icon(Icons.place_outlined, size: 16, color: muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                placeText(listing, language: context.language) ??
                    context.strings.locationNotStated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ] else
            const Spacer(),
          if (onCompare != null)
            Tooltip(
              message: selected
                  ? context.strings.removeFromComparison
                  : context.strings.compare,
              child: TextButton.icon(
                onPressed: onCompare,
                style: TextButton.styleFrom(
                  foregroundColor: selected ? scheme.primary : muted,
                  minimumSize: const Size(48, 48),
                ),
                icon: Icon(
                  selected ? Icons.check_circle : Icons.compare_arrows,
                  size: 18,
                ),
                label: Text(
                  selected ? context.strings.remove : context.strings.compare,
                ),
              ),
            )
          else
            const SizedBox(height: 48, width: 12),
        ],
      ),
    );
  }
}

class const _PhotoPill(final String text, {final IconData? icon})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.photoPillScrim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (icon != null) Icon(icon, size: 14, color: AppColors.onPhoto),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.onPhotoLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green from 3 % below the estimate, red from 3 % above, muted between
/// (the listing page's price notice starts at 3 % too).
Color _marketPositionColour(BuildContext context, double pct) {
  final colors = AppColors.of(context);
  if (pct >= 3) return colors.positive;
  if (pct <= -3) return colors.negative;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
