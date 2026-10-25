import 'package:equatable/equatable.dart';

enum ListingCardField {
  source('source'),
  dealScore('deal_score'),
  priceChange('price_change'),
  year('year'),
  mileage('mileage'),
  location('location'),
  preferredColour('preferred_colour'),
  riskScore('risk_score'),
  sellerType('seller_type'),
  firstSeenAt('first_seen_at');

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
    ListingCardField.year,
    ListingCardField.mileage,
    ListingCardField.location,
    ListingCardField.preferredColour,
  };

  static const additionalFields = {
    ListingCardField.riskScore,
    ListingCardField.sellerType,
    ListingCardField.firstSeenAt,
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
