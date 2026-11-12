import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/financing.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/financing_text.dart';

String price(double amount, [AppLanguage language = .portuguese]) =>
    Formatters.price(amount, language: language);

void main() {
  group('financingCost', () {
    test('the TAEG is an effective yearly rate: its twelfth root a month', () {
      final cost = financingCost(
        price: 8000,
        deposit: 2000,
        months: 48,
        apr: 0.119,
      );
      expect(cost.financed, 6000);
      expect(cost.monthly, closeTo(155.94, 0.01));
      expect(cost.totalPaid, closeTo(9485.03, 0.01));
      expect(cost.interest, closeTo(1485.03, 0.01));
      expect(cost.nothingFinanced, isFalse);
    });

    test('at 0 % the instalments only split the price', () {
      final cost = financingCost(price: 6000, deposit: 0, months: 48, apr: 0);
      expect(cost.monthly, 125);
      expect(cost.totalPaid, 6000);
      expect(cost.interest, 0);
    });

    test('a deposit that covers the price borrows nothing', () {
      final cost = financingCost(
        price: 5000,
        deposit: 6000,
        months: 24,
        apr: 0.1,
      );
      expect(cost.nothingFinanced, isTrue);
      expect(cost.monthly, 0);
      expect(cost.totalPaid, 5000);
      expect(cost.interest, 0);
    });

    test('a longer term lowers the instalment and raises the interest', () {
      FinancingCost over(int months) =>
          financingCost(price: 8000, deposit: 0, months: months, apr: 0.12);
      expect(over(72).monthly, lessThan(over(36).monthly));
      expect(over(72).interest, greaterThan(over(36).interest));
    });
  });

  test('parseRate reads a typed TAEG', () {
    expect(parseRate('11,9'), closeTo(0.119, 1e-9));
    expect(parseRate(' 11.9 % '), closeTo(0.119, 1e-9));
    expect(parseRate('0'), 0);
    expect(parseRate('100'), 1);
    expect(parseRate('101'), isNull);
    expect(parseRate(''), isNull);
    expect(parseRate('doze'), isNull);
    expect(parseRate('1,2,3'), isNull);
  });

  group('financingLines', () {
    final cost = financingCost(
      price: 8000,
      deposit: 2000,
      months: 48,
      apr: 0.119,
    );

    test('the instalment, the total and the interest', () {
      expect(financingLines(cost), [
        '${price(155.94)} por mês durante 48 meses',
        'Paga ${price(9485.03)} ao todo, entrada incluída: '
            '${price(1485.03)} a mais do que a pronto',
      ]);
    });

    test('the same loan at the most to pay, and what it saves', () {
      final lines = financingLines(cost, offer: 7500);
      expect(lines, hasLength(3));
      expect(
        lines.last,
        'Se fechar pela oferta máxima de "Quanto oferecer" '
        '(${price(7500)}): ${price(142.94)} por mês, ${price(8861.28)} '
        'ao todo, menos ${price(9485.03 - 8861.28)}',
      );
    });

    test('no offer line when the offer is the price or near it', () {
      expect(financingLines(cost, offer: 8000), hasLength(2));
      expect(financingLines(cost, offer: 7951), hasLength(2));
      expect(financingLines(cost, offer: 7950), hasLength(3));
    });

    test('nothing borrowed says so', () {
      final paid = financingCost(
        price: 5000,
        deposit: 5000,
        months: 24,
        apr: 0.1,
      );
      expect(financingLines(paid, offer: 4500), [
        'A entrada cobre o preço: não há nada a financiar',
      ]);
    });

    test('in English', () {
      expect(
        financingLines(cost, language: .english).first,
        '${price(155.94, .english)} a month for 48 months',
      );
    });
  });
}
