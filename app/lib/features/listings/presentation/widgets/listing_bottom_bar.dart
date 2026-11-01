import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/listing.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';

/// The bar fixed below the ad, always in reach: the next step after
/// reading is the seller's ad. On wide screens it also shows the price.
class const ListingBottomBar({required final Listing listing, super.key})
    extends StatelessWidget {
  Future<void> _openOriginal(BuildContext context) async {
    final messageStrings = context.strings;

    final uri = adAddress(listing);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);

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
                  builder: (context, constraints) {
                    final button = FilledButton.icon(
                      onPressed: () => _openOriginal(context),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        originalLinkLabel(
                          listing.source,
                          language: context.language,
                        ),
                      ),
                    );
                    final share = _ShareButton(listing: listing);
                    if (constraints.maxWidth < 600) {
                      return Row(
                        children: [
                          share,
                          const SizedBox(width: 12),
                          Expanded(child: button),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.priceLabel(language: context.language),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFeatures: AppTheme.tabularFigures,
                            ),
                          ),
                        ),
                        share,
                        const SizedBox(width: 12),
                        button,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sends the ad to someone: the app's page of it, with the bike, its price
/// and the seller's ad (F.4). Where there is no share sheet, it is copied.
class const _ShareButton({required final Listing listing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.strings.shareListing,
    child: OutlinedButton(
      onPressed: () => shareOrCopy(
        ScaffoldMessenger.of(context),
        title: listing.nameAndYear,
        text: listingShareText(listing, language: context.language),
        url: listingLink(webOrigin, listing.id),
        language: context.language,
      ),
      child: const Icon(Icons.ios_share),
    ),
  );
}
