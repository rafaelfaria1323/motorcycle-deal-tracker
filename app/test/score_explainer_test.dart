import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

Listing _listing({
  int? dealScore,
  double? price,
  int? mileage,
  int? year,
  Map<String, dynamic>? breakdown,
}) {
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
        mileage: 2000,
        year: 2026,
        breakdown: {
          'pct_below_market': 8.0,
          'market_price': 9000,
          'market_listing_count': 5,
          'risk_reasons': <String>[],
          'slices_used': 3,
          'slices_total': 3,
        },
      ),
      today: DateTime(2026, 12, 31),
    )!;

    expect(explanation.label, 'Excelente');
    expect(explanation.lines.map((l) => l.tone), [
      ExplanationTone.positive,
      ExplanationTone.neutral,
      ExplanationTone.positive,
      ExplanationTone.positive,
    ]);
    expect(
      explanation.lines.first.text,
      contains('8 % (720 €) abaixo do valor estimado'),
    );
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
      today: DateTime(2026, 12, 31),
    )!;

    expect(explanation.label, 'Fraco');
    expect(
      explanation.lines.where((l) => l.tone == ExplanationTone.negative),
      hasLength(2),
    );
    expect(
      explanation.lines.where((l) => l.text.contains('poucos anúncios')),
      hasLength(1),
    );
  });

  test('extras found in the ad read as a positive', () {
    final explanation = ScoreExplainer.explain(
      _listing(
        dealScore: 80,
        breakdown: {
          'extras': ['exhaust', 'heated_grips', 'something_new'],
        },
      ),
    )!;

    expect(
      explanation.lines,
      contains(
        const ExplanationLine(
          ExplanationTone.positive,
          'Extras indicados: escape desportivo, punhos aquecidos',
        ),
      ),
    );
    expect(
      ScoreExplainer.explain(
        _listing(
          dealScore: 80,
          breakdown: {
            'extras': ['exhaust', 'heated_grips'],
            'equipment_bonus': 4,
          },
        ),
      )!.lines.single.text,
      'Extras indicados (+4): escape desportivo, punhos aquecidos',
    );
    expect(
      ScoreExplainer.explain(
        _listing(
          dealScore: 80,
          breakdown: {
            'extras': ['led_indicators', 'phone_mount', 'quickshifter'],
            'valued_extras': ['quickshifter'],
            'equipment_bonus': 1,
          },
        ),
      )!.lines.single.text,
      'Extras indicados (+1 por quickshifter): piscas LED, '
      'suporte de telemóvel ou USB, quickshifter',
    );
    expect(extrasText(const {'extras': <String>[]}), isNull);
    expect(extrasText(null), isNull);
  });

  test('a scored dealer is explained by its band; otherwise nothing', () {
    ExplanationLine? line(num score, [int? bikes = 12]) => sellerLine({
      'scores': {'seller': score},
      'dealer_bikes': bikes,
    });

    expect(
      line(90),
      const ExplanationLine(
        ExplanationTone.positive,
        'Stand com anúncios fiáveis (90/100 em 12 motas)',
      ),
    );
    expect(line(80)!.tone, ExplanationTone.positive);
    expect(line(79.6)!.text, contains('fiáveis (80/100'));
    expect(line(79.4)!.tone, ExplanationTone.neutral);
    expect(line(50)!.tone, ExplanationTone.neutral);
    expect(line(49)!.tone, ExplanationTone.negative);
    expect(line(49)!.text, contains('muitos sinais de alerta'));
    expect(line(60, null)!.text, endsWith('(60/100)'));
    expect(sellerLine(const {'scores': <String, dynamic>{}}), isNull);
    expect(sellerLine(null), isNull);

    final lines = ScoreExplainer.explain(
      _listing(
        dealScore: 75,
        breakdown: {
          'scores': {'seller': 100},
          'dealer_bikes': 6,
        },
      ),
    )!.lines;
    expect(
      lines.single.text,
      'Stand com anúncios fiáveis (100/100 em 6 motas)',
    );
  });

  test('a score without the price comparison says it is capped', () {
    final lines = ScoreExplainer.explain(
      _listing(dealScore: 70, breakdown: {'capped_without_price': true}),
    )!.lines;
    expect(lines.single.text, contains('no máximo em 70'));
  });

  test('a damaged bike says its score is capped at 79', () {
    final lines = ScoreExplainer.explain(
      _listing(dealScore: 79, breakdown: {'capped_for_damage': true}),
    )!.lines;
    expect(lines.single.tone, ExplanationTone.negative);
    expect(lines.single.text, contains('no máximo em 79'));
  });

  test('a damaged bike\'s price is judged against its damaged value', () {
    final lines = ScoreExplainer.explain(
      _listing(
        dealScore: 70,
        price: 7000,
        breakdown: {
          'pct_below_market': 22.2,
          'market_price': 9000,
          'market_listing_count': 5,
          'damage_allowance': 0.2,
          'damaged_value': 7200,
          'pct_below_damaged_value': 2.8,
        },
      ),
      today: DateTime(2026, 12, 31),
    )!.lines;
    // 2.8 % below 7 200 is in line, not 22 % below 9 000.
    expect(lines.first.tone, ExplanationTone.neutral);
    expect(lines[1].text, startsWith('Valor estimado'));
    expect(lines[2].text, contains('para a reparação'));
  });

  group('mileage against the bike\'s age (5 000 km a year is normal)', () {
    ExplanationLine? line(int? km, int? year) => mileageForAge(km, year, 2027);

    test('the normal grows with age, at least one year\'s', () {
      expect(expectedMileage(2026, 2027), 5000);
      expect(expectedMileage(2025, 2027), 7500);
      expect(expectedMileage(2016, 2027), 52500);
    });

    test('bands: low, normal, above, far above', () {
      expect(line(2500, 2026)!.tone, ExplanationTone.positive);
      expect(line(2500, 2026)!.text, startsWith('Poucos km para o ano'));
      expect(line(30000, 2016)!.tone, ExplanationTone.neutral);
      expect(line(10000, 2025)!.tone, ExplanationTone.negative);
      expect(line(10000, 2025)!.text, startsWith('Km acima do normal'));
      expect(line(20000, 2025)!.text, startsWith('Muitos km para o ano'));
      expect(line(20000, 2025)!.text, contains('normal: cerca de'));
    });

    test('counted in days: no jump on 1 January', () {
      final dec31 = expectedMileage(2024, decimalYear(DateTime(2025, 12, 31)));
      final jan1 = expectedMileage(2024, decimalYear(DateTime(2026)));
      expect((jan1 - dec31).abs(), lessThan(20));
      expect(decimalYear(DateTime(2026, 7, 2)), closeTo(2026.5, 0.01));
    });

    test('up to 10 % over the normal is still normal', () {
      // 2022 at the start of 2027: 4.5 years, 22 500 km.
      expect(line(24000, 2022)!.text, startsWith('Km normais'));
      expect(line(27000, 2022)!.text, startsWith('Km acima do normal'));
    });

    test('without a year only a low mileage is said; nothing without km', () {
      expect(line(3000, null)!.tone, ExplanationTone.positive);
      expect(line(30000, null), isNull);
      expect(line(null, 2020), isNull);
    });
  });
}
