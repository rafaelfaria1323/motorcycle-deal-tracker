import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/comparable_years.dart';

void main() {
  ComparableYears? parse(String from, String to) =>
      parseComparableYears(from, to, first: 1990, last: 2027);

  test('empty fields are open ends', () {
    expect(parse('', ' '), (from: null, to: null));
    expect(parse('2018', ''), (from: 2018, to: null));
    expect(parse('', '2020'), (from: null, to: 2020));
    expect(parse(' 2018 ', '2020'), (from: 2018, to: 2020));
    expect(parse('2020', '2020'), (from: 2020, to: 2020));
  });

  test('years out of range, not numbers or backwards are refused', () {
    expect(parse('1989', ''), isNull);
    expect(parse('', '2028'), isNull);
    expect(parse('dois mil', ''), isNull);
    expect(parse('2021', '2020'), isNull);
    expect(parse('1990', '2027'), (from: 1990, to: 2027));
  });

  test('the line says which ads the value comes from', () {
    expect(comparableYearsText((from: null, to: null)), isNull);
    expect(
      comparableYearsText((from: 2018, to: 2020)),
      'Comparado só com anúncios de 2018 a 2020',
    );
    expect(
      comparableYearsText((from: 2018, to: null)),
      'Comparado só com anúncios de 2018 ou mais recentes',
    );
    expect(
      comparableYearsText((
        from: null,
        to: 2020,
      ), language: AppLanguage.english),
      'Compared only with ads from 2020 or older',
    );
  });
}
