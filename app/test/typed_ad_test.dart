import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/negotiation_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/offer_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/seller_message_text.dart';
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
}) => typedAdListing(
  motorcycleId: 'mt07',
  name: name,
  year: 2021,
  mileage: mileage,
  price: price,
  sellerType: seller,
  value: value,
  condition: condition,
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

    test('below 3 comparables there is no estimate and no offer', () {
      final listing = _typed(
        value: const BikeValue(comparableCount: 2, estimate: 7000),
      );
      expect(listing.scoreBreakdown, {'market_listing_count': 2});
      expect(listing.marketPosition, isNull);
      expect(suggestOffer(listing), isNull);
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
