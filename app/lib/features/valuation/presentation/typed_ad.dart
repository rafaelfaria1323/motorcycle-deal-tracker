import '../../listings/domain/entities/catalog_model.dart';
import '../../market/domain/repositories/market_behaviour_repository.dart'
    show TypedAdScore;
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
/// what the ad already says is not asked again in the message. The
/// model's new-bike price ([catalog]: the dealers' new bikes, else the
/// list price, as on a stored ad's page) is what a nearly new bike is
/// compared with.
///
/// With its [score] (N.107, `typed_ad_score`: what a stored ad with the
/// same facts would get) the listing carries the Deal Score, the Risk
/// Score and their breakdown, and the offer is worked out from that
/// breakdown as on a stored ad (against the damaged value for an
/// accident); without it, from the value adjusted for the condition.
///
/// [daysListed] (how long the site says it has been on sale) dates its
/// publication that many days before [today], and [initialPrice] (its
/// price before a drop, when the site shows one above the price) is its
/// first price: the seller's urgency, the offer and the arguments read
/// them as a stored ad's dates and drops.
Listing typedAdListing({
  required String motorcycleId,
  required String name,
  required int year,
  required int? mileage,
  required double price,
  required SellerType sellerType,
  required BikeValue value,
  BikeCondition condition = const BikeCondition(),
  CatalogModel? catalog,
  TypedAdScore? score,
  String? description,
  int? daysListed,
  double? initialPrice,
  DateTime? today,
}) {
  final fromAds = catalog?.newPriceFromAds;
  final estimate = conditionEstimate(value, condition);
  final breakdown = score?.breakdown;
  final reasons = [
    for (final reason in breakdown?['risk_reasons'] as List? ?? const [])
      '$reason',
  ];
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
    initialPrice: initialPrice != null && initialPrice > price
        ? initialPrice
        : null,
    publishedAt: daysListed == null
        ? null
        : (today ?? DateTime.now()).subtract(Duration(days: daysListed)),
    description: switch (description?.trim()) {
      final text? when text.isNotEmpty => text,
      _ => null,
    },
    dealScore: score?.dealScore,
    riskScore: score?.riskScore,
    riskReasons: reasons,
    hasFirstOwnerSignal: reasons.contains('first_owner'),
    scoreBreakdown:
        breakdown ??
        {
          'market_price': ?estimate,
          'market_listing_count': value.comparableCount,
        },
    marketPosition: breakdown != null
        ? typedMarketPosition(breakdown)
        : estimate == null || price < minRealPrice
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
    newPrice: fromAds ?? catalog?.newPrice,
    newPriceCheckedAt: fromAds == null ? catalog?.newPriceCheckedAt : null,
    newPriceAdCount: fromAds == null ? null : catalog?.newPriceAdCount,
  );
}

/// The market position of a scored typed ad, as the computed field
/// `market_position` reads a stored ad's breakdown: against the legalised
/// or the damaged value when there is one; null below 3 comparables.
double? typedMarketPosition(Map<String, dynamic> breakdown) {
  final count = (breakdown['market_listing_count'] as num?)?.toInt() ?? 0;
  if (count < 3) return null;
  final legalised = breakdown['legalisation_cost'] != null
      ? breakdown['pct_below_legalised_value'] as num?
      : null;
  final damaged = breakdown['damage_allowance'] != null
      ? breakdown['pct_below_damaged_value'] as num?
      : null;
  final pct = legalised ?? damaged ?? breakdown['pct_below_market'] as num?;
  return pct == null ? null : (pct * 10).round() / 10;
}
