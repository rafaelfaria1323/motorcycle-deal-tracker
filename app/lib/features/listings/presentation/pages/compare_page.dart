import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listings_repository.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../widgets/listing_photo.dart';
import '../../../../core/localization/localizations.dart';

/// Up to three listings side by side, one column each, the best value of
/// each row highlighted. The ids live in the address, so the page survives
/// a reload and can be shared.
class const ComparePage({required final List<String> ids, super.key})
    extends StatefulWidget {
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  late Future<List<Listing>> _future = _load();

  Future<List<Listing>> _load() async {
    final repository = getIt<ListingsRepository>();
    final found = await Future.wait(widget.ids.map(repository.getListingById));
    return [for (final l in found) ?l];
  }

  @override
  void didUpdateWidget(ComparePage old) {
    super.didUpdateWidget(old);
    if (old.ids.join(',') != widget.ids.join(',')) _future = _load();
  }

  void _remove(String id) {
    final cubit = getIt<CompareCubit>();
    if (cubit.contains(id)) cubit.toggle(id);
    final rest = [
      for (final other in widget.ids)
        if (other != id) other,
    ];
    if (rest.isEmpty) {
      _close();
    } else {
      // In place of this entry, so back doesn't bring the removed one back.
      Router.neglect(context, () => context.replace(AppRoutes.compare(rest)));
    }
  }

  void _close() => goBack(context, fallback: AppRoutes.deals);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _close),
        title: Text(context.strings.compare),
      ),
      body: FutureBuilder<List<Listing>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: context.strings.couldNotLoadListings,
              message: context.strings.checkYourConnectionAndTryAgain,
              actionLabel: context.strings.retry,
              onAction: () => setState(() => _future = _load()),
            );
          }
          final listings = snapshot.data;
          if (listings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (listings.length < 2) {
            return StateMessage(
              icon: Icons.compare_arrows,
              title: context.strings.chooseAtLeastTwoListings,
              message: context.strings.inDealsPressAndHoldListingOrUse(
                maxCompared: (maxCompared).toString(),
              ),
              actionLabel: context.strings.viewDeals,
              onAction: () => context.go(AppRoutes.deals),
            );
          }
          return _Table(listings: listings, onRemove: _remove);
        },
      ),
    );
  }
}

class const _Table({
  required final List<Listing> listings,
  required final ValueChanged<String> onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final rows = compareRows(listings, language: context.language);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, l) in listings.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Header(listing: l, onRemove: () => onRemove(l.id)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rows) ...[
          const Divider(height: 16),
          Text(
            row.label,
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, value) in row.values.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: row.best.contains(i)
                              ? theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.positive,
                                  fontWeight: FontWeight.w700,
                                )
                              : theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (row.best.contains(i))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.check_circle,
                            size: 14,
                            color: colors.positive,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class const _Header({
  required final Listing listing,
  required final VoidCallback onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = [
      listing.brand,
      listing.model,
      if (listing.year != null) '${listing.year}',
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            InkWell(
              onTap: () => context.push(
                AppRoutes.listingDetail(listing.id),
                extra: AppRoutes.fromList,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ListingPhoto(
                    url: listing.images.isEmpty ? null : listing.images.first,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: context.strings.removeFromComparison,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
