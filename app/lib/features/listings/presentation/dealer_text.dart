import '../../../core/formatting/formatters.dart';
import '../domain/entities/dealer_reliability.dart';
import '../domain/entities/listing.dart';
import '../../../core/localization/localizations.dart';

/// Below this many bikes the figures say little about a dealer.
const minDealerBikes = 5;

/// The name to look the listing's dealer up by, trimmed; null for private
/// or unknown sellers (their names are never stored) and empty names.
String? dealerLookupName(Listing listing) {
  if (listing.sellerType != SellerType.dealer) return null;
  final name = listing.sellerName?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// "Motos Lda: 12 motas vistas desde 21/08/2026 (5 à venda)".
String dealerHeadline(
  DealerReliability d, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final since = d.firstSeenAt;
  return language.messages.dealerBikesLine(
    name: d.name,
    bikes: d.bikes,
    since: since == null
        ? ''
        : language.messages.since(date: Formatters.date(since)),
    live: d.live.toString(),
  );
}

/// One line per warning sign found in the dealer's ads, then how often it
/// lowered its prices; a reassuring line when there are no warning signs.
List<String> dealerLines(
  DealerReliability d, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  String share(int n) => language.messages.ofTextDealerText(
    n: (n).toString(),
    bikes: d.bikes.toString(),
  );
  final warnings = [
    if (d.relisted > 0)
      language.messages.dealerRelisted(share: share(d.relisted)),
    if (d.sharpChanges > 0)
      language.messages.dealerSharpChanges(share: share(d.sharpChanges)),
    if (d.missingMileage > 0)
      language.messages.dealerNoMileage(share: share(d.missingMileage)),
    if (d.repeated > 0) language.messages.dealerRepeated(repeated: d.repeated),
  ];
  return [
    if (warnings.isEmpty) language.messages.noWarningSignsInThisDealerSListings,
    ...warnings,
    d.dropped == 0
        ? language.messages.hasNotReducedAnyBikeSPriceYet
        : language.messages.dealerDropped(share: share(d.dropped)),
    if (d.bikes < minDealerBikes)
      language.messages.notEnoughDataAboutThisDealerYetFewer(
        minDealerBikes: (minDealerBikes).toString(),
      ),
  ];
}
