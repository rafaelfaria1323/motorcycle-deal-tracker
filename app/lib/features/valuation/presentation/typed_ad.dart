import '../../listings/domain/entities/listing.dart';
import '../domain/entities/bike_condition.dart';
import '../domain/entities/bike_value.dart';
import 'bike_value_text.dart';

/// The id of an ad typed by hand: a valid id no stored listing has, so the
/// cheaper ads' query (which leaves the ad itself out) still works.
const typedAdId = '00000000-0000-0000-0000-000000000000';

/// The ad typed in "Avaliar um anúncio" (N.105: one on Facebook
/// Marketplace or another site the collector doesn't read) as a listing,
/// so Negociar's offer, arguments and message to the seller work on it
/// as on a stored ad. Its estimate is the bike's [value] adjusted for
/// what the ad says of its [condition] (as "Quanto vale a minha mota");
/// what the ad already says is not asked again in the message.
Listing typedAdListing({
  required String motorcycleId,
  required String name,
  required int year,
  required int? mileage,
  required double price,
  required SellerType sellerType,
  required BikeValue value,
  BikeCondition condition = const BikeCondition(),
}) {
  final estimate = conditionEstimate(value, condition);
  final space = name.indexOf(' ');
  return Listing(
    id: typedAdId,
    source: typedAdSource,
    url: '',
    // `name` joins them again with the space.
    brand: space < 0 ? name : name.substring(0, space),
    model: space < 0 ? '' : name.substring(space + 1),
    status: ListingStatus.active,
    sellerType: sellerType,
    images: const [],
    motorcycleId: motorcycleId,
    year: year,
    mileage: mileage,
    price: price,
    scoreBreakdown: {
      'market_price': ?estimate,
      'market_listing_count': value.comparableCount,
    },
    marketPosition: estimate == null || price < minRealPrice
        ? null
        : (estimate - price) / estimate * 100,
    registrations: switch (condition.owners) {
      .unknown => null,
      .one => 1,
      .two => 2,
      .threeOrMore => 3,
    },
    serviceBook: switch (condition.serviceBook) {
      .unknown => null,
      .yes => true,
      .no => false,
    },
  );
}
