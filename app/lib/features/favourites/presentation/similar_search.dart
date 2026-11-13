import 'dart:math' as math;

import '../../listings/domain/entities/listing.dart';
import '../../listings/domain/entities/listing_filters.dart';
import '../../../core/localization/localizations.dart';

/// How far above a gone favourite's last price a similar bike may ask.
const similarPriceMargin = 0.10;

/// How much more mileage a similar bike may have: 30 %, at least 3 000 km.
const similarMileageShare = 0.30;
const similarMileageMinimum = 3000;

/// The search that finds a bike like a favourite that left the market
/// (N.84): the same model, a year either side, at most 10 % dearer than its
/// last price (rounded up to 250 €) and with up to 30 % more km (at least
/// 3 000 more, rounded up to 1 000). Null for a live ad, or one whose model
/// isn't in the catalog: there would be nothing to search by.
ListingFilters? similarSearchFilters(Listing listing) {
  final model = listing.motorcycleId;
  if (listing.isLive || model == null) return null;
  final year = listing.year;
  final price = listing.askingPrice;
  final mileage = listing.mileage;
  return ListingFilters(
    motorcycleIds: [model],
    minYear: year == null ? null : year - 1,
    maxYear: year == null ? null : year + 1,
    maxPrice: price == null
        ? null
        : _roundUp((price * (1 + similarPriceMargin)).round(), 250).toDouble(),
    maxMileage: mileage == null
        ? null
        : _roundUp(
            mileage +
                math.max(
                  (mileage * similarMileageShare).round(),
                  similarMileageMinimum,
                ),
            1000,
          ),
  );
}

/// The suggested name: "Parecida com Honda CB650R 2021".
String similarSearchName(
  Listing listing, {
  AppLanguage language = .portuguese,
}) => language.messages.similarSearchName(
  bike: [
    listing.brand,
    listing.model,
    if (listing.year != null) '${listing.year}',
  ].join(' '),
);

int _roundUp(int value, int step) => (value / step).ceil() * step;
