import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/market/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/market/presentation/market_behaviour_text.dart';

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
      contains('25 % dos vendedores baixaram o preço (descida típica 4,2 %)'),
    );
  });

  test('the age line says publicado only with the site\'s date', () {
    expect(
      marketLines(market(), daysListed: 0).last,
      'Este anúncio foi publicado hoje',
    );
    expect(
      marketLines(market(), daysListed: 3).last,
      'Este anúncio está publicado há 3 dias',
    );
    expect(
      marketLines(market(), daysListed: 0, firstSeenOnly: true).last,
      'Visto pela primeira vez hoje',
    );
    expect(
      marketLines(market(), daysListed: 1, firstSeenOnly: true).last,
      'Visto pela primeira vez há 1 dia',
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

  test('a fitted model shows its own depreciation', () {
    final line = depreciationLine(
      const Depreciation(
        sampleCount: 64,
        isFitted: true,
        perYear: 0.05235,
        per1000Km: 0.002771,
      ),
    );

    expect(
      line,
      'Desvalorização deste modelo: 5,1 % por ano e 2,7 % por 10 000 km '
      '(64 anúncios)',
    );
  });

  test('a model with few listings says the general rates apply', () {
    final line = depreciationLine(
      const Depreciation(
        sampleCount: 12,
        isFitted: false,
        perYear: 0.04,
        per1000Km: 0.002,
      ),
    );

    expect(
      line,
      'Desvalorização: ainda poucos dados (12 de 30 anúncios); '
      'usa-se a regra geral de 3,9 % por ano e 2,0 % por 10 000 km',
    );
  });

  test('the depreciation line comes before the days listed', () {
    final lines = marketLines(
      const MarketBehaviour(
        liveCount: 40,
        goneCount: 0,
        pricedCount: 0,
        droppedCount: 0,
        depreciation: Depreciation(
          sampleCount: 40,
          isFitted: true,
          perYear: 0.05,
          per1000Km: 0.003,
        ),
      ),
      daysListed: 3,
    );

    expect(lines[lines.length - 2], startsWith('Desvalorização deste modelo'));
  });
}
