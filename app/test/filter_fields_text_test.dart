import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/filter_fields_text.dart';

void main() {
  test('whole numbers are trimmed; blanks and junk mean no filter', () {
    expect(parseWholeNumberField(' 2021 '), 2021);
    expect(parseWholeNumberField(''), isNull);
    expect(parseWholeNumberField('abc'), isNull);
    expect(parseWholeNumberField('1,5'), isNull);
  });

  test('prices accept a comma as the decimal separator', () {
    expect(parsePriceField('7500'), 7500.0);
    expect(parsePriceField(' 7500,5 '), 7500.5);
    expect(parsePriceField('7500.5'), 7500.5);
    expect(parsePriceField(''), isNull);
    expect(parsePriceField('x'), isNull);
  });

  test('text fields are trimmed and a blank one is null', () {
    expect(parseTextField('  Porto '), 'Porto');
    expect(parseTextField('   '), isNull);
  });
}
