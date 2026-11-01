import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/exit_price.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/exit_price_text.dart';

const exit = ExitPrice(goneCount: 7, median: 6000);

void main() {
  group('exitPriceLine', () {
    test('says what the gone ads left at', () {
      expect(
        exitPriceLine(exit),
        'Saíram do mercado por cerca de ${Formatters.price(6000)}: o último '
        'preço de 7 anúncios deste modelo que saíram nos últimos 90 dias, '
        'ajustado ao ano e aos km.',
      );
      expect(
        exitPriceLine(exit, language: .english),
        startsWith(
          'Left the market at about '
          '${Formatters.price(6000, language: .english)}: the last price '
          'of 7 ads',
        ),
      );
    });

    test("takes the bike's condition", () {
      expect(
        exitPriceLine(exit, adjust: 0.85),
        contains(Formatters.price(5100)),
      );
    });

    test('says nothing with fewer than 5 gone ads or no price', () {
      expect(exitPriceLine(const ExitPrice(goneCount: 4, median: 6000)), null);
      expect(
        exitPriceLine(const ExitPrice(goneCount: 5, median: 6000)),
        isNotNull,
      );
      expect(exitPriceLine(const ExitPrice(goneCount: 0)), isNull);
    });
  });

  group('exitPriceComparison', () {
    test('compares the asking price with it', () {
      expect(
        exitPriceComparison(exit, 6300),
        'Este anúncio pede ${Formatters.percent(5)} mais.',
      );
      expect(
        exitPriceComparison(exit, 5400),
        'Este anúncio pede ${Formatters.percent(10)} menos.',
      );
      expect(exitPriceComparison(exit, 6020), 'Este anúncio pede o mesmo.');
      expect(
        exitPriceComparison(exit, 6300, language: .english),
        'This ad asks ${Formatters.percent(5, language: .english)} more.',
      );
    });

    test('says nothing without a price or with too few gone ads', () {
      expect(exitPriceComparison(exit, null), isNull);
      expect(
        exitPriceComparison(const ExitPrice(goneCount: 4, median: 6000), 6300),
        isNull,
      );
      expect(exitPriceComparison(const ExitPrice(goneCount: 7), 6300), isNull);
    });
  });
}
