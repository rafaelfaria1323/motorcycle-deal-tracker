import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/market_behaviour_text.dart';

MarketBehaviour market({
  int gone = 0,
  int? toGone,
  int priced = 0,
  int dropped = 0,
  double? drop,
}) => MarketBehaviour(
  liveCount: 12,
  goneCount: gone,
  pricedCount: priced,
  droppedCount: dropped,
  medianDaysToGone: toGone,
  medianDropPct: drop,
);

void main() {
  test('few departures are not presented as a typical time', () {
    final lines = marketLines(market(gone: 2, toGone: 9));

    expect(
      lines,
      contains(
        'Tempo até sair do mercado: ainda poucos dados (2 anúncios saíram)',
      ),
    );
  });

  test('enough data gives the typical time and the drop share', () {
    final lines = marketLines(
      market(gone: 6, toGone: 21, priced: 12, dropped: 3, drop: 4.2),
    );

    expect(
      lines,
      contains('Tempo típico até sair do mercado: 21 dias (6 anúncios)'),
    );
    expect(
      lines,
      contains('25% dos vendedores baixaram o preço (descida típica 4.2%)'),
    );
  });

  test('a listing up for over twice the usual time gets the hint', () {
    final lines = marketLines(market(gone: 6, toGone: 20), daysListed: 45);

    expect(lines.last, startsWith('Está à venda há mais do dobro'));
  });

  test('no hint without enough departures', () {
    final lines = marketLines(market(gone: 2, toGone: 5), daysListed: 45);

    expect(lines.any((l) => l.contains('margem')), isFalse);
  });
}
