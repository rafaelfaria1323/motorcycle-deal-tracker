import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../domain/entities/listing.dart';
import '../listing_detail_text.dart';
import '../listing_report_text.dart';
import '../offer_context.dart';

/// "Relatório do anúncio" (16.8): the ad's whole analysis as text, sent
/// through the share sheet (or copied) with the app's link, to a mechanic
/// or to whoever goes to see the bike. The offer's figures are asked for
/// as the card is built (the same answer as "Quanto oferecer"), so the
/// tap opens the share sheet at once, as Safari requires.
class const ListingReportCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<ListingReportCard> createState() => _ListingReportCardState();
}

class _ListingReportCardState extends State<ListingReportCard> {
  late final Future<OfferContext> _context = offerContextOf(widget.listing);
  OfferContext? _loaded;

  @override
  void initState() {
    super.initState();
    _context.then((value) {
      if (mounted) setState(() => _loaded = value);
    });
  }

  void _share() {
    final listing = widget.listing;
    final (market, cheaper) = _loaded ?? (null, const <Listing>[]);
    final favourite = getIt<FavouritesCubit>().state.favouriteOf(listing.id);
    shareOrCopy(
      ScaffoldMessenger.of(context),
      title: context.strings.reportTitle(bike: listing.nameAndYear),
      text: listingReportText(
        listing,
        today: DateTime.now(),
        market: market,
        cheaper: cheaper,
        checklist: favourite?.checklist ?? const {},
        language: context.language,
      ),
      url: listingLink(webOrigin, listing.id),
      language: context.language,
    );
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.strings.listingReport,
    children: [
      Text(context.strings.listingReportBody),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: _share,
        icon: const Icon(Icons.description_outlined),
        label: Text(context.strings.shareReport),
      ),
    ],
  );
}
