import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/listing_card_preferences.dart';
import 'colour_text.dart';
import 'listing_dates_text.dart';
import 'listing_labels.dart';

List<(ListingCardField, String)> listingCardExtraFacts(
  Listing listing,
  ListingCardPreferences preferences, {
  DateTime? now,
}) => [
  if (preferences.shows(ListingCardField.riskScore) &&
      listing.riskScore != null)
    (ListingCardField.riskScore, 'Risk Score: ${listing.riskScore}/100'),
  if (preferences.shows(ListingCardField.sellerType) &&
      listing.sellerType != SellerType.unknown)
    (ListingCardField.sellerType, listing.sellerType.label),
  if (preferences.shows(ListingCardField.firstSeenAt) &&
      listing.firstSeenAt != null)
    (
      ListingCardField.firstSeenAt,
      'Encontrado ${Formatters.daysAgo(listing.firstSeenAt!, now: now)}',
    ),
  if (preferences.shows(ListingCardField.colour))
    if (colourLabel(listing.colour) case final colour?)
      (ListingCardField.colour, 'Cor: $colour'),
  if (preferences.shows(ListingCardField.registrations))
    if (listing.registrations == 1)
      (ListingCardField.registrations, 'Primeiro dono')
    else if (listing.registrations case final owners?)
      (ListingCardField.registrations, '$owners registos (donos)')
    else if (listing.hasFirstOwnerSignal)
      (ListingCardField.registrations, 'Primeiro dono (indicado no anúncio)'),
  if (preferences.shows(ListingCardField.serviceBook))
    if (listing.serviceBook case final book?)
      (
        ListingCardField.serviceBook,
        book ? 'Livro de revisões completo' : 'Sem livro de revisões completo',
      ),
  if (preferences.shows(ListingCardField.origin))
    if (listing.origin == 'national')
      (ListingCardField.origin, 'Nacional')
    else if (listing.origin == 'imported')
      (ListingCardField.origin, 'Importada'),
  if (preferences.shows(ListingCardField.warrantyUntil))
    if (listing.warrantyUntil case final until?)
      (
        ListingCardField.warrantyUntil,
        'Garantia de fábrica até ${Formatters.date(until)}',
      ),
  if (preferences.shows(ListingCardField.dealerWarrantyMonths))
    if (listing.dealerWarrantyMonths case final months?)
      (
        ListingCardField.dealerWarrantyMonths,
        '$months ${months == 1 ? 'mês' : 'meses'} de garantia do vendedor',
      ),
  if (preferences.shows(ListingCardField.sellerName) &&
      listing.sellerType == SellerType.dealer)
    if (listing.sellerName?.trim() case final seller?)
      if (seller.isNotEmpty) (ListingCardField.sellerName, 'Stand: $seller'),
  if (preferences.shows(ListingCardField.publishedAt))
    if (listing.publishedAt case final published?)
      (
        ListingCardField.publishedAt,
        'Publicado: ${dateWithAge(published, now: now)}',
      ),
  if (preferences.shows(ListingCardField.siteRefreshedAt))
    if (renewalToShow(listing) case final renewed?)
      (
        ListingCardField.siteRefreshedAt,
        'Renovado no site: ${dateWithAge(renewed, now: now)}',
      ),
  if (preferences.shows(ListingCardField.status) &&
      listing.status != ListingStatus.unknown)
    (ListingCardField.status, 'Estado: ${listing.status.label}'),
];
