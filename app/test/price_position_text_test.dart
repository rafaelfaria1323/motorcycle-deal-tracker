import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_position_text.dart';

void main() {
  group('pricePosition', () {
    test('counts the cheaper, equal and dearer listings', () {
      final p = pricePosition(7000, [6000, 6500, 7000, 8000, 9000])!;

      expect(p.cheaper, 2);
      expect(p.same, 1);
      expect(p.dearer, 2);
      expect(p.others, 5);
    });

    test('the median of an even number of prices is the middle average', () {
      expect(pricePosition(7000, [1, 2, 3, 4, 5, 6])!.median, 3.5);
      expect(pricePosition(7000, [5, 1, 4, 2, 3])!.median, 3);
    });

    test('the strip spans every price, this listing included', () {
      final p = pricePosition(10000, [6000, 7000, 8000, 9000, 6000])!;

      expect(p.lowest, 6000);
      expect(p.highest, 10000);
      expect(p.thisX, 1);
      expect(p.othersX, [0, 0, 0.25, 0.5, 0.75]);
    });

    test('a listing below every other one starts the strip', () {
      final p = pricePosition(5000, [6000, 7000, 8000, 9000, 10000])!;

      expect(p.lowest, 5000);
      expect(p.thisX, 0);
      expect(p.othersX.last, 1);
    });

    test('equal prices sit in the middle', () {
      final p = pricePosition(7000, [7000, 7000, 7000, 7000, 7000])!;

      expect(p.thisX, 0.5);
      expect(p.othersX, everyElement(0.5));
    });

    test('needs a price and at least five others', () {
      expect(pricePosition(null, [1, 2, 3, 4, 5]), isNull);
      expect(pricePosition(7000, [1, 2, 3, 4]), isNull);
      expect(pricePosition(7000, [1, 2, 3, 4, 5]), isNotNull);
    });
  });

  group('pricePositionLine', () {
    test('says where the price sits, with the median', () {
      expect(
        pricePositionLine(7000, [6000, 6500, 8000, 9000, 9500]),
        '2 anúncios ativos são mais baratos e 3 são mais caros '
        '(mediana ${Formatters.price(8000)})',
      );
    });

    test('singular forms and equal prices', () {
      expect(
        pricePositionLine(7000, [6000, 7000, 7000, 8000, 9000]),
        startsWith(
          '1 anúncio ativo é mais barato e 2 são mais caros, '
          '2 têm o mesmo preço',
        ),
      );
      expect(
        pricePositionLine(7000, [6000, 6500, 7000, 8000, 7500]),
        startsWith(
          '2 anúncios ativos são mais baratos e 2 são mais caros, '
          '1 tem o mesmo preço',
        ),
      );
      expect(
        pricePositionLine(7000, [6000, 6500, 5000, 8000, 5500]),
        startsWith('4 anúncios ativos são mais baratos e 1 é mais caro'),
      );
    });

    test('the cheapest and the dearest are named as such', () {
      expect(
        pricePositionLine(5000, [6000, 7000, 8000, 9000, 10000]),
        startsWith('O preço mais baixo dos 6 anúncios ativos deste modelo'),
      );
      expect(
        pricePositionLine(11000, [6000, 7000, 8000, 9000, 10000]),
        startsWith('O preço mais alto dos 6 anúncios ativos deste modelo'),
      );
    });

    test('a tie with the cheapest or dearest is not called that', () {
      expect(
        pricePositionLine(6000, [6000, 7000, 8000, 9000, 10000]),
        startsWith(
          'Nenhum anúncio ativo é mais barato e 4 são mais caros, '
          '1 tem o mesmo preço',
        ),
      );
      expect(
        pricePositionLine(10000, [6000, 7000, 8000, 9000, 10000]),
        startsWith(
          '4 anúncios ativos são mais baratos e nenhum é mais caro, '
          '1 tem o mesmo preço',
        ),
      );
    });

    test('few others: not enough data, and nothing without a price', () {
      expect(
        pricePositionLine(7000, [6000, 8000]),
        'Preço face aos outros anúncios: ainda poucos dados '
        '(2 anúncios ativos)',
      );
      expect(
        pricePositionLine(7000, [6000]),
        'Preço face aos outros anúncios: ainda poucos dados '
        '(1 anúncio ativo)',
      );
      expect(pricePositionLine(null, [1, 2, 3, 4, 5]), isNull);
    });
  });
}
