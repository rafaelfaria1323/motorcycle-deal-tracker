import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../offer_text.dart';
import '../seller_message_text.dart';
import '../../../../core/localization/localizations.dart';

/// "Mensagem para o vendedor": a first message with the questions the ad
/// leaves open, optionally with the suggested opening offer, copied with
/// one tap. Hidden for removed listings.
class SellerMessageCard extends StatefulWidget {
  const SellerMessageCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<SellerMessageCard> createState() => _SellerMessageCardState();
}

class _SellerMessageCardState extends State<SellerMessageCard> {
  late final Future<OfferSuggestion?> _offer = _loadOffer();
  bool _withOffer = false;

  Future<OfferSuggestion?> _loadOffer() async {
    final messageLanguage = context.language;

    final listing = widget.listing;
    // The same suggestion as "Quanto oferecer".
    if (suggestOffer(listing, language: messageLanguage) == null) return null;
    final id = listing.motorcycleId;
    MarketBehaviour? market;
    if (id != null) {
      try {
        market = await getIt<MarketBehaviourRepository>().getForModel(id);
      } catch (_) {
        // Without the model's figures the suggestion still works.
      }
    }
    return suggestOffer(
      listing,
      market: market,
      daysListed: daysOnSale(listing),
      language: messageLanguage,
    );
  }

  Future<void> _copy(String text) async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      showMessage(messenger, messageStrings.messageCopied);
    } catch (_) {
      showMessage(messenger, messageStrings.couldNotCopySelectTextInstead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing.isRemoved) return const SizedBox.shrink();

    return FutureBuilder<OfferSuggestion?>(
      future: _offer,
      builder: (context, snapshot) {
        final offer = snapshot.data;
        final message = sellerMessage(
          listing,
          offer: _withOffer ? offer?.opening : null,
          language: context.language,
        );
        final theme = Theme.of(context);

        return SectionCard(
          title: context.strings.messageToSeller,
          children: [
            if (offer != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  context.strings.includeOfferOf(
                    price: Formatters.price(
                      offer.opening,
                      language: context.language,
                    ),
                  ),
                ),
                value: _withOffer,
                onChanged: (value) => setState(() => _withOffer = value),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(message),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _copy(message),
              icon: const Icon(Icons.copy),
              label: Text(context.strings.copyMessageSellerMessageCard),
            ),
          ],
        );
      },
    );
  }
}
