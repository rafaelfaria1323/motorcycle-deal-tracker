import 'package:flutter/material.dart';

import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import 'deal_score_badge.dart';
import 'listing_photo.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({required this.listing, this.onTap, super.key});

  final Listing listing;
  final VoidCallback? onTap;

  static const photoHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = [
      '${listing.brand} ${listing.model}',
      if (listing.year != null) '${listing.year}',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                      top: 8,
                      right: 8,
                      child: DealScoreBadge(score: listing.dealScore!),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.price(listing.price),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.mileage(listing.mileage)}'
                    ' · ${listing.location ?? '—'}',
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
