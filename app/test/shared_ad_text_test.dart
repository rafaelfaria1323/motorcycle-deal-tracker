import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/bike_condition.dart';
import 'package:motorcycle_deal_tracker/features/valuation/domain/entities/shared_ad.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/shared_ad_text.dart';

final _now = DateTime(2026, 11, 15);

SharedAd _ad({
  String url = 'https://www.facebook.com/marketplace/item/123/',
  String? title,
  String? description,
  String? price,
  String? oldPrice,
  String? pageText,
  List<String> lines = const [],
}) => SharedAd(
  id: 'a',
  receivedAt: _now,
  url: url,
  title: title,
  description: description,
  price: price,
  oldPrice: oldPrice,
  pageText: pageText,
  lines: lines,
);

void main() {
  test('a Facebook Marketplace ad as Safari shows it', () {
    final facts = sharedAdFacts(
      _ad(
        title: 'Yamaha MT-07 2019',
        description: '  Como nova, revisões na marca.  ',
        lines: [
          'Yamaha MT-07 2019',
          '7 500 €',
          'Anunciado há 5 semanas em Lisboa',
          'Conduzido 25 000 km',
        ],
      ),
      now: _now,
    );
    expect(facts.price, 7500);
    expect(facts.year, 2019);
    expect(facts.mileage, 25000);
    expect(facts.daysListed, 35);
    expect(facts.description, 'Como nova, revisões na marca.');
    expect(facts.words, ['yamaha', 'mt', '07', '2019']);
  });

  test('the English page', () {
    final facts = sharedAdFacts(
      _ad(
        title: '2021 Honda CB650R',
        lines: ['€6,900', 'Listed 3 weeks ago in Lisbon', 'Driven 12,000 km'],
      ),
      now: _now,
    );
    expect(facts.price, 6900);
    expect(facts.year, 2021);
    expect(facts.mileage, 12000);
    expect(facts.daysListed, 21);
  });

  group('price', () {
    test("the page's data first, also a bare number", () {
      expect(sharedAdPrice(_ad(price: '7500.00', lines: ['8 000 €'])), 7500);
      expect(sharedAdPrice(_ad(price: 'EUR 7.500'))!, 7500);
      expect(sharedAdPrice(_ad(price: '7.500,00 €')), 7500);
    });

    test('else the first line with euros', () {
      expect(
        sharedAdPrice(_ad(lines: ['Lisboa', '5.250 € negociáveis'])),
        5250,
      );
      expect(sharedAdPrice(_ad(price: '', lines: ['EUR 4 900'])), 4900);
    });

    test('placeholders and numbers without euros are no price', () {
      expect(sharedAdPrice(_ad(lines: ['1 €', 'Conduzido 25 000 km'])), isNull);
      expect(sharedAdPrice(_ad(price: 'consultar')), isNull);
      expect(sharedAdPrice(_ad(lines: ['2 000 000 €'])), isNull);
    });
  });

  group('year', () {
    test('the title, else a labelled line', () {
      expect(sharedAdYear(_ad(title: 'MT-07 2018 A2'), now: _now), 2018);
      expect(
        sharedAdYear(
          _ad(title: 'MT-07', lines: ['Ano: 2017']),
          now: _now,
        ),
        2017,
      );
    });

    test('never a price, a mileage, an unlabelled line or a future year', () {
      expect(sharedAdYear(_ad(title: 'Honda CB 2000 €'), now: _now), isNull);
      expect(sharedAdYear(_ad(title: 'Mota 2000 km'), now: _now), isNull);
      expect(
        sharedAdYear(
          _ad(title: 'MT-07', lines: ['Publicado 2025']),
          now: _now,
        ),
        isNull,
      );
      expect(sharedAdYear(_ad(title: 'MT-07 2030'), now: _now), isNull);
      expect(sharedAdYear(_ad(title: 'MT-07 2027'), now: _now), 2027);
    });
  });

  group('mileage', () {
    test('a labelled line first', () {
      expect(
        sharedAdMileage(_ad(lines: ['a 5 km de si', 'Quilómetros: 18.500'])),
        18500,
      );
      expect(sharedAdMileage(_ad(lines: ['Km 7 500'])), 7500);
    });

    test('a line with only the km, or km in a line or the title', () {
      expect(sharedAdMileage(_ad(lines: ['25 000 km'])), 25000);
      expect(sharedAdMileage(_ad(lines: ['7 500 € · 25 000 km'])), 25000);
      expect(sharedAdMileage(_ad(title: 'MT-07 12000km')), 12000);
    });

    test('a distance or a speed is no mileage', () {
      expect(sharedAdMileage(_ad(lines: ['Lisboa · a 5 km'])), isNull);
      expect(sharedAdMileage(_ad(lines: ['within 10 km'])), isNull);
      expect(sharedAdMileage(_ad(lines: ['Velocidade 220 km/h'])), isNull);
    });
  });

  group('time on sale', () {
    test('Portuguese and English, words for one', () {
      int? days(String line) => sharedAdDaysListed(_ad(lines: [line]));
      expect(days('Anunciado há 2 meses'), 60);
      expect(days('há uma semana'), 7);
      expect(days('Publicado há mais de 1 ano'), 365);
      expect(days('há 3 horas'), 0);
      expect(days('ontem'), 1);
      expect(days('Listed a week ago'), 7);
      expect(days('Listed about an hour ago'), 0);
      expect(days('2 days ago'), 2);
      expect(days('há 20 anos'), isNull);
      expect(days('7 500 €'), isNull);
    });
  });

  test("the inbox's name: the title, else the site", () {
    expect(sharedAdName(_ad(title: ' MT-07 ')), 'MT-07');
    expect(sharedAdName(_ad(title: '')), 'facebook.com');
    expect(
      sharedAdSite(_ad(url: 'https://m.custojusto.pt/lisboa/motos/x')),
      'custojusto.pt',
    );
  });

  group('the page text (script 3, N.110c)', () {
    final page = _ad(
      title: '2019 Yamaha MT-07',
      description: 'Mota sempre em garagem, único dono...',
      oldPrice: '7 400 €',
      lines: ['2019 Yamaha MT-07', '6 900 € 7 400 €', 'Anunciado há 3 semanas'],
      pageText: [
        '2019 Yamaha MT-07',
        '6 900 € 7 400 €',
        'Anunciado há 3 semanas',
        'Matrícula: 03/2019',
        'Condução: 18 000 km',
        'Mota sempre em garagem, único dono, livro de revisões na marca, '
            'pneus novos com 2000 km. Nunca caiu.',
        'Ver mais',
      ].join('\n'),
    );

    test('fills the price before the drop and the km', () {
      final facts = sharedAdFacts(page, now: _now);
      expect(facts.price, 6900);
      expect(facts.initialPrice, 7400);
      expect(facts.mileage, 18000);
      expect(facts.daysListed, 21);
    });

    test('takes the page\'s whole description over the cut one', () {
      expect(
        sharedAdDescription(page),
        startsWith('Mota sempre em garagem, único dono, livro'),
      );
      expect(sharedAdDescription(page), endsWith('Nunca caiu.'));
    });

    test('reads the condition, denials left out', () {
      final condition = sharedAdFacts(page, now: _now).condition;
      expect(condition.owners, BikeOwners.one);
      expect(condition.serviceBook, BikeServiceBook.yes);
      expect(condition.damage, BikeDamage.none);
      expect(condition.warranty, isFalse);
    });

    test('a line with two prices gives the first price', () {
      final ad = _ad(lines: ['5 500 € 6 000 €']);
      expect(sharedAdPrice(ad), 5500);
      expect(sharedAdInitialPrice(ad, 5500), 6000);
      expect(sharedAdInitialPrice(_ad(oldPrice: '5 000 €'), 5500), isNull);
      expect(sharedAdInitialPrice(_ad(oldPrice: '6 000 €'), null), isNull);
    });

    test('the year from a labelled line of the page', () {
      final ad = _ad(title: 'Honda CB650R', pageText: 'Ano: 2021\nOutro');
      expect(sharedAdYear(ad, now: _now), 2021);
    });

    test('without the share data, the page\'s long lines', () {
      final ad = _ad(
        pageText:
            'Curta\n${'Uma descrição longa da mota, com tudo o que tem e o que precisa, para ler com calma.'}'
            ' Mais.\nOutra',
      );
      expect(sharedAdDescription(ad), startsWith('Uma descrição longa'));
      expect(sharedAdDescription(_ad()), isNull);
    });
  });

  group('sharedAdCondition', () {
    test('accidents and falls', () {
      expect(
        sharedAdCondition('Teve um acidente ligeiro.').damage,
        BikeDamage.accident,
      );
      expect(
        sharedAdCondition('Caiu parada, riscos no escape.').damage,
        BikeDamage.dropped,
      );
      expect(
        sharedAdCondition('Nunca teve acidentes nem quedas.').damage,
        BikeDamage.none,
      );
      expect(sharedAdCondition('Sem quedas.').damage, BikeDamage.none);
      expect(
        sharedAdCondition('No accidents, never dropped.').damage,
        BikeDamage.none,
      );
      // Portuguese "no" is "in the".
      expect(
        sharedAdCondition('Riscos no depósito, caiu.').damage,
        BikeDamage.dropped,
      );
    });

    test('owners', () {
      expect(sharedAdCondition('1ª mão').owners, BikeOwners.one);
      expect(sharedAdCondition('Primeiro dono').owners, BikeOwners.one);
      expect(sharedAdCondition('2 donos').owners, BikeOwners.two);
      expect(sharedAdCondition('Teve 3 donos').owners, BikeOwners.threeOrMore);
      expect(sharedAdCondition('Impecável').owners, BikeOwners.unknown);
    });

    test('service book and warranty', () {
      expect(
        sharedAdCondition('Revisões na marca').serviceBook,
        BikeServiceBook.yes,
      );
      expect(
        sharedAdCondition('Sem livro de revisões').serviceBook,
        BikeServiceBook.no,
      );
      expect(sharedAdCondition('Ainda em garantia').warranty, isTrue);
      expect(sharedAdCondition('Sem garantia de fábrica').warranty, isFalse);
    });
  });
}
