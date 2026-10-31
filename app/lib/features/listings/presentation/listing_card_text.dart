import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/listing_card_preferences.dart';
import 'colour_text.dart';
import 'listing_dates_text.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

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
        language.messages.registeredOwnersListingCardText(
          owners: (owners).toString(),
        ),
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
