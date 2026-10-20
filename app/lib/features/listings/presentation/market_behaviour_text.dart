import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/market_behaviour.dart';

/// Below this many listings a figure is not shown as a fact.
const minMarketData = 5;

/// Listings a model needs before its own depreciation is fitted (the same
/// threshold as the model_depreciation view).
const minDepreciationData = 30;

/// [daysListed] counts from the site's publication date, or from the day
/// the collector first saw the listing when the site gave none
/// ([firstSeenOnly]); then the line says so instead of "publicado".
List<String> marketLines(
  MarketBehaviour m, {
  int? daysListed,
  bool firstSeenOnly = false,
}) {
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
      lines.add(
        'Nenhum vendedor baixou o preço desde que acompanhamos este modelo',
      );
    } else {
      final share = (m.droppedCount * 100 / m.pricedCount).round();
      final drop = m.medianDropPct;
      lines.add(
        drop == null
            ? '${Formatters.percent(share)} dos vendedores baixaram o preço'
            : '${Formatters.percent(share)} dos vendedores baixaram o preço '
                  '(descida típica ${Formatters.percent(drop, decimals: 1)})',
      );
    }
  }

  final depreciation = m.depreciation;
  if (depreciation != null) lines.add(depreciationLine(depreciation));

  if (daysListed != null) {
    lines.add(switch ((daysListed <= 0, firstSeenOnly)) {
      (true, false) => 'Este anúncio foi publicado hoje',
      (true, true) => 'Visto pela primeira vez hoje',
      (false, false) =>
        'Este anúncio está publicado há $daysListed '
            '${daysListed == 1 ? 'dia' : 'dias'}',
      (false, true) =>
        'Visto pela primeira vez há $daysListed '
            '${daysListed == 1 ? 'dia' : 'dias'}',
    });
    if (enoughGone && daysListed > 2 * toGone) {
      lines.add(
        'Está à venda há mais do dobro do tempo habitual: '
        'pode haver margem para negociar',
      );
    }
  }
  return lines;
}

/// The yearly and per-10 000 km loss in value, as percentages of the price.
String depreciationLine(Depreciation d) {
  String pct(double rate) =>
      Formatters.percent((1 - exp(-rate)) * 100, decimals: 1);
  final rates =
      '${pct(d.perYear)} por ano e ${pct(d.per1000Km * 10)} por 10 000 km';

  return d.isFitted
      ? 'Desvalorização deste modelo: $rates (${d.sampleCount} anúncios)'
      : 'Desvalorização: ainda poucos dados (${d.sampleCount} de '
            '$minDepreciationData anúncios); usa-se a regra geral de $rates';
}
