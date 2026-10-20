import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/offer_text.dart';

Listing _listing({
  double? price = 7000,
  double? estimate = 7000,
  SellerType sellerType = SellerType.private,
  double? initialPrice,
  int? riskScore,
  ListingStatus status = ListingStatus.active,
  String? duplicateOf,
  DateTime? publishedAt,
  DateTime? firstSeenAt,
  DateTime? relistedSince,
  String? relistedFrom,
}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://example.com/l1',
  brand: 'Yamaha',
  model: 'MT-07',
  status: status,
  sellerType: sellerType,
  images: const [],
  firstSeenAt: firstSeenAt,
  lastSeenAt: null,
  price: price,
  initialPrice: initialPrice ?? price,
  riskScore: riskScore,
  duplicateOf: duplicateOf,
  publishedAt: publishedAt,
  relistedSince: relistedSince,
  relistedFrom: relistedFrom,
  scoreBreakdown: estimate == null ? null : {'market_price': estimate},
);

MarketBehaviour _market({
  int goneCount = 10,
  int? medianDaysToGone = 30,
  int pricedCount = 20,
  int droppedCount = 0,
  double? medianDropPct,
}) => MarketBehaviour(
  liveCount: 20,
  goneCount: goneCount,
  pricedCount: pricedCount,
  droppedCount: droppedCount,
  medianDaysToGone: medianDaysToGone,
  medianDropPct: medianDropPct,
);

void main() {
  group('suggestOffer', () {
    test(
      'nothing without a price, an estimate, or for removed and repeats',
      () {
        expect(suggestOffer(_listing(price: null)), isNull);
        expect(suggestOffer(_listing(estimate: null)), isNull);
        expect(suggestOffer(_listing(estimate: 0)), isNull);
        expect(suggestOffer(_listing(status: ListingStatus.removed)), isNull);
        expect(suggestOffer(_listing(duplicateOf: 'l0')), isNull);
      },
    );

    test('a private seller at the estimate: start 6 % below', () {
      final offer = suggestOffer(_listing())!;
      expect(offer.ceiling, 7000);
      expect(offer.opening, 6550); // 6580 rounded down to 50 €
      expect(
        offer.headline,
        'Comece por ${Formatters.price(6550)} e não passe de '
        '${Formatters.price(7000)}.',
      );
      expect(
        offer.reasons.first,
        'O preço pedido está em linha com o valor estimado.',
      );
    });

    test('a dealer leaves less room', () {
      final offer = suggestOffer(_listing(sellerType: SellerType.dealer))!;
      expect(offer.opening, 6750); // 6790
      expect(offer.reasons[1], startsWith('Vendedor profissional'));
    });

    test('above the estimate, the estimate is the most to pay', () {
      final offer = suggestOffer(_listing(price: 8000, estimate: 7230))!;
      expect(offer.ceiling, 7200);
      expect(offer.opening, 6750); // 6768
      expect(offer.reasons.first, startsWith('O preço pedido está 11 % acima'));
    });

    test('below the estimate, says how far', () {
      final offer = suggestOffer(_listing(price: 6300, estimate: 7000))!;
      expect(offer.ceiling, 6300);
      expect(offer.reasons.first, contains('10 % abaixo do valor estimado'));
      // 6 % less the 10 % already given: the 1 % minimum.
      expect(offer.opening, 6200); // 6237
    });

    test('a fair price long on sale is not pushed far below its value', () {
      // Rafael's case: about 6 % under the estimate, on sale three times the
      // model's usual time, a model whose sellers often drop. Before: 15 %
      // off the asking price (6 800 €).
      final offer = suggestOffer(
        _listing(price: 8000, estimate: 8500),
        market: _market(droppedCount: 10, medianDropPct: 5),
        daysListed: 100,
      )!;
      expect(offer.ceiling, 8000);
      // 6 + 7 + 2.5 - 5.9 = 9.6 %: 7232, but never under 90 % of 8 500.
      expect(offer.opening, 7650);
    });

    test('long on sale against the model, and very long', () {
      final market = _market(medianDaysToGone: 30);
      final long = suggestOffer(_listing(), market: market, daysListed: 40)!;
      expect(long.opening, 6350); // 9 %: 6370
      expect(
        long.reasons.last,
        contains('mais do que o típico deste modelo (30 dias)'),
      );

      final veryLong = suggestOffer(
        _listing(),
        market: market,
        daysListed: 61,
      )!;
      expect(veryLong.opening, 6300); // 11 %, capped at 10: 6300
      expect(
        veryLong.reasons.last,
        'À venda há 61 dias, mais do dobro do típico deste modelo (30 dias): '
        'o vendedor pode aceitar uma proposta mais baixa.',
      );

      final longest = suggestOffer(_listing(), market: market, daysListed: 91)!;
      expect(longest.opening, 6300); // 13 %, capped at 10: 6300
      expect(longest.reasons.last, contains('mais do triplo do típico'));

      final atTypical = suggestOffer(
        _listing(),
        market: market,
        daysListed: 30,
      )!;
      expect(atTypical.opening, 6550);
    });

    test('without enough model data, 45 days is long', () {
      final few = _market(goneCount: 4);
      expect(
        suggestOffer(_listing(), market: few, daysListed: 45)!.opening,
        6550,
      );
      final offer = suggestOffer(_listing(), market: few, daysListed: 46)!;
      expect(offer.opening, 6350);
      expect(offer.reasons.last, contains('muito tempo'));
    });

    test('a relisted bike leaves more room', () {
      final offer = suggestOffer(_listing(relistedFrom: 'l0'))!;
      expect(offer.opening, 6400); // 8 %: 6440
      expect(offer.reasons.last, startsWith('Já foi anunciada antes'));
    });

    test('an earlier drop leaves less room', () {
      final offer = suggestOffer(_listing(price: 7000, initialPrice: 7500))!;
      expect(offer.opening, 6700); // 4 %: 6720
      expect(
        offer.reasons.last,
        'O vendedor já baixou o preço: há menos margem.',
      );
    });

    test('a model whose sellers often drop adds half the usual drop', () {
      final often = _market(droppedCount: 7, medianDropPct: 5);
      expect(
        suggestOffer(_listing(), market: often)!.opening,
        6400,
      ); // 8.5 %: 6405
      final big = _market(droppedCount: 7, medianDropPct: 12);
      expect(
        suggestOffer(_listing(), market: big)!.opening,
        6300,
      ); // 6 + 4 (half the drop, at most 4): 6300
      final rare = _market(droppedCount: 6, medianDropPct: 5);
      expect(suggestOffer(_listing(), market: rare)!.opening, 6550);
      final unknown = _market(
        pricedCount: 4,
        droppedCount: 4,
        medianDropPct: 5,
      );
      expect(suggestOffer(_listing(), market: unknown)!.opening, 6550);
    });

    test('a high risk adds room; everything together is capped at 10 %', () {
      expect(suggestOffer(_listing(riskScore: 50))!.opening, 6350); // 9 %: 6370
      expect(suggestOffer(_listing(riskScore: 49))!.opening, 6550);
      final all = suggestOffer(
        _listing(riskScore: 80),
        market: _market(droppedCount: 10, medianDropPct: 10),
        daysListed: 100,
      )!;
      expect(all.opening, 6300); // 18 % capped at 10: 6300
    });

    test('nothing for a price below one step', () {
      expect(suggestOffer(_listing(price: 40, estimate: 40)), isNull);
    });
  });

  group('daysOnSale', () {
    final now = DateTime(2026, 10, 20);
    test('from the first relist, the publication or the first sighting', () {
      expect(
        daysOnSale(
          _listing(
            relistedSince: DateTime(2026, 8, 1),
            publishedAt: DateTime(2026, 10, 1),
          ),
          now: now,
        ),
        80,
      );
      expect(
        daysOnSale(_listing(publishedAt: DateTime(2026, 10, 1)), now: now),
        19,
      );
      expect(
        daysOnSale(_listing(firstSeenAt: DateTime(2026, 10, 10)), now: now),
        10,
      );
      expect(daysOnSale(_listing(), now: now), isNull);
      expect(
        daysOnSale(_listing(publishedAt: DateTime(2026, 10, 21)), now: now),
        0,
      );
    });
  });
}
