import 'package:equatable/equatable.dart';

enum ListingCardField {
  source('source'),
  dealScore('deal_score'),
  priceChange('price_change'),
  marketPosition('market_position'),
  year('year'),
  mileage('mileage'),
  location('location'),
  preferredColour('preferred_colour'),
  riskScore('risk_score'),
  sellerType('seller_type'),
  firstSeenAt('first_seen_at'),
  colour('colour'),
  registrations('registrations'),
  serviceBook('service_book'),
  origin('origin'),
  warrantyUntil('warranty_until'),
  dealerWarrantyMonths('dealer_warranty_months'),
  sellerName('seller_name'),
  publishedAt('published_at'),
  siteRefreshedAt('site_refreshed_at'),
  status('status');

  const ListingCardField(this.code);

  final String code;
}

class ListingCardPreferences extends Equatable {
  ListingCardPreferences(Iterable<ListingCardField> fields)
    : fields = Set.unmodifiable(fields);

  const ListingCardPreferences.defaults() : fields = defaultFields;

  static const defaultFields = {
    ListingCardField.source,
    ListingCardField.dealScore,
    ListingCardField.priceChange,
    ListingCardField.marketPosition,
    ListingCardField.year,
    ListingCardField.mileage,
    ListingCardField.location,
    ListingCardField.preferredColour,
  };

  static const additionalFields = {
    ListingCardField.riskScore,
    ListingCardField.sellerType,
    ListingCardField.firstSeenAt,
    ListingCardField.colour,
    ListingCardField.registrations,
    ListingCardField.serviceBook,
    ListingCardField.origin,
    ListingCardField.warrantyUntil,
    ListingCardField.dealerWarrantyMonths,
    ListingCardField.sellerName,
    ListingCardField.publishedAt,
    ListingCardField.siteRefreshedAt,
    ListingCardField.status,
  };

  final Set<ListingCardField> fields;

  bool shows(ListingCardField field) => fields.contains(field);

  ListingCardPreferences withField(ListingCardField field, bool visible) =>
      ListingCardPreferences({
        for (final current in fields)
          if (current != field) current,
        if (visible) field,
      });

  @override
  List<Object?> get props => [fields];
}
