import '../../../core/formatting/formatters.dart';
import '../domain/entities/dealer_reliability.dart';
import '../../../core/localization/localizations.dart';

/// Below this many bikes the figures say little about a dealer.
const minDealerBikes = 5;

/// "Motos Lda: 12 motas vistas desde 21/08/2026 (5 à venda)".
String dealerHeadline(
  DealerReliability d, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final since = d.firstSeenAt;
  return language.messages.forSale(
    name: d.name,
    bikes: d.bikes.toString(),
    value: d.bikes == 1
        ? language.messages.bikeSeen
        : language.messages.bikesSeen,
    value4: since == null
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
      language.messages.relistedAfterEarlierListingDisappeared(
        value: share(d.relisted),
      ),
    if (d.sharpChanges > 0)
      language.messages.withSharpPriceChanges50OrMoreIn(
        value: share(d.sharpChanges),
      ),
    if (d.missingMileage > 0)
      language.messages.withNoMileage(value: share(d.missingMileage)),
    if (d.repeated > 0)
      language.messages.forSameUsedBikeOnSameSite(
        repeated: d.repeated.toString(),
        value: d.repeated == 1
            ? language.messages.repeatedListing
            : language.messages.repeatedListings,
      ),
  ];
  return [
    if (warnings.isEmpty) language.messages.noWarningSignsInThisDealerSListings,
    ...warnings,
    d.dropped == 0
        ? language.messages.hasNotReducedAnyBikeSPriceYet
        : language.messages.reducedPriceOf(value: share(d.dropped)),
    if (d.bikes < minDealerBikes)
      language.messages.notEnoughDataAboutThisDealerYetFewer(
        minDealerBikes: (minDealerBikes).toString(),
      ),
  ];
}
