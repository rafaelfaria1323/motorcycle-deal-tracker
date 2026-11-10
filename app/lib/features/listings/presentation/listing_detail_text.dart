import '../../../app/router/app_routes.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/platform/app_build.dart';
import '../domain/entities/listing.dart';
import 'colour_text.dart';
import 'listing_dates_text.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

/// The chips under the ad's name, as Stitch's ad page: the year, the
/// mileage and the model's engine size, each only when known.
List<String> heroSpecs(Listing listing, {AppLanguage language = .portuguese}) =>
    [
      if (listing.year != null) '${listing.year}',
      if (listing.mileage != null)
        Formatters.mileage(listing.mileage, language: language),
      if (listing.engineCc case final cc?) '$cc cc',
    ];

/// Who sells: "Particular", "Stand: Motos Lopes" (the dealer's name when
/// the ad gives it), "Stand"; null when unknown.
String? sellerText(Listing listing, {AppLanguage language = .portuguese}) {
  final name = listing.sellerName?.trim();
  return switch (listing.sellerType) {
    .unknown => null,
    .dealer when name != null && name.isNotEmpty => language.messages.dealer(
      seller: name,
    ),
    final type => type.label(language: language),
  };
}

/// How far the price is from the value under it, in euros, to the
/// nearest 10 € as that value ("860 €"); null without a position.
String? marketGapText(Listing listing, {AppLanguage language = .portuguese}) {
  final price = listing.askingPrice;
  final pct = listing.marketPosition;
  if (price == null || pct == null || pct >= 100) return null;
  final value = price / (1 - pct / 100);
  final gap = ((value - price).abs() / 10).round() * 10.0;
  if (gap == 0) return null;
  return Formatters.price(gap, language: language);
}

/// "Comparado com 14 anúncios": the comparables the estimate came from
/// (`market_listing_count`); null when the breakdown doesn't say.
String? comparablesText(Listing listing, {AppLanguage language = .portuguese}) {
  final count = (listing.scoreBreakdown?['market_listing_count'] as num?)
      ?.toInt();
  if (count == null || count <= 0) return null;
  return language.messages.comparedWithListings(count: count);
}

/// "a 45 km" from the person's home.
String distanceText(int km, {AppLanguage language = .portuguese}) =>
    language.messages.away(mileage: Formatters.mileage(km, language: language));

/// "Matosinhos, a 8 km"; the place alone without a distance; null without
/// a place.
String? placeText(Listing listing, {AppLanguage language = .portuguese}) {
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
String originalLinkLabel(String source, {AppLanguage language = .portuguese}) =>
    switch (source) {
      'standvirtual' || 'olx' => language.messages.viewOnSite(
        site: sourceLabel(source, language: language),
      ),
      _ => language.messages.viewOriginalListing,
    };

/// The ad's own address when it is a web one; null otherwise. It comes
/// from the site, so nothing else is opened or shared.
Uri? adAddress(Listing listing) {
  final uri = Uri.tryParse(listing.url);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
      ? uri
      : null;
}

/// The second line of the page's bar once its own heading has scrolled
/// away, under the bike's name: "2023 · 6 400 €".
String compactTitleLine(
  Listing listing, {
  AppLanguage language = .portuguese,
}) => [
  if (listing.year != null) '${listing.year}',
  if (listing.price != null) listing.priceLabel(language: language),
].join(' · ');

/// The app's page of the listing [id] at [origin], as notifications open it.
String listingLink(String origin, String id) =>
    '$origin/#${AppRoutes.listingDetail(id)}';

/// What sharing an ad sends before the app's link: the bike, its mileage
/// and price, and the seller's ad when it has a web address.
String listingShareText(
  Listing listing, {
  AppLanguage language = .portuguese,
}) => [
  [
    listing.nameAndYear,
    if (listing.mileage != null)
      Formatters.mileage(listing.mileage, language: language),
    if (listing.price != null) listing.priceLabel(language: language),
  ].join(' · '),
  if (adAddress(listing) case final ad?)
    language.messages.originalAdAddress(url: '$ad'),
  language.messages.onApp(app: appName),
].join('\n');

/// One row of a facts card: a label and its value.
typedef Fact = (String label, String value);

/// "A mota": year and mileage always (a dash when unknown), the rest only
/// when the ad says. A mileage read from the description says so, and a
/// colour among the person's favourites.
List<Fact> bikeFacts(Listing listing, {AppLanguage language = .portuguese}) => [
  (language.messages.yearLabel, listing.year?.toString() ?? '—'),
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
      language.messages.colourLabel,
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
    (language.messages.factoryWarrantyUntilLabel, Formatters.date(until)),
  if (listing.dealerWarrantyMonths case final months?)
    (
      language.messages.sellerWarranty,
      language.messages.months(months: months),
    ),
];

/// "O anúncio": where and who, the site, its dates and the status.
List<Fact> adFacts(
  Listing listing, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) => [
  (
    language.messages.locationLabel,
    placeText(listing, language: language) ?? '—',
  ),
  (language.messages.seller, listing.sellerName ?? '—'),
  (language.messages.sellerType, listing.sellerType.label(language: language)),
  (language.messages.source, sourceLabel(listing.source, language: language)),
  if (listing.publishedAt case final published?)
    (
      language.messages.publishedLabel,
      dateWithAge(published, now: now, language: language),
    ),
  if (renewalToShow(listing) case final renewed?)
    (
      language.messages.renewedOnSiteLabel,
      dateWithAge(renewed, now: now, language: language),
    ),
  (language.messages.statusLabel, listing.status.label(language: language)),
];
