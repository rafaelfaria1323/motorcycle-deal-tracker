import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'colour_text.dart';
import 'listing_dates_text.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

/// The line under the price: "2022 · 12 300 km · Lisboa · Profissional".
/// Missing facts are left out rather than shown as dashes.
String keyFactsLine(
  Listing listing, {
  AppLanguage language = AppLanguage.portuguese,
}) => [
  if (listing.year != null) '${listing.year}',
  if (listing.mileage != null)
    Formatters.mileage(listing.mileage, language: language),
  ?placeText(listing, language: language),
  if (listing.sellerType != SellerType.unknown)
    listing.sellerType.label(language: language),
].join(' · ');

/// "a 45 km" from the person's home.
String distanceText(int km, {AppLanguage language = AppLanguage.portuguese}) =>
    language.messages.away(mileage: Formatters.mileage(km, language: language));

/// "Matosinhos, a 8 km"; the place alone without a distance; null without
/// a place.
String? placeText(
  Listing listing, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final location = listing.location?.trim();
  if (location == null || location.isEmpty) return null;
  final km = listing.distanceKm;
  return km == null
      ? location
      : '$location, ${distanceText(km, language: language)}';
}

/// "3 / 12" on the photo gallery.
String photoCounterText(int index, int count) => '${index + 1} / $count';

/// The button to the seller's ad: "Ver no OLX".
String originalLinkLabel(
  String source, {
  AppLanguage language = AppLanguage.portuguese,
}) => switch (source) {
  'standvirtual' || 'olx' => language.messages.viewOnSite(
    site: sourceLabel(source, language: language),
  ),
  _ => language.messages.viewOriginalListing,
};

/// One row of a facts card: a label and its value.
typedef Fact = (String label, String value);

/// "A mota": year and mileage always (a dash when unknown), the rest only
/// when the ad says. A mileage read from the description says so, and a
/// colour among the person's favourites.
List<Fact> bikeFacts(
  Listing listing, {
  AppLanguage language = AppLanguage.portuguese,
}) => [
  (language.messages.yearCompareText, listing.year?.toString() ?? '—'),
  (
    language.messages.mileage,
    listing.mileageFromText
        ? language.messages.readFromDescription(
            mileage: Formatters.mileage(listing.mileage, language: language),
          )
        : Formatters.mileage(listing.mileage, language: language),
  ),
  if (colourLabel(listing.colour, language: language) case final colour?)
    (
      language.messages.colourListingDetailText,
      listing.myColour
          ? language.messages.oneOfYourPreferredColours(colour: colour)
          : colour,
    ),
  if (listing.registrations case final owners?)
    (language.messages.registeredOwners, '$owners'),
  if (listing.serviceBook case final book?)
    (
      language.messages.serviceBook,
      book ? language.messages.complete : language.messages.no,
    ),
  if (listing.origin case final origin?)
    (
      language.messages.origin,
      origin == 'national'
          ? language.messages.portugueseMarket
          : language.messages.imported,
    ),
  if (listing.warrantyUntil case final until?)
    (
      language.messages.factoryWarrantyUntilListingDetailText,
      Formatters.date(until),
    ),
  if (listing.dealerWarrantyMonths case final months?)
    (
      language.messages.sellerWarranty,
      language.messages.months(months: (months).toString()),
    ),
];

/// "O anúncio": where and who, the site, its dates and the status.
List<Fact> adFacts(
  Listing listing, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) => [
  (
    language.messages.locationCompareText,
    placeText(listing, language: language) ?? '—',
  ),
  (language.messages.seller, listing.sellerName ?? '—'),
  (language.messages.sellerType, listing.sellerType.label(language: language)),
  (language.messages.source, sourceLabel(listing.source, language: language)),
  if (listing.publishedAt case final published?)
    (
      language.messages.publishedListingDetailText,
      dateWithAge(published, now: now, language: language),
    ),
  if (renewalToShow(listing) case final renewed?)
    (
      language.messages.renewedOnSiteListingDetailText,
      dateWithAge(renewed, now: now, language: language),
    ),
  (
    language.messages.statusListingDetailText,
    listing.status.label(language: language),
  ),
];
