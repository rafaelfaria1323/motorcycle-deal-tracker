import '../domain/entities/market_behaviour.dart';

/// Below this many listings a figure is not shown as a fact.
const minMarketData = 5;

List<String> marketLines(MarketBehaviour m, {int? daysListed}) {
  final lines = <String>[
    '${m.liveCount} ${m.liveCount == 1 ? 'anúncio ativo' : 'anúncios ativos'} '
        'deste modelo',
  ];

  final toGone = m.medianDaysToGone;
  final enoughGone = m.goneCount >= minMarketData && toGone != null;
  if (enoughGone) {
    lines.add(
      'Tempo típico até sair do mercado: $toGone dias '
      '(${m.goneCount} anúncios)',
    );
  } else {
    lines.add(
      'Tempo até sair do mercado: ainda poucos dados '
      '(${m.goneCount} ${m.goneCount == 1 ? 'anúncio saiu' : 'anúncios saíram'})',
    );
  }

  if (m.pricedCount >= minMarketData) {
    if (m.droppedCount == 0) {
      lines.add('Nenhum vendedor baixou o preço desde que acompanhamos');
    } else {
      final share = (m.droppedCount * 100 / m.pricedCount).round();
      final drop = m.medianDropPct;
      lines.add(
        drop == null
            ? '$share% dos vendedores baixaram o preço'
            : '$share% dos vendedores baixaram o preço '
                  '(descida típica ${drop.toStringAsFixed(1)}%)',
      );
    }
  }

  if (daysListed != null) {
    lines.add(
      daysListed <= 0
          ? 'Este anúncio foi publicado hoje'
          : 'Este anúncio está publicado há $daysListed '
                '${daysListed == 1 ? 'dia' : 'dias'}',
    );
    if (enoughGone && daysListed > 2 * toGone) {
      lines.add(
        'Está à venda há mais do dobro do tempo habitual: '
        'pode haver margem para negociar',
      );
    }
  }
  return lines;
}
