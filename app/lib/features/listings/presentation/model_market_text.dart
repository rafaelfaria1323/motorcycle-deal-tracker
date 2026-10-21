import '../../../core/formatting/formatters.dart';
import '../domain/entities/model_market.dart';
import 'market_behaviour_text.dart';

/// Cheapest typical asking price first; models without prices last.
List<ModelMarket> byMedianPrice(List<ModelMarket> models) {
  final sorted = [...models];
  sorted.sort((a, b) {
    final x = a.prices?.median;
    final y = b.prices?.median;
    if (x == null || y == null) {
      if (x != y) return x == null ? 1 : -1;
      return a.name.compareTo(b.name);
    }
    final byPrice = x.compareTo(y);
    return byPrice != 0 ? byPrice : a.name.compareTo(b.name);
  });
  return sorted;
}

/// The asking-price lines of a model in the comparison.
List<String> priceSpreadLines(PriceSpread? p) {
  if (p == null) return const ['Sem anúncios ativos com preço'];
  if (p.count < minMarketData) {
    return [
      'Preços pedidos: ainda poucos dados '
          '(${p.count} ${p.count == 1 ? 'anúncio' : 'anúncios'})',
    ];
  }

  String price(double value) => Formatters.price(value);
  final year = p.medianYear;
  final km = p.medianMileage == null
      ? null
      : Formatters.mileage(p.medianMileage);
  final typical = switch ((year, km)) {
    (null, null) => null,
    (final year?, null) => 'A mota típica é de $year',
    (null, final km?) => 'A mota típica tem $km',
    (final year?, final km?) => 'A mota típica é de $year, com $km',
  };
  return [
    'Preço pedido típico ${price(p.median)} '
        '(metade entre ${price(p.p25)} e ${price(p.p75)})',
    'De ${price(p.min)} a ${price(p.max)}',
    ?typical,
  ];
}
