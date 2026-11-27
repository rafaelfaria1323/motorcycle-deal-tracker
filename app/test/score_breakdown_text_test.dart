import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_breakdown_text.dart';

Listing _listing({
  int? dealScore,
  int? riskScore,
  double? price,
  int? mileage,
  int? year,
  SellerType sellerType = SellerType.dealer,
  Map<String, dynamic>? breakdown,
}) => Listing(
  id: 'id',
  source: 'mock',
  url: 'https://example.com',
  brand: 'Yamaha',
  model: 'R7',
  status: ListingStatus.active,
  sellerType: sellerType,
  images: const [],
  firstSeenAt: DateTime(2026, 1, 1),
  lastSeenAt: DateTime(2026, 1, 2),
  dealScore: dealScore,
  riskScore: riskScore,
  price: price,
  mileage: mileage,
  year: year,
  scoreBreakdown: breakdown,
);

/// A dealer's bike with every slice, as recalculate_deal_scores() stores it.
Listing _fullListing() => _listing(
  dealScore: 79,
  riskScore: 10,
  price: 8280,
  mileage: 12000,
  year: 2022,
  breakdown: {
    'scores': {'price': 70, 'year_mileage': 79.5, 'risk': 90, 'seller': 80},
    'weights': {'price': 35, 'year_mileage': 20, 'risk': 10, 'seller': 10},
    'mileage_score': 75,
    'year_score': 90,
    'mileage_share': 0.7,
    'market_price': 9000,
    'pct_below_market': 8.0,
    'market_listing_count': 12,
    'dealer_bikes': 14,
    'equipment_bonus': 2,
    'valued_extras': ['quickshifter', 'exhaust'],
    'capped_without_price': false,
    'capped_for_damage': false,
    'capped_for_legalisation': false,
  },
);

void main() {
  test('an unscored listing has no breakdown', () {
    expect(scoreBreakdownOf(_listing()), isNull);
    expect(scoreBreakdownOf(_listing(dealScore: 50, breakdown: {})), isNull);
  });

  test('each slice shows its score, weight and points', () {
    final breakdown = scoreBreakdownOf(_fullListing())!;
    final rows = breakdown.rows;

    expect(rows.map((r) => r.label), [
      'Preço face ao mercado',
      'Ano e quilómetros',
      'Risco',
      'Vendedor',
    ]);
    expect(rows.every((r) => r.counted), isTrue);
    expect(rows.map((r) => r.score), [
      '70/100',
      '79,5/100',
      '90/100',
      '80/100',
    ]);
    // 35, 20, 10 and 10 of 75.
    expect(rows.map((r) => r.share), [
      'peso 47 %',
      'peso 27 %',
      'peso 13 %',
      'peso 13 %',
    ]);
    expect(rows.map((r) => r.points), [
      '32,7 pontos',
      '21,2 pontos',
      '12,0 pontos',
      '10,7 pontos',
    ]);

    expect(
      rows[0].details.first,
      'Preço 8,0 % abaixo do valor estimado (${Formatters.price(9000)})',
    );
    expect(
      rows[0].details.last,
      startsWith('50 pontos no valor de referência'),
    );
    expect(rows[1].details, [
      'Quilómetros (${Formatters.mileage(12000)}): 75/100, 70 % desta parte',
      'Ano (2022): 90/100, 30 % desta parte',
      startsWith('Quilómetros face à idade'),
      'Ano: 10 pontos a menos por cada ano de idade',
    ]);
    expect(rows[2].details, ['100 menos o Risk Score (10)']);
    expect(rows[3].details.single, startsWith('Pelas 14 motas do stand'));
  });

  test('the totals add the weighted average, the bonus and the score', () {
    final totals = scoreBreakdownOf(_fullListing())!.totals;

    expect(totals.first, const ScoreBreakdownTotal('Média ponderada', '76,5'));
    expect(totals[1].label, startsWith('Equipamento que vale dinheiro ('));
    expect(totals[1].value, '+2');
    expect(
      totals.last,
      const ScoreBreakdownTotal('Deal Score', '79', isResult: true),
    );
    expect(totals, hasLength(3));
  });

  test('slices without data say why they do not count', () {
    final breakdown = scoreBreakdownOf(
      _listing(
        dealScore: 53,
        riskScore: 20,
        price: 1,
        sellerType: SellerType.private,
        year: 2015,
        breakdown: {
          // Scored before N.126: no parts of the year/mileage slice.
          'scores': {'year_mileage': 40, 'risk': 80},
          'weights': {'year_mileage': 20, 'risk': 10},
          'equipment_bonus': 0,
          'capped_without_price': false,
        },
      ),
    )!;
    final rows = breakdown.rows;

    expect(rows.map((r) => r.counted), [false, true, true, false]);
    expect(rows[0].details, ['Não conta: o anúncio não tem preço']);
    expect(rows[0].share, isNull);
    expect(rows[1].details, isEmpty);
    expect(rows[1].share, 'peso 67 %');
    expect(rows[1].points, '26,7 pontos');
    expect(rows[2].details, ['100 menos o Risk Score (20)']);
    expect(rows[3].details, [
      'Não conta: só os stands com 5 ou mais motas têm esta parte',
    ]);
    expect(breakdown.totals.map((t) => t.label), [
      'Média ponderada',
      'Deal Score',
    ]);
    expect(breakdown.totals.first.value, '53,3');
  });

  test('too few comparables and a small dealer leave out their slices', () {
    final breakdown = scoreBreakdownOf(
      _listing(
        dealScore: 70,
        riskScore: 0,
        price: 8000,
        mileage: 1000,
        year: 2025,
        breakdown: {
          'scores': {'year_mileage': 97, 'risk': 100},
          'weights': {'year_mileage': 20, 'risk': 10},
          'market_listing_count': 2,
          'equipment_bonus': 1,
          'capped_without_price': true,
        },
      ),
    )!;

    expect(breakdown.rows[0].details, [
      'Não conta: há 2 anúncios para comparar e são precisos 3',
    ]);
    expect(breakdown.rows[3].details, [
      'Não conta: o stand tem menos de 5 motas guardadas',
    ]);
    expect(breakdown.totals.map((t) => (t.label, t.value)), [
      ('Média ponderada', '98,0'),
      ('Equipamento que vale dinheiro', '+1'),
      ('Máximo sem comparação de preço', '70'),
      ('Deal Score', '70'),
    ]);
  });

  test('a damaged bike is priced against its value with the damage', () {
    final breakdown = scoreBreakdownOf(
      _listing(
        dealScore: 79,
        riskScore: 30,
        price: 7350,
        breakdown: {
          'scores': {'price': 37.5, 'risk': 70},
          'weights': {'price': 35, 'risk': 10},
          'market_price': 8750,
          'pct_below_market': 16.0,
          'damaged_value': 7000,
          'pct_below_damaged_value': -5.0,
          'capped_for_damage': true,
        },
      ),
    )!;

    expect(
      breakdown.rows[0].details.first,
      'Preço 5,0 % acima do valor estimado com o dano '
      '(${Formatters.price(7000)})',
    );
    expect(breakdown.rows[1].details, [
      'Não conta: o anúncio não diz o ano nem os quilómetros',
    ]);
    expect(
      breakdown.totals.map((t) => t.label),
      contains('Máximo com danos ou reparações'),
    );
  });

  test('a nearly new bike is priced against a new one', () {
    final breakdown = scoreBreakdownOf(
      _listing(
        dealScore: 90,
        price: 7600,
        breakdown: {
          'scores': {'price': 75},
          'weights': {'price': 35},
          'market_price': 7700,
          'pct_below_market': 1.3,
          'new_price': 8000,
          'pct_below_new': 5.0,
          'price_from_new': true,
        },
      ),
    )!;

    expect(
      breakdown.rows[0].details.first,
      'Preço 5,0 % abaixo do preço de uma mota nova '
      '(${Formatters.price(8000)})',
    );
    expect(breakdown.rows[0].share, 'peso 100 %');
  });

  test('English', () {
    final breakdown = scoreBreakdownOf(
      _fullListing(),
      language: AppLanguage.english,
    )!;

    expect(breakdown.rows.first.label, 'Price against the market');
    expect(breakdown.rows.first.share, 'weight 47 %');
    expect(breakdown.rows.first.points, '32.7 points');
    expect(
      breakdown.rows.first.details.first,
      'Price 8.0 % below the estimated value '
      '(${Formatters.price(9000, language: AppLanguage.english)})',
    );
    expect(breakdown.totals.first.label, 'Weighted average');
  });
}
