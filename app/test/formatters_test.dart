import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  test('price and mileage show a dash when missing', () {
    expect(Formatters.price(null), '—');
    expect(Formatters.mileage(null), '—');
  });

  test('price has the euro sign and no decimals', () {
    final text = Formatters.price(7450);
    expect(text, contains('€'));
    expect(text, contains('450'));
    expect(text, isNot(contains(',')));
  });

  test('mileage ends in km', () {
    expect(Formatters.mileage(12500), endsWith(' km'));
    expect(Formatters.mileage(12500), contains('500'));
  });

  test('date is day/month/year', () {
    expect(Formatters.date(DateTime(2026, 3, 7)), '07/03/2026');
  });

  test('daysAgo says today, yesterday, then the number of days', () {
    final now = DateTime(2026, 10, 19, 12);
    expect(Formatters.daysAgo(DateTime(2026, 10, 19, 8), now: now), 'hoje');
    expect(Formatters.daysAgo(DateTime(2026, 10, 18, 8), now: now), 'ontem');
    expect(
      Formatters.daysAgo(DateTime(2026, 10, 14, 8), now: now),
      'há 5 dias',
    );
  });

  test('percent has a decimal comma and a space before the sign', () {
    expect(Formatters.percent(15), '15 %');
    expect(Formatters.percent(5.25, decimals: 1), '5,3 %');
    expect(Formatters.percent(4.04, decimals: 1), '4,0 %');
  });
}
