import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/platform/open_ad.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/listing.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';

/// The bar fixed below the ad, always in reach: the next step after
/// reading is the seller's ad, beside the price and the Deal Score.
class const ListingBottomBar({required final Listing listing, super.key})
    extends StatelessWidget {
  Future<void> _openOriginal(BuildContext context) async {
    final messageStrings = context.strings;

    final uri = adAddress(listing);
    final opened = uri != null && await openAd(uri);

    if (!opened && context.mounted) {
      showMessage(
        ScaffoldMessenger.of(context),
        messageStrings.couldNotOpenListing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The tab bar's colour, which Safari's bottom toolbar is tinted with.
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: LayoutBuilder(
                  // As Stitch's ad page: the price and the score on the
                  // left, the seller's ad on the right; the button takes
                  // at most about two thirds, its label shortened beyond.
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(child: _PriceSummary(listing: listing)),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.65,
                        ),
                        child: FilledButton.icon(
                          onPressed: () => _openOriginal(context),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            originalLinkLabel(
                              listing.source,
                              language: context.language,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar's left side: the price with the Deal Score beside it, and the
/// bike under them.
class const _PriceSummary({required final Listing listing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = listing.dealScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              listing.priceLabel(language: context.language),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            if (score != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.of(context).score(score),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '${context.strings.dealScore} $score'.toUpperCase(),
                    style: AppTheme.scoreBand,
                  ),
                ),
              ),
          ],
        ),
        Text(
          listing.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Sends the ad to someone: the app's page of it, with the bike, its price
/// and the seller's ad (F.4). Where there is no share sheet, it is copied.
/// In the page's bar, as on Stitch's ad page.
class const ShareListingButton({required final Listing listing, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.strings.shareListing,
    onPressed: () => shareOrCopy(
      ScaffoldMessenger.of(context),
      title: listing.nameAndYear,
      text: listingShareText(listing, language: context.language),
      url: listingLink(webOrigin, listing.id),
      language: context.language,
    ),
    icon: const Icon(Icons.ios_share),
  );
}
