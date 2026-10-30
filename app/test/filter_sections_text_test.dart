import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/filter_sections_text.dart';

void main() {
  test('nothing chosen reads as the section default', () {
    expect(chosenSummary(const [], none: 'Todos'), 'Todos');
  });

  test('one or two choices are named', () {
    expect(chosenSummary(const ['MT-07'], none: 'Todos'), 'MT-07');
    expect(chosenSummary(const ['MT-07', 'R7'], none: 'Todos'), 'MT-07 · R7');
  });

  test('more choices are counted', () {
    expect(
      chosenSummary(const ['MT-07', 'R7', 'CB650R'], none: 'Todos'),
      '3 escolhidos',
    );
    expect(
      chosenSummary(
        const ['Quickshifter', 'Exhaust', 'Luggage', 'Heated grips'],
        none: 'Any',
        language: AppLanguage.english,
      ),
      '4 chosen',
    );
  });
}
