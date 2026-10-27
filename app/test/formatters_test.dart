import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';

void main() {
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

  test(
    'English formats euros, kilometres, decimals and percentages regionally',
    () {
      const language = AppLanguage.english;
      expect(Formatters.price(7450, language: language), '€7,450');
      expect(Formatters.mileage(12500, language: language), '12,500 km');
      expect(Formatters.percent(5.25, decimals: 1, language: language), '5.3%');
      expect(Formatters.decimal(42.25, language: language), '42.3');
      final now = DateTime(2026, 10, 19, 12);
      expect(
        Formatters.daysAgo(
          DateTime(2026, 10, 19, 8),
          now: now,
          language: language,
        ),
        'today',
      );
      expect(
        Formatters.daysAgo(
          DateTime(2026, 10, 18, 8),
          now: now,
          language: language,
        ),
        'yesterday',
      );
      expect(
        Formatters.daysAgo(
          DateTime(2026, 10, 14, 8),
          now: now,
          language: language,
        ),
        '5 days ago',
      );
    },
  );

  test('malformed regional grouping cannot silently change the amount', () {
    for (final text in ['6,50', '1.234,56', '1,23,456', '1e3']) {
      expect(
        Formatters.parsePrice(text, language: AppLanguage.english),
        isNull,
        reason: text,
      );
    }
    for (final text in ['6.50', '1,234.56', '1.23.456', '1e3']) {
      expect(Formatters.parsePrice(text), isNull, reason: text);
    }
  });

  test(
    'price entry uses the chosen language and rejects non-finite numbers',
    () {
      for (final (language, text) in [
        (AppLanguage.portuguese, '6.500,50 €'),
        (AppLanguage.portuguese, '6\u202f500,50'),
        (AppLanguage.english, '€6,500.50'),
        (AppLanguage.english, '6 500.50'),
      ]) {
        expect(Formatters.parsePrice(text, language: language), 6500.5);
      }
      for (final language in AppLanguage.values) {
        for (final text in ['', 'unknown', 'NaN', 'Infinity', '-Infinity']) {
          expect(Formatters.parsePrice(text, language: language), isNull);
        }
      }
    },
  );

  test('calendar days count local days, not 24-hour spans', () {
    // Late evening to just after midnight: the next day.
    expect(
      Formatters.calendarDays(
        DateTime(2026, 3, 29, 23, 30),
        DateTime(2026, 3, 30, 1, 40),
      ),
      1,
    );
    expect(
      Formatters.calendarDays(DateTime(2026, 3, 29, 8), DateTime(2026, 3, 29)),
      0,
    );
    expect(
      Formatters.calendarDays(DateTime(2026, 2, 27), DateTime(2026, 3, 2)),
      3,
    );
  });
}
