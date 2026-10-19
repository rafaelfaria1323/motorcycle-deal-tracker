import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/compare_text.dart';

Listing listing(
  String id, {
  double? price,
  int? dealScore,
  int? riskScore,
  int? year,
  int? mileage,
  double? pctBelow,
  int? owners,
  bool? serviceBook,
  double? initialPrice,
}) => Listing(
  id: id,
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/$id.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  price: price,
  initialPrice: initialPrice,
  dealScore: dealScore,
  riskScore: riskScore,
  year: year,
  mileage: mileage,
  registrations: owners,
  serviceBook: serviceBook,
  scoreBreakdown: pctBelow == null ? null : {'pct_below_market': pctBelow},
  firstSeenAt: DateTime.utc(2026, 10, 10),
);

CompareRow rowOf(List<CompareRow> rows, String label) =>
    rows.firstWhere((r) => r.label == label);

void main() {
  test('bestOf picks the best known values, none when not a contest', () {
    expect(bestOf([7000, 6500, null], higherIsBetter: false), {1});
    expect(bestOf([80, 90, 90], higherIsBetter: true), {1, 2});
    expect(bestOf([80, 80], higherIsBetter: true), isEmpty);
    expect(bestOf([80, null], higherIsBetter: true), isEmpty);
  });

  test('each row marks its best column', () {
    final rows = compareRows([
      listing(
        'a',
        price: 7000,
        dealScore: 72,
        riskScore: 30,
        year: 2021,
        mileage: 15000,
        pctBelow: 4,
        owners: 1,
        serviceBook: true,
      ),
      listing(
        'b',
        price: 6500,
        dealScore: 85,
        riskScore: 45,
        year: 2020,
        mileage: 9000,
        pctBelow: -3,
        owners: 2,
        serviceBook: false,
      ),
    ], now: DateTime.utc(2026, 10, 20));

    expect(rowOf(rows, 'Preço').best, {1});
    expect(rowOf(rows, 'Pontuação').best, {1});
    expect(rowOf(rows, 'Risco').best, {0});
    expect(rowOf(rows, 'Face ao mercado').values, [
      '4 % abaixo do mercado',
      '3 % acima do mercado',
    ]);
    expect(rowOf(rows, 'Face ao mercado').best, {0});
    expect(rowOf(rows, 'Ano').best, {0});
    expect(rowOf(rows, 'Quilómetros').best, {1});
    expect(rowOf(rows, 'Donos').best, {0});
    expect(rowOf(rows, 'Livro de revisões').values, ['Completo', 'Não']);
    expect(rowOf(rows, 'Livro de revisões').best, {0});
    expect(rowOf(rows, 'Localização').best, isEmpty);
    expect(rowOf(rows, 'Visto pela primeira vez').values, [
      'há 10 dias',
      'há 10 dias',
    ]);
  });

  test('unknown values are a dash and never win', () {
    final rows = compareRows([listing('a'), listing('b', year: 2022)]);

    expect(rowOf(rows, 'Ano').values, ['—', '2022']);
    expect(rowOf(rows, 'Ano').best, isEmpty);
    expect(rowOf(rows, 'Face ao mercado').values, ['—', '—']);
    expect(rowOf(rows, 'Pontuação').values, ['—', '—']);
  });

  test('a price drop shows how much', () {
    final rows = compareRows([
      listing('a', price: 6500, initialPrice: 7000),
      listing('b', price: 6500, initialPrice: 6500),
    ]);
    expect(rowOf(rows, 'Baixa de preço').values.last, '—');
    expect(rowOf(rows, 'Baixa de preço').values.first, startsWith('−'));
  });

  test('ids from the address: no repeats, at most three', () {
    expect(parseCompareIds('a,b,a,c,d'), ['a', 'b', 'c']);
    expect(parseCompareIds(' a , ,b'), ['a', 'b']);
    expect(parseCompareIds(null), isEmpty);
  });
}
