import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/listing.dart';
import '../listing_dates_text.dart';

/// Removed, duplicate, relisted: shown before anything else on the ad,
/// since they change how the rest reads. Nothing when none applies.
class const ListingStatusCards({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastSeenAt = listing.lastSeenAt;
    final duplicateOf = listing.duplicateOf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (listing.isRemoved)
          _StatusCard(
            color: scheme.errorContainer,
            icon: Icons.block,
            title: context.strings.listingRemovedListingDetailPage,
            text: lastSeenAt == null
                ? context.strings.thisListingIsNoLongerAvailable
                : context.strings.thisListingIsNoLongerAvailableLastSeen(
                    daysago: Formatters.daysAgo(
                      lastSeenAt,
                      language: context.language,
                    ),
                  ),
          ),
        if (duplicateOf != null)
          _StatusCard(
            color: scheme.secondaryContainer,
            icon: Icons.content_copy,
            title: context.strings.duplicateListing,
            text: context.strings.itAppearsToBeSameBikeAsAnother,
            actionLabel: context.strings.viewOriginal,
            onAction: () => context.push(
              AppRoutes.listingDetail(duplicateOf),
              extra: AppRoutes.fromList,
            ),
          ),
        if (relistText(listing, language: context.language) case final relist?)
          _StatusCard(
            color: scheme.secondaryContainer,
            icon: Icons.history,
            title: context.strings.relisted,
            text: relist,
            actionLabel: context.strings.viewEarlierListing,
            onAction: () => context.push(
              AppRoutes.listingDetail(listing.relistedFrom!),
              extra: AppRoutes.fromList,
            ),
          ),
      ],
    );
  }
}

class const _StatusCard({
  required final Color color,
  required final IconData icon,
  required final String title,
  required final String text,
  final String? actionLabel,
  final VoidCallback? onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(text),
        trailing: actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel)),
      ),
    );
  }
}
