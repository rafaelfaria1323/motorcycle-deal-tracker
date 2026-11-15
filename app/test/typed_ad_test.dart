import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/catalog_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/negotiation_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/new_price_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/offer_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/seller_message_text.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/repositories/market_behaviour_repository.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_condition.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_value.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/bike_value_text.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/typed_ad.dart';

const _value = BikeValue(
  comparableCount: 12,
  estimate: 7000,
  low: 6500,
  high: 7600,
);

Listing _typed({
  String name = 'Yamaha MT-07',
  int? mileage = 18000,
  double price = 7400,
  SellerType seller = SellerType.private,
  BikeValue value = _value,
  BikeCondition condition = const BikeCondition(),
  CatalogModel? catalog,
  TypedAdScore? score,
  String? description,
}) => typedAdListing(
  motorcycleId: 'mt07',
  name: name,
  year: 2021,
  mileage: mileage,
  price: price,
  sellerType: seller,
  value: value,
  condition: condition,
  catalog: catalog,
  score: score,
  description: description,
);

CatalogModel _catalog({
  double? listPrice,
  DateTime? checkedAt,
  double? fromAds,
  int? adCount,
}) => CatalogModel(
  id: 'mt07',
  brand: 'Yamaha',
  model: 'MT-07',
  minYear: 2018,
  isTracked: true,
  newPrice: listPrice,
  newPriceCheckedAt: checkedAt,
  newPriceFromAds: fromAds,
  newPriceAdCount: adCount,
);

void main() {
  const language = AppLanguage.portuguese;

  group('typedAdListing', () {
    test('the typed facts, with the value as its estimate', () {
      final listing = _typed();
      expect(listing.id, typedAdId);
      expect(listing.isTyped, isTrue);
      expect(listing.isLive, isTrue);
      expect(listing.name, 'Yamaha MT-07');
      expect(listing.brand, 'Yamaha');
      expect(listing.model, 'MT-07');
      expect(listing.motorcycleId, 'mt07');
      expect(listing.year, 2021);
      expect(listing.mileage, 18000);
      expect(listing.askingPrice, 7400);
      expect(listing.sellerType, SellerType.private);
      expect(listing.scoreBreakdown, {
        'market_price': 7000,
        'market_listing_count': 12,
      });
      // 400 € above 7 000 €.
      expect(listing.marketPosition, closeTo(-5.714, 0.001));
      expect(listing.registrations, isNull);
      expect(listing.serviceBook, isNull);
    });

    test('a one-word name keeps it whole', () {
      final listing = _typed(name: 'Vespa');
      expect(listing.brand, 'Vespa');
      expect(listing.model, '');
    });

    test('what the ad says of the bike adjusts the estimate', () {
      const condition = BikeCondition(
        damage: BikeDamage.accident,
        owners: BikeOwners.one,
        serviceBook: BikeServiceBook.yes,
      );
      final listing = _typed(condition: condition);
      expect(
        listing.scoreBreakdown!['market_price'],
        conditionEstimate(_value, condition),
      );
      expect(listing.scoreBreakdown!['market_price'], lessThan(7000));
      expect(listing.registrations, 1);
      expect(listing.serviceBook, isTrue);
      expect(
        _typed(
          condition: const BikeCondition(
            owners: BikeOwners.threeOrMore,
            serviceBook: BikeServiceBook.no,
          ),
        ),
        isA<Listing>()
            .having((l) => l.registrations, 'registrations', 3)
            .having((l) => l.serviceBook, 'serviceBook', isFalse),
      );
      expect(
        _typed(condition: const BikeCondition(owners: BikeOwners.two))
            .registrations,
        2,
      );
    });

    test('takes the model\'s new-bike price as a stored ad\'s page does', () {
      expect(_typed().newPrice, isNull);
      expect(newPriceLines(_typed()), isEmpty);

      final checked = DateTime(2026, 10, 1);
      final listed = _typed(
        catalog: _catalog(listPrice: 8250, checkedAt: checked),
      );
      expect(listed.newPrice, 8250);
      expect(listed.newPriceCheckedAt, checked);
      expect(listed.newPriceAdCount, isNull);

      // The dealers' new bikes win over the typed list price.
      final fromAds = _typed(
        catalog: _catalog(
          listPrice: 8250,
          checkedAt: checked,
          fromAds: 8400,
          adCount: 4,
        ),
      );
      expect(fromAds.newPrice, 8400);
      expect(fromAds.newPriceAdCount, 4);
      expect(fromAds.newPriceCheckedAt, isNull);
      expect(
        newPriceLines(_typed(price: 7500, catalog: _catalog(listPrice: 8250))),
        contains(startsWith('Menos de 10 % abaixo de uma nova')),
      );
    });

    test('below 3 comparables there is no estimate and no offer', () {
      final listing = _typed(
        value: const BikeValue(comparableCount: 2, estimate: 7000),
      );
      expect(listing.scoreBreakdown, {'market_listing_count': 2});
      expect(listing.marketPosition, isNull);
      expect(suggestOffer(listing), isNull);
    });
  });

  group('the scored typed ad (N.107)', () {
    const scored = (
      dealScore: 81,
      riskScore: 12,
      breakdown: <String, dynamic>{
        'market_price': 8000,
        'market_listing_count': 7,
        'pct_below_market': 12.5,
        'risk_reasons': ['first_owner', 'cosmetic_damage'],
        'extras': ['quickshifter'],
      },
    );

    test('carries the scores and the breakdown of a stored ad', () {
      final listing = _typed(
        price: 7000,
        score: scored,
        description: '  Vendo a minha MT-07  ',
      );
      expect(listing.dealScore, 81);
      expect(listing.riskScore, 12);
      expect(listing.scoreBreakdown, scored.breakdown);
      expect(listing.riskReasons, ['first_owner', 'cosmetic_damage']);
      expect(listing.hasFirstOwnerSignal, isTrue);
      expect(listing.marketPosition, 12.5);
      expect(listing.description, 'Vendo a minha MT-07');
      expect(ScoreExplainer.explain(listing), isNotNull);
      // The offer comes from the market of the breakdown.
      expect(suggestOffer(listing), isNotNull);
    });

    test('without a score it keeps the value as its estimate', () {
      final listing = _typed(description: '   ');
      expect(listing.dealScore, isNull);
      expect(listing.riskReasons, isEmpty);
      expect(listing.description, isNull);
      expect(listing.scoreBreakdown!['market_price'], 7000);
    });

    test('the market position follows the damaged or legalised value', () {
      expect(
        typedMarketPosition({
          'market_listing_count': 5,
          'pct_below_market': 10,
          'damage_allowance': 0.15,
          'pct_below_damaged_value': -5.04,
        }),
        -5.0,
      );
      expect(
        typedMarketPosition({
          'market_listing_count': 5,
          'pct_below_market': 10,
          'pct_below_damaged_value': -5,
          'legalisation_cost': 400,
          'pct_below_legalised_value': -12.36,
        }),
        -12.4,
      );
      // A damaged value without its allowance is not used.
      expect(
        typedMarketPosition({
          'market_listing_count': 3,
          'pct_below_market': 2.5,
          'pct_below_damaged_value': -5,
        }),
        2.5,
      );
      expect(
        typedMarketPosition({
          'market_listing_count': 2,
          'pct_below_market': 10,
        }),
        isNull,
      );
    });
  });

  group('the typed ad in Negociar', () {
    test('gets an offer below its price', () {
      final offer = suggestOffer(_typed());
      expect(offer, isNotNull);
      expect(offer!.opening, lessThan(7400));
      expect(offer.ceiling, lessThanOrEqualTo(7400));
    });

    test('the message asks only what the ad leaves open, naming no site', () {
      final open = sellerMessage(_typed(mileage: null));
      expect(open, contains(language.messages.whatIsItsMileage));
      expect(open, contains(language.messages.howManyOwnersHasItHad));
      expect(open, contains(language.messages.isItRegisteredInYourName));
      expect(open, contains(language.messages.isThereReservationOfOwnership));
      expect(open, isNot(contains('OLX')));
      expect(open, isNot(contains('Standvirtual')));

      final known = sellerMessage(
        _typed(
          seller: SellerType.dealer,
          condition: const BikeCondition(
            owners: BikeOwners.one,
            serviceBook: BikeServiceBook.yes,
          ),
        ),
      );
      expect(known, isNot(contains(language.messages.whatIsItsMileage)));
      expect(known, isNot(contains(language.messages.howManyOwnersHasItHad)));
      expect(
        known,
        isNot(contains(language.messages.doesItHaveServiceBookWithItsServices)),
      );
      expect(
        known,
        isNot(contains(language.messages.isItRegisteredInYourName)),
      );
      expect(
        known,
        isNot(contains(language.messages.isThereReservationOfOwnership)),
      );
    });

    test('its comparison holds the three cheapest stored ads', () {
      Listing stored(String id, double price) => Listing(
        id: id,
        source: 'olx',
        url: 'https://example.com/$id',
        brand: 'Yamaha',
        model: 'MT-07',
        status: ListingStatus.active,
        sellerType: SellerType.private,
        images: const [],
        price: price,
      );
      expect(
        compareWithCheaper(_typed(), [
          stored('d', 7100),
          stored('b', 6600),
          stored('a', 6200),
          stored('c', 6900),
        ]),
        ['a', 'b', 'c'],
      );
    });
  });
}
