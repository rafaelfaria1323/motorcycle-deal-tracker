import '../../../core/formatting/formatters.dart';
import '../domain/entities/dealer_reliability.dart';

/// Below this many bikes the figures say little about a dealer.
const minDealerBikes = 5;

/// "Motos Lda: 12 motas vistas desde 21/08/2026 (5 à venda)".
String dealerHeadline(DealerReliability d) {
  final since = d.firstSeenAt;
  return '${d.name}: ${d.bikes} ${d.bikes == 1 ? 'mota vista' : 'motas vistas'}'
      '${since == null ? '' : ' desde ${Formatters.date(since)}'} '
      '(${d.live} à venda)';
}

/// One line per warning sign found in the dealer's ads, then how often it
/// lowered its prices; a reassuring line when there are no warning signs.
List<String> dealerLines(DealerReliability d) {
  String share(int n) => '$n de ${d.bikes}';
  final warnings = [
    if (d.relisted > 0)
      '${share(d.relisted)} publicadas de novo depois de o anúncio sair',
    if (d.sharpChanges > 0)
      '${share(d.sharpChanges)} com mudanças de preço bruscas '
          '(50 % ou mais de uma vez)',
    if (d.missingMileage > 0) '${share(d.missingMileage)} sem quilómetros',
    if (d.repeated > 0)
      '${d.repeated} ${d.repeated == 1 ? 'anúncio repetido' : 'anúncios repetidos'} '
          'da mesma mota usada no mesmo site',
  ];
  return [
    if (warnings.isEmpty) 'Sem sinais de alerta nos anúncios deste stand',
    ...warnings,
    d.dropped == 0
        ? 'Ainda não baixou o preço de nenhuma mota'
        : 'Baixou o preço de ${share(d.dropped)}',
    if (d.bikes < minDealerBikes)
      'Ainda poucos dados sobre este stand (menos de $minDealerBikes motas)',
  ];
}
