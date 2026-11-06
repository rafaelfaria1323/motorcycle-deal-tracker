import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/listing_card_preferences.dart';
import 'colour_text.dart';
import 'listing_dates_text.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

/// Where the price sits against the estimated value, whole percent:
/// "8 % abaixo do mercado", "5 % acima do mercado", "No valor de mercado";
/// null when unknown. [pct] is below (+) or above (−) the estimate, as
/// `Listing.marketPosition` (cards) and the comparison read it.
String? marketPositionText(double? pct, {AppLanguage language = .portuguese}) {
  if (pct == null) return null;
  final rounded = pct.round();
  if (rounded == 0) return language.messages.atMarketValue;
  return rounded > 0
      ? language.messages.belowMarketValue(rounded: '$rounded')
      : language.messages.aboveMarketValue(percent: '${-rounded}');
}

/// "2023 · 12 000 km" under the card's title: the year when shown and
/// known, the mileage when shown ("—" when unknown); null with neither.
String? yearAndMileageText(
  Listing listing,
  ListingCardPreferences preferences, {
  AppLanguage language = .portuguese,
}) {
  final parts = [
    if (preferences.shows(ListingCardField.year) && listing.year != null)
      '${listing.year}',
    if (preferences.shows(ListingCardField.mileage))
      Formatters.mileage(listing.mileage, language: language),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The risk reasons serious enough to warn of on the photo, strongest
/// first; the rest stay in the ad's Avaliação.
const _cardWarningCodes = [
  'not_legalised_outside_eu',
  'not_legalised',
  'possible_accident',
  'needs_repair',
  'photos_reused',
  'text_year_mismatch',
  'text_mileage_mismatch',
  'text_origin_mismatch',
  'text_service_book_mismatch',
  'a2_limited',
];

/// Short warnings for the card's photo ("Por legalizar", "Acidente
/// referido"), at most [max], each said once.
List<String> cardWarnings(
  List<String> reasons, {
  int max = 2,
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  final present = reasons.toSet();
  return <String>{
    for (final code in _cardWarningCodes)
      if (present.contains(code))
        switch (code) {
          'not_legalised' ||
          'not_legalised_outside_eu' => messages.cardWarningNotLegalised,
          'possible_accident' => messages.cardWarningAccident,
          'needs_repair' => messages.cardWarningRepair,
          'photos_reused' => messages.cardWarningPhotosReused,
          'a2_limited' => messages.cardWarningA2,
          _ => messages.cardWarningContradiction,
        },
  }.take(max).toList();
}

List<(ListingCardField, String)> listingCardExtraFacts(
  Listing listing,
  ListingCardPreferences preferences, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) => [
  if (preferences.shows(ListingCardField.riskScore) &&
      listing.riskScore != null)
    (
      ListingCardField.riskScore,
      language.messages.riskScore100(riskScore: listing.riskScore.toString()),
    ),
  if (preferences.shows(ListingCardField.sellerType) &&
      listing.sellerType != .unknown)
    (ListingCardField.sellerType, listing.sellerType.label(language: language)),
  if (preferences.shows(ListingCardField.firstSeenAt) &&
      listing.firstSeenAt != null)
    (
      ListingCardField.firstSeenAt,
      language.messages.found(
        daysago: Formatters.daysAgo(
          listing.firstSeenAt!,
          now: now,
          language: language,
        ),
      ),
    ),
  if (preferences.shows(ListingCardField.colour))
    if (colourLabel(listing.colour, language: language) case final colour?)
      (ListingCardField.colour, language.messages.colour(colour: colour)),
  if (preferences.shows(ListingCardField.registrations))
    if (listing.registrations == 1)
      (ListingCardField.registrations, language.messages.firstOwner)
    else if (listing.registrations case final owners?)
      (
        ListingCardField.registrations,
        language.messages.registeredOwnersCount(owners: (owners).toString()),
      )
    else if (listing.hasFirstOwnerSignal)
      (
        ListingCardField.registrations,
        language.messages.firstOwnerStatedInListing,
      ),
  if (preferences.shows(ListingCardField.serviceBook))
    if (listing.serviceBook case final book?)
      (
        ListingCardField.serviceBook,
        book
            ? language.messages.completeServiceBook
            : language.messages.noCompleteServiceBook,
      ),
  if (preferences.shows(ListingCardField.origin))
    if (listing.origin == 'national')
      (ListingCardField.origin, language.messages.portugueseMarket)
    else if (listing.origin == 'imported')
      (ListingCardField.origin, language.messages.imported),
  if (preferences.shows(ListingCardField.warrantyUntil))
    if (listing.warrantyUntil case final until?)
      (
        ListingCardField.warrantyUntil,
        language.messages.factoryWarrantyUntil(date: Formatters.date(until)),
      ),
  if (preferences.shows(ListingCardField.dealerWarrantyMonths))
    if (listing.dealerWarrantyMonths case final months?)
      (
        ListingCardField.dealerWarrantyMonths,
        language.messages.sellerWarrantyMonths(months: months),
      ),
  if (preferences.shows(ListingCardField.sellerName) &&
      listing.sellerType == .dealer)
    if (listing.sellerName?.trim() case final seller?)
      if (seller.isNotEmpty)
        (ListingCardField.sellerName, language.messages.dealer(seller: seller)),
  if (preferences.shows(ListingCardField.publishedAt))
    if (listing.publishedAt case final published?)
      (
        ListingCardField.publishedAt,
        language.messages.publishedOn(
          date: dateWithAge(published, now: now, language: language),
        ),
      ),
  if (preferences.shows(ListingCardField.siteRefreshedAt))
    if (renewalToShow(listing) case final renewed?)
      (
        ListingCardField.siteRefreshedAt,
        language.messages.renewedOnSite(
          date: dateWithAge(renewed, now: now, language: language),
        ),
      ),
  if (preferences.shows(ListingCardField.status) && listing.status != .unknown)
    (
      ListingCardField.status,
      language.messages.status(label: listing.status.label(language: language)),
    ),
];
