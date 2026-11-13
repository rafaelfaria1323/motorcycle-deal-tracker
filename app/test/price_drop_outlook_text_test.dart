import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/price_drop_outlook.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/price_drop_outlook_text.dart';

PriceDropOutlook outlook({
  int dropped = 0,
  int gone = 0,
  int unchanged = 0,
  double? medianDrop,
}) => PriceDropOutlook(
  sample: dropped + gone + unchanged,
  dropped: dropped,
  gone: gone,
  unchanged: unchanged,
  medianDrop: medianDrop,
);

void main() {
  test('below five ads followed, nothing to say', () {
    expect(priceDropOutlookText(outlook(dropped: 2, unchanged: 2)), isNull);
    expect(priceDropOutlookText(outlook(dropped: 2, unchanged: 3)), isNotNull);
  });

  test('what the ads did, in Portuguese', () {
    final text = priceDropOutlookText(
      outlook(dropped: 4, gone: 2, unchanged: 4, medianDrop: 7.6),
    )!;
    expect(
      text.intro,
      'Anúncios deste modelo que estavam à venda há tanto tempo como este, '
      'nos 30 dias seguintes:',
    );
    expect(text.lines, [
      '4 de 10 baixaram o preço (em regra 8 %)',
      '2 de 10 saíram do mercado sem baixar',
      '4 de 10 continuaram ao mesmo preço',
    ]);
    expect(text.advice, startsWith('Muitos baixaram'));
  });

  test('no drops: no typical drop', () {
    final text = priceDropOutlookText(
      outlook(gone: 1, unchanged: 5),
      language: AppLanguage.english,
    )!;
    expect(text.lines.first, '0 of 6 lowered their price');
    expect(text.advice, startsWith('Few dropped'));
  });

  test('the advice follows the more frequent way out', () {
    expect(
      outlookAdvice(outlook(dropped: 4, gone: 1, unchanged: 5)),
      OutlookAdvice.wait,
    );
    expect(
      outlookAdvice(outlook(dropped: 3, gone: 2, unchanged: 5)),
      OutlookAdvice.neutral,
    );
    expect(
      outlookAdvice(outlook(dropped: 1, gone: 4, unchanged: 5)),
      OutlookAdvice.buyNow,
    );
    // As many left as dropped: waiting is no safer.
    expect(
      outlookAdvice(outlook(dropped: 4, gone: 4, unchanged: 2)),
      OutlookAdvice.buyNow,
    );
    expect(
      outlookAdvice(outlook(dropped: 5, gone: 4, unchanged: 1)),
      OutlookAdvice.wait,
    );
  });
}
