import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../listing_card_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import '../photo_url.dart';
import 'deal_score_badge.dart';
import 'listing_photo.dart';
import 'photo_tag.dart';
import 'price_change_tag.dart';
import '../../../../core/localization/localizations.dart';

class const ListingCard({
  required final Listing listing,
  final VoidCallback? onTap,

  /// Picks the listing for the comparison.
  final VoidCallback? onLongPress,
  final bool selected = false,
  final bool favourite = false,

  /// Adds the listing to the favourites or takes it out (the button on the
  /// photo); without it a favourite only shows its star.
  final VoidCallback? onFavourite,
  final ListingCardPreferences preferences =
      const ListingCardPreferences.defaults(),
  super.key,
}) extends StatelessWidget {
  static const photoHeight = 180.0;
  static const _gridFactLines = 2;

  /// The height of every card in a grid: room for a two-line name, the
  /// year and mileage line when either is shown, the price box (with the
  /// estimated value when the market position is shown), one line of
  /// warnings and a line per optional fact of up to [_gridFactLines]
  /// lines; a card that needs less leaves the space above its footer.
  static double gridHeight(
    BuildContext context, {
    ListingCardPreferences preferences =
        const ListingCardPreferences.defaults(),
  }) {
    final chips = ListingCardPreferences.additionalFields
        .where((field) => field != .publishedAt && preferences.shows(field))
        .length;
    final hasYearOrMileage =
        preferences.shows(ListingCardField.year) ||
        preferences.shows(ListingCardField.mileage);
    final scaler = MediaQuery.textScalerOf(context);
    final chipLine = _chipLineHeight(context);
    return 410 +
        (chipLine + _chipPadding * 2 + 10) -
        (hasYearOrMileage ? 0 : 25) +
        (preferences.shows(ListingCardField.marketPosition)
            ? chipLine * 2 + 2
            : 0) +
        chips * (chipLine * _gridFactLines + _chipPadding * 2 + 6) +
        (scaler.scale(16) - 16) * 10;
  }

  static const _chipPadding = 3.0;

  static double _chipLineHeight(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return (MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 13) *
            (style?.height ?? 1.4))
        .ceilToDouble();
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
                  onFavourite: onFavourite,
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
                if (showLocation || onLongPress != null || onTap != null) ...[
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

/// The photo with, as in the Stitch design, the site and the ad's age at
/// the top left (each when chosen), the favourite button at the top right
/// and "Removido" at the bottom.
class const _CardPhoto({
  required final Listing listing,
  required final bool favourite,
  required final VoidCallback? onFavourite,
  required final ListingCardPreferences preferences,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final published = preferences.shows(ListingCardField.publishedAt)
        ? listing.publishedAt
        : null;
    final showSource = preferences.shows(ListingCardField.source);
    return SizedBox(
      height: ListingCard.photoHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListingPhoto(
            url: listing.images.isEmpty ? null : listing.images.first,
            box: cardPhotoBox(
              MediaQuery.sizeOf(context).width,
              MediaQuery.devicePixelRatioOf(context),
            ),
          ),
          if (showSource || published != null)
            Positioned(
              top: 10,
              left: 10,
              right: 56,
              child: Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (showSource)
                      PhotoTag(
                        sourceLabel(listing.source, language: context.language),
                        strong: true,
                      ),
                    if (published != null)
                      PhotoTag(
                        listingAgeText(published, language: context.language),
                      ),
                  ],
                ),
              ),
            ),
          if (listing.isRemoved)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _PhotoPill(context.strings.removed),
              ),
            ),
          if (onFavourite != null || favourite)
            Positioned(
              top: 4,
              right: 4,
              child: _FavouriteToggle(
                favourite: favourite,
                onPressed: onFavourite,
              ),
            ),
        ],
      ),
    );
  }
}

/// The round button on the photo: the star, filled for a favourite.
class const _FavouriteToggle({
  required final bool favourite,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      favourite ? Icons.star : Icons.star_border,
      size: 20,
      color: favourite ? scheme.primary : scheme.onSurface,
      semanticLabel: onPressed == null ? context.strings.inFavourites : null,
    );
    final background = scheme.surfaceContainerLowest.withValues(alpha: 0.92);
    if (onPressed == null) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: background,
          child: icon,
        ),
      );
    }
    return IconButton(
      tooltip: favourite
          ? context.strings.removeFromFavouritesFavouriteWidgets
          : context.strings.addToFavourites,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: background,
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: icon,
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
    final warnings = cardWarnings(
      listing.riskReasons,
      language: context.language,
    );
    final preferredColour =
        preferences.shows(ListingCardField.preferredColour) && listing.myColour;
    final flags = [
      for (final warning in warnings)
        _FactChip(
          warning,
          icon: Icons.warning_amber_rounded,
          tone: _Tone.warning,
          maxLines: 1,
        ),
      if (preferredColour)
        _FactChip(
          context.strings.preferredColour,
          icon: Icons.palette_outlined,
          tone: _Tone.positive,
          maxLines: 1,
        ),
    ];
    final facts = [
      for (final (field, text) in listingCardExtraFacts(
        listing,
        preferences,
        language: context.language,
      ))
        _factChip(context, field, text),
    ];

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
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 10),
            // One line in a grid cell (its height counts one), wrapped
            // elsewhere.
            if (maxFactLines != null)
              Row(
                spacing: 6,
                children: [for (final flag in flags) Flexible(child: flag)],
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: flags),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: facts),
          ],
        ],
      ),
    );
  }

  _FactChip _factChip(
    BuildContext context,
    ListingCardField field,
    String text,
  ) {
    if (field == .riskScore) {
      final risk = listing.riskScore ?? 0;
      final colors = AppColors.of(context);
      return _FactChip(
        text,
        dot: risk >= 50
            ? colors.negative
            : risk >= 20
            ? colors.scoreInteresting
            : colors.positive,
        maxLines: maxFactLines,
      );
    }
    final positive = switch (field) {
      .registrations =>
        listing.registrations == 1 ||
            (listing.registrations == null && listing.hasFirstOwnerSignal),
      .serviceBook => listing.serviceBook ?? false,
      .warrantyUntil || .dealerWarrantyMonths => true,
      _ => false,
    };
    return _FactChip(
      text,
      icon: switch (field) {
        ListingCardField.sellerType => Icons.store_outlined,
        ListingCardField.firstSeenAt => Icons.schedule,
        ListingCardField.colour => Icons.palette_outlined,
        ListingCardField.registrations => Icons.person_outline,
        ListingCardField.serviceBook => Icons.menu_book_outlined,
        ListingCardField.origin => Icons.public_outlined,
        ListingCardField.warrantyUntil ||
        ListingCardField.dealerWarrantyMonths => Icons.verified_user_outlined,
        ListingCardField.sellerName => Icons.storefront_outlined,
        ListingCardField.siteRefreshedAt => Icons.update,
        ListingCardField.status => Icons.info_outline,
        _ => throw ArgumentError.value(field),
      },
      tone: positive ? _Tone.positive : _Tone.neutral,
      maxLines: maxFactLines,
    );
  }
}

enum _Tone { neutral, positive, warning }

/// A fact under the price, as Stitch's chips: reassuring ones tinted
/// green, the serious risk reasons red, the rest grey; the Risk Score
/// with a dot in its colour.
class const _FactChip(
  final String text, {
  final IconData? icon,
  final Color? dot,
  final _Tone tone = _Tone.neutral,
  final int? maxLines,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, iconColour) = switch (tone) {
      _Tone.positive => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _Tone.warning => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.onErrorContainer,
      ),
      _Tone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: ListingCard._chipPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            if (dot != null)
              DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 7),
              )
            else if (icon != null)
              Icon(icon, size: 14, color: iconColour),
            Flexible(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The price and its change on the left and, on the same row (below it
/// when there is no room), where the price sits against the estimated
/// value, in a filled box without a border, with the estimated value
/// under the price, as in the Stitch list design.
class const _PriceLine({
  required final Listing listing,
  required final ListingCardPreferences preferences,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final showPosition = preferences.shows(ListingCardField.marketPosition);
    final pct = showPosition ? listing.marketPosition : null;
    final position = showPosition
        ? cardMarketPositionText(listing, language: context.language)
        : null;
    final estimate = showPosition
        ? estimatedValueText(listing, language: context.language)
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            Wrap(
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
                      if (pct!.abs() >= 0.05)
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
            if (estimate != null)
              // Two lines at most: a long mileage on a narrow card must not
              // cut off the value (`gridHeight` counts the second).
              Text(
                estimate,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The place on the left and "Comparar" with its check box on the right
/// (the whole card opens the ad).
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
      padding: const EdgeInsets.only(left: 16, right: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                ),
                label: Text(context.strings.compare),
              ),
            )
          else
            const SizedBox(height: 48, width: 8),
        ],
      ),
    );
  }
}

/// "Removido" on the photo, on a dark scrim.
class const _PhotoPill(final String text) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.photoPillScrim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.onPhotoLabel,
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
