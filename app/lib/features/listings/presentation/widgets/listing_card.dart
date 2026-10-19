import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import 'deal_score_badge.dart';
import 'listing_photo.dart';
import 'price_change_tag.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final Listing listing;
  final VoidCallback? onTap;

  /// Picks the listing for the comparison.
  final VoidCallback? onLongPress;

  /// In the comparison: a primary border and a check mark.
  final bool selected;

  static const photoHeight = 180.0;

  /// The card's full height, for the grid's `mainAxisExtent`.
  static const height = 300.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;

    final shape = theme.cardTheme.shape;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: selected && shape is RoundedRectangleBorder
          ? shape.copyWith(
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListingPhoto(
                    url: listing.images.isEmpty ? null : listing.images.first,
                  ),
                  if (listing.dealScore != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: DealScoreBadge(score: listing.dealScore!),
                    ),
                  if (listing.isRemoved)
                    const Positioned(top: 10, left: 10, child: _RemovedPill()),
                  if (selected)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary,
                        child: Icon(
                          Icons.compare_arrows,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${listing.brand} ${listing.model}',
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        Formatters.price(listing.price),
                        style: textTheme.headlineSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PriceChangeTag(listing: listing),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: textTheme.bodyMedium?.copyWith(color: muted),
                    child: IconTheme.merge(
                      data: IconThemeData(size: 16, color: muted),
                      child: Row(
                        children: [
                          if (listing.year != null) ...[
                            const Icon(Icons.calendar_today_outlined),
                            const SizedBox(width: 4),
                            Text('${listing.year}'),
                            const SizedBox(width: 12),
                          ],
                          const Icon(Icons.speed),
                          const SizedBox(width: 4),
                          Text(Formatters.mileage(listing.mileage)),
                          if (listing.location != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.place_outlined),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                listing.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovedPill extends StatelessWidget {
  const _RemovedPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Removido',
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
