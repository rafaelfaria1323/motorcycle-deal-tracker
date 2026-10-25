import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/listing_card_preferences.dart';
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
];
