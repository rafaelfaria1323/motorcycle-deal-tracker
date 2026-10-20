import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/negotiation_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/offer_text.dart';

final _today = DateTime(2026, 10, 20);

Listing _listing({
  double? price = 7000,
  double? initialPrice,
  int? year = 2022,
  int? mileage = 20000,
  int? engineCc = 689,
  SellerType sellerType = SellerType.private,
  Map<String, dynamic>? breakdown,
}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://example.com/l1',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: sellerType,
  images: const [],
  price: price,
  initialPrice: initialPrice ?? price,
  year: year,
  mileage: mileage,
  engineCc: engineCc,
  scoreBreakdown:
      breakdown ?? const {'market_price': 7000, 'market_listing_count': 8},
);

MarketBehaviour _market({int? medianDaysToGone = 30}) => MarketBehaviour(
  liveCount: 20,
  goneCount: 10,
  pricedCount: 20,
  droppedCount: 0,
  medianDaysToGone: medianDaysToGone,
);

const _issue = ChecklistEntry(mark: ChecklistMark.issue);

void main() {
  group('visit findings', () {
    test('problems with a price come off; papers and engine block', () {
      final findings = visitFindings({
        'tyres': _issue,
        'chain': _issue,
        'documents': _issue,
        'brakes': const ChecklistEntry(mark: ChecklistMark.ok),
        'keys': const ChecklistEntry(note: 'Só uma'),
      }, engineCc: 689);

      expect(findings.repairs.map((r) => (r.title, r.cost)), [
        ('Pneus', 300.0),
        ('Corrente e cremalheira', 200.0),
      ]);
      expect(findings.total, 500);
      expect(findings.blockers, ['Documento Único (DUA)']);
      expect(
        findings.repairsText,
        'pneus (~${Formatters.price(300)}), corrente e cremalheira '
        '(~${Formatters.price(200)})',
      );
      expect(visitFindings(const {}).isEmpty, isTrue);
    });

    test('repair prices follow the engine size', () {
      expect(
        visitFindings({'tyres': _issue}, engineCc: 998).total,
        greaterThan(visitFindings({'tyres': _issue}, engineCc: 125).total),
      );
    });

    test('the repairs come off the opening and the most to pay', () {
      final offer = suggestOffer(_listing())!;
      final after = afterVisit(
        offer,
        visitFindings({'tyres': _issue}, engineCc: 689),
      );
      expect(after.ceiling, offer.ceiling - 300);
      expect(after.opening, offer.opening - 300);
      expect(after.reasons.last, startsWith('Na visita: pneus'));
      expect(afterVisit(offer, const VisitFindings()), same(offer));
    });

    test('the opening stays below the most to pay after a big repair', () {
      const offer = OfferSuggestion(opening: 900, ceiling: 1000, reasons: []);
      final after = offer.lowerBy(950, 'x');
      expect(after.ceiling, offerStep);
      expect(after.opening, lessThanOrEqualTo(after.ceiling));
    });
  });

  group('arguments', () {
    List<String> argue(
      Listing listing, {
      MarketBehaviour? market,
      int? days,
      List<Listing> cheaper = const [],
      VisitFindings? visit,
    }) => negotiationArguments(
      listing,
      market: market,
      daysListed: days,
      cheaper: cheaper,
      visit: visit,
      today: _today,
    );

    test('a fair, recent bike gives nothing to argue with', () {
      expect(argue(_listing()), isEmpty);
    });

    test('above the estimate, by how much', () {
      final args = argue(
        _listing(
          price: 7500,
          breakdown: const {'market_price': 7000, 'market_listing_count': 8},
        ),
      );
      expect(args.single, contains('acima do valor de mercado'));
      expect(args.single, contains(Formatters.price(500)));
      // Not from an estimate on too few ads.
      expect(
        argue(
          _listing(
            price: 7500,
            breakdown: const {'market_price': 7000, 'market_listing_count': 2},
          ),
        ),
        isEmpty,
      );
    });

    test('cheaper bikes of the same model', () {
      expect(
        argue(_listing(), cheaper: [_listing(price: 6500)]).single,
        'Há outra MT-07 de ano parecido, sem mais km, por '
        '${Formatters.price(6500)}.',
      );
      expect(
        argue(
          _listing(),
          cheaper: [_listing(price: 6600), _listing(price: 6400)],
        ).single,
        contains('Há 2 MT-07'),
      );
    });

    test('high mileage, risk reasons, relists', () {
      final args = argue(
        _listing(
          mileage: 40000,
          breakdown: const {
            'market_price': 7000,
            'market_listing_count': 8,
            'risk_reasons': ['no_service_book', 'relisted', 'first_owner'],
          },
        ),
      );
      expect(args[0], contains('acima do normal para uma mota de 2022'));
      expect(args[1], contains('livro de revisões'));
      expect(args[2], 'Já esteve à venda noutro anúncio e não se vendeu.');
      expect(args, hasLength(3));
    });

    test('long on sale, against the model when it is known', () {
      expect(
        argue(_listing(), market: _market(), days: 60).single,
        'Está à venda há 60 dias; uma mota destas costuma sair em 30.',
      );
      expect(argue(_listing(), market: _market(), days: 20), isEmpty);
      expect(argue(_listing(), days: 60).single, 'Está à venda há 60 dias.');
    });

    test('an earlier drop shows the seller wants to sell', () {
      expect(
        argue(_listing(price: 6800, initialPrice: 7200)).single,
        contains('Já baixou de ${Formatters.price(7200)}'),
      );
    });

    test('old tyres, unless the ad or the visit says otherwise', () {
      final old = _listing(year: 2019, mileage: 20000);
      expect(argue(old).single, startsWith('Com 7 anos'));
      expect(
        argue(
          _listing(
            year: 2019,
            mileage: 20000,
            breakdown: const {
              'market_price': 7000,
              'extras': ['new_tyres'],
            },
          ),
        ),
        isEmpty,
      );
      final tyres = visitFindings({'tyres': _issue});
      expect(argue(old, visit: tyres).single, startsWith('Viu na visita'));
    });

    test('the visit comes first', () {
      final args = argue(
        _listing(price: 6800, initialPrice: 7200),
        visit: visitFindings({'chain': _issue}),
      );
      expect(args.first, startsWith('Viu na visita: corrente'));
    });
  });

  group('messages', () {
    test('each offer of the plan has its message', () {
      final offer = suggestOffer(_listing())!;
      final steps = offer.steps;
      expect(steps.first.message, offerMessage(offer.opening));
      expect(steps.last.message, lastOfferMessage(offer.ceiling));
      expect(steps.last.message, contains('última proposta'));
    });

    test('the reply to a counter-offer comes with the message to send', () {
      const offer = OfferSuggestion(opening: 6500, ceiling: 7000, reasons: []);
      expect(offer.reply(6400).message, acceptMessage(6400));
      expect(offer.reply(6900).message, offerMessage(6800));
      expect(offer.reply(7500).message, lastOfferMessage(7000));
      expect(offer.replyTo(7500), offer.reply(7500).advice);
      expect(walkAwayMessage, contains('se baixar o preço'));
    });
  });

  group('seller urgency', () {
    test('low without any sign', () {
      final u = sellerUrgency(_listing(), market: _market(), daysListed: 10);
      expect(u.level, Urgency.low);
      expect(u.text, 'Pressa do vendedor: baixa');
    });

    test('long on sale and a drop: medium, then high', () {
      expect(
        sellerUrgency(_listing(), market: _market(), daysListed: 40).level,
        Urgency.medium,
      );
      final u = sellerUrgency(
        _listing(price: 6800, initialPrice: 7200),
        market: _market(),
        daysListed: 70,
      );
      expect(u.level, Urgency.high);
      expect(
        u.text,
        'Pressa do vendedor: alta (à venda há 70 dias, já baixou o preço)',
      );
    });

    test('relisted often counts twice', () {
      final u = sellerUrgency(
        _listing(
          breakdown: const {
            'risk_reasons': ['relisted_often'],
          },
        ),
        daysListed: 50,
      );
      expect(u.level, Urgency.high);
      expect(u.reasons, ['à venda há 50 dias', 'posta à venda várias vezes']);
    });
  });

  group('dealer', () {
    test('asks for extras; tyres only when due and not new', () {
      expect(dealerAsks(_listing(year: 2025, mileage: 2000), today: _today), [
        'a revisão feita antes da entrega',
        'a garantia por escrito (numa usada vendida por um stand, a lei dá '
            'pelo menos 18 meses)',
        'o registo de propriedade pago por eles',
      ]);
      expect(
        dealerAsks(_listing(year: 2020), today: _today),
        contains('pneus novos'),
      );
      expect(
        dealerAsks(
          _listing(
            year: 2020,
            breakdown: const {
              'extras': ['new_tyres'],
            },
          ),
          today: _today,
        ),
        isNot(contains('pneus novos')),
      );
    });

    test('the message names the bike, the price and the asks', () {
      final message = dealerMessage(
        _listing(sellerType: SellerType.dealer),
        6800,
        today: _today,
      );
      expect(message, contains('Yamaha MT-07 de 2022'));
      expect(message, contains(Formatters.price(6800)));
      expect(message, contains('- o registo de propriedade pago por eles;'));
    });
  });
}
