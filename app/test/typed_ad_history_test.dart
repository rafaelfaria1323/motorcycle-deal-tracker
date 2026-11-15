import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/typed_ad_history.dart';

void main() {
  group('typedAdDaysValue', () {
    test('empty is unknown', () {
      expect(typedAdDaysValue(''), (null,));
      expect(typedAdDaysValue('  '), (null,));
    });

    test('days, weeks and months as the sites say them', () {
      expect(typedAdDaysValue('35'), (35,));
      expect(typedAdDaysValue('0'), (0,));
      expect(typedAdDaysValue('12 dias'), (12,));
      expect(typedAdDaysValue('1 dia'), (1,));
      expect(typedAdDaysValue('5 semanas'), (35,));
      expect(typedAdDaysValue('5 Sem.'), (35,));
      expect(typedAdDaysValue('3 weeks'), (21,));
      expect(typedAdDaysValue('2 meses'), (60,));
      expect(typedAdDaysValue('1 mês'), (30,));
      expect(typedAdDaysValue('1 month'), (30,));
      expect(typedAdDaysValue('4d'), (4,));
    });

    test('the sites\' own words (B.3)', () {
      expect(typedAdDaysValue('há 5 semanas'), (35,));
      expect(typedAdDaysValue('Há 2 meses'), (60,));
      expect(typedAdDaysValue('5 weeks ago'), (35,));
      expect(typedAdDaysValue('2 dias atrás'), (2,));
      expect(typedAdDaysValue('Publicado há 3 dias'), (3,));
      expect(typedAdDaysValue('Listed 2 weeks ago'), (14,));
      expect(typedAdDaysValue('há uma semana'), (7,));
      expect(typedAdDaysValue('a week ago'), (7,));
      expect(typedAdDaysValue('um mês'), (30,));
      expect(typedAdDaysValue('1 ano'), (365,));
      expect(typedAdDaysValue('2 anos'), (730,));
      expect(typedAdDaysValue('a year ago'), (365,));
      expect(typedAdDaysValue('há 3 horas'), (0,));
      expect(typedAdDaysValue('an hour ago'), (0,));
      expect(typedAdDaysValue('há 20 minutos'), (0,));
      expect(typedAdDaysValue('10 min'), (0,));
    });

    test('anything else, or over ten years, is refused', () {
      expect(typedAdDaysValue('há muito'), isNull);
      expect(typedAdDaysValue('-3'), isNull);
      expect(typedAdDaysValue('3,5'), isNull);
      expect(typedAdDaysValue('3650'), (3650,));
      expect(typedAdDaysValue('3651'), isNull);
      expect(typedAdDaysValue('122 meses'), isNull);
      expect(typedAdDaysValue('11 anos'), isNull);
      expect(typedAdDaysValue('a'), isNull);
      expect(typedAdDaysValue('há'), isNull);
      expect(typedAdDaysValue('5 semanas depois'), isNull);
    });
  });

  group('parseTypedAdHistory', () {
    test('both empty: nothing known', () {
      expect(parseTypedAdHistory('', '', price: 7500), (
        daysListed: null,
        initialPrice: null,
      ));
    });

    test('an earlier price above the asking price is a drop', () {
      expect(parseTypedAdHistory('5 semanas', '7.900', price: 7500), (
        daysListed: 35,
        initialPrice: 7900,
      ));
      expect(
        parseTypedAdHistory(
          '',
          '7,900',
          price: 7500,
          language: AppLanguage.english,
        ),
        (daysListed: null, initialPrice: 7900),
      );
    });

    test('an earlier price not above it, or no price, is refused', () {
      expect(parseTypedAdHistory('', '7500', price: 7500), isNull);
      expect(parseTypedAdHistory('', '7000', price: 7500), isNull);
      expect(parseTypedAdHistory('', '200', price: null), isNull);
      expect(parseTypedAdHistory('', 'muito', price: 7500), isNull);
      expect(parseTypedAdHistory('', '8000', price: null), (
        daysListed: null,
        initialPrice: 8000,
      ));
    });

    test('an unreadable time is refused', () {
      expect(parseTypedAdHistory('ontem', '', price: 7500), isNull);
    });
  });
}
