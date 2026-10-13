import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

Listing _listing({int? dealScore, double? price, int? mileage, int? year, Map<String, dynamic>? breakdown}) {
  return Listing(
    id: 'id',
    source: 'mock',
    url: 'https://example.com',
    brand: 'Yamaha',
    model: 'R7',
    status: ListingStatus.active,
    sellerType: SellerType.dealer,
    images: const [],
    firstSeenAt: DateTime(2026, 1, 1),
    lastSeenAt: DateTime(2026, 1, 2),
    dealScore: dealScore,
    price: price,
    mileage: mileage,
    year: year,
    scoreBreakdown: breakdown,
  );
}

void main() {
  test('unscored listing has no explanation', () {
    expect(ScoreExplainer.explain(_listing()), isNull);
  });

  test('labels follow the score bands', () {
    expect(ScoreExplainer.label(90), 'Excelente');
    expect(ScoreExplainer.label(89), 'Muito bom');
    expect(ScoreExplainer.label(70), 'Interessante');
    expect(ScoreExplainer.label(60), 'Normal');
    expect(ScoreExplainer.label(59), 'Fraco');
  });

  test('good deal lists price, mileage and year as positives', () {
    final explanation = ScoreExplainer.explain(
      _listing(
        dealScore: 91,
        price: 8280,
        mileage: 3500,
        year: 2026,
        breakdown: {
          'pct_below_market': 8.0,
          'market_price': 9000,
          'market_listing_count': 5,
          'risk_reasons': <String>[],
          'slices_used': 3,
          'slices_total': 6,
        },
      ),
      currentYear: 2026,
    )!;

    expect(explanation.label, 'Excelente');
    expect(explanation.lines.map((l) => l.tone), [
      ExplanationTone.positive,
      ExplanationTone.positive,
      ExplanationTone.positive,
    ]);
    expect(explanation.lines.first.text, contains('abaixo do preço de mercado'));
    expect(explanation.slicesUsed, 3);
  });

  test('risk reasons and thin markets are explained', () {
    final explanation = ScoreExplainer.explain(
      _listing(
        dealScore: 55,
        price: 9000,
        breakdown: {
          'pct_below_market': 0.0,
          'market_price': 9000,
          'market_listing_count': 2,
          'risk_reasons': ['possible_accident', 'no_mileage'],
        },
      ),
      currentYear: 2026,
    )!;

    expect(explanation.label, 'Fraco');
    expect(explanation.lines.where((l) => l.tone == ExplanationTone.negative), hasLength(2));
    expect(explanation.lines.where((l) => l.text.contains('poucos anúncios')), hasLength(1));
  });
}
