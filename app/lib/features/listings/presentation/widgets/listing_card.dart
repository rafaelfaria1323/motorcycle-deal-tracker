import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../listing_card_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import 'deal_score_badge.dart';
import 'listing_photo.dart';
import 'price_change_tag.dart';
import '../../../../core/localization/localizations.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.favourite = false,
    this.preferences = const ListingCardPreferences.defaults(),
    super.key,
  });

  final Listing listing;
  final VoidCallback? onTap;

  /// Picks the listing for the comparison.
  final VoidCallback? onLongPress;

  final bool selected;
  final bool favourite;
  final ListingCardPreferences preferences;

  static const photoHeight = 180.0;
  static const _gridFactLines = 2;

  static double gridHeight(
    BuildContext context, {
    ListingCardPreferences preferences =
        const ListingCardPreferences.defaults(),
  }) {
    final extraRows = ListingCardPreferences.additionalFields
        .where(preferences.shows)
        .length;
    final hasFacts =
        preferences.shows(ListingCardField.year) ||
        preferences.shows(ListingCardField.mileage) ||
        extraRows > 0;
    final scaler = MediaQuery.textScalerOf(context);
    final factStyle = Theme.of(context).textTheme.bodyMedium;
    final factLineHeight =
        (scaler.scale(factStyle?.fontSize ?? 14) * (factStyle?.height ?? 1.5))
            .ceilToDouble();
    return 390 -
        (hasFacts ? 0 : 32) +
        extraRows * (factLineHeight * _gridFactLines + 8) +
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

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({
    required this.listing,
    required this.favourite,
    required this.preferences,
  });

  final Listing listing;
  final bool favourite;
  final ListingCardPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final score = preferences.shows(ListingCardField.dealScore)
        ? listing.dealScore
        : null;
    final preferredColour =
        preferences.shows(ListingCardField.preferredColour) && listing.myColour;
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
              right: preferences.shows(ListingCardField.dealScore) ? 100 : 12,
              child: Align(
                alignment: Alignment.topLeft,
                child: _PhotoPill(
                  sourceLabel(listing.source, language: context.language),
                ),
              ),
            ),
          if (score != null)
            Positioned(
              top: 12,
              right: 12,
              child: DealScoreBadge(score: score, showLabel: true),
            ),
          if (listing.isRemoved || preferredColour)
            Positioned(
              bottom: 12,
              left: 12,
              right: favourite ? 52 : 12,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (listing.isRemoved) _PhotoPill(context.strings.removed),
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
              bottom: 10,
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

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.listing,
    required this.preferences,
    this.maxFactLines,
  });

  final Listing listing;
  final ListingCardPreferences preferences;
  final int? maxFactLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final showYear =
        preferences.shows(ListingCardField.year) && listing.year != null;
    final showMileage = preferences.shows(ListingCardField.mileage);
    final extraFacts = listingCardExtraFacts(
      listing,
      preferences,
      language: context.language,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${listing.brand} ${listing.model}',
            style: textTheme.titleLarge?.copyWith(fontSize: 23),
            maxLines: MediaQuery.textScalerOf(context).scale(16) > 20
                ? null
                : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                Formatters.price(listing.price, language: context.language),
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  height: 1.1,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
              if (preferences.shows(ListingCardField.priceChange))
                PriceChangeTag(listing: listing),
            ],
          ),
          if (showYear || showMileage || extraFacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium?.copyWith(color: muted),
              child: IconTheme.merge(
                data: IconThemeData(size: 16, color: muted),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    if (showYear || showMileage)
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showYear)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 5,
                              children: [
                                const Icon(Icons.calendar_today_outlined),
                                Text('${listing.year}'),
                              ],
                            ),
                          if (showMileage)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 5,
                              children: [
                                const Icon(Icons.speed),
                                Text(
                                  Formatters.mileage(
                                    listing.mileage,
                                    language: context.language,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.listing,
    required this.selected,
    required this.onCompare,
    required this.showLocation,
  });

  final Listing listing;
  final bool selected;
  final VoidCallback? onCompare;
  final bool showLocation;

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

class _PhotoPill extends StatelessWidget {
  const _PhotoPill(this.text, {this.icon});

  final String text;
  final IconData? icon;

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
