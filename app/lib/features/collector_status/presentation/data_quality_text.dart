import '../../listings/presentation/listing_labels.dart';
import '../domain/source_quality.dart';
import 'collection_text.dart';

/// "OLX · 120 anúncios ativos"
String qualityTitle(SourceQuality q) =>
    '${sourceLabel(q.source)} · ${q.liveCount} '
    '${q.liveCount == 1 ? 'anúncio ativo' : 'anúncios ativos'}';

/// What the site's live listings are: tracked, other models, duplicates.
String qualityMixLine(SourceQuality q) {
  final parts = [
    '${q.scoredCount} dos modelos acompanhados',
    if (q.unmatchedCount > 0)
      '${q.unmatchedCount} sem modelo (${percent(q.unmatchedCount, q.liveCount)})',
    if (q.duplicateCount > 0)
      '${q.duplicateCount} '
          '${q.duplicateCount == 1 ? 'duplicado' : 'duplicados'} '
          '(${percent(q.duplicateCount, q.liveCount)})',
  ];
  return parts.join(' · ');
}

/// The facts the scored listings miss; null when none is missing.
String? qualityMissingLine(SourceQuality q) {
  final parts = [
    if (q.missingYear > 0) 'ano ${percent(q.missingYear, q.scoredCount)}',
    if (q.missingMileage > 0) 'km ${percent(q.missingMileage, q.scoredCount)}',
    if (q.missingLocation > 0)
      'localização ${percent(q.missingLocation, q.scoredCount)}',
  ];
  if (parts.isEmpty) return null;
  return 'Em falta: ${parts.join(' · ')}';
}

/// Null when every listing page has been read.
String? qualityDetailsLine(SourceQuality q) {
  if (q.detailsPending == 0) return null;
  return q.detailsPending == 1
      ? '1 página de anúncio por ler'
      : '${q.detailsPending} páginas de anúncio por ler';
}

/// Collections run every 4 hours; a day without seeing any listing means
/// the site stopped answering or the collection stopped.
const staleAfter = Duration(hours: 24);

/// When the site's listings were last seen; null before the view had it.
String? qualitySeenLine(SourceQuality q, DateTime now) {
  final seen = q.lastSeenAt;
  if (seen == null) return null;
  final ago = agoText(seen, now: now);
  if (now.difference(seen) > staleAfter) {
    return 'Nenhum anúncio visto no site $ago: verifique a recolha';
  }
  return 'Último anúncio visto no site $ago';
}

/// Null when no price moved by half or more at once.
String? qualitySharpPricesLine(SourceQuality q) {
  final n = q.sharpPriceChanges;
  if (n == 0) return null;
  return '${n == 1 ? '1 anúncio' : '$n anúncios'} com o preço alterado em '
      '50 % ou mais de uma só vez nos últimos 30 dias (possível erro de '
      'leitura)';
}

/// "12 %", rounded; "<1 %" for a small non-zero share.
String percent(int part, int whole) {
  if (whole <= 0 || part <= 0) return '0 %';
  final value = part * 100 / whole;
  if (value < 1) return '<1 %';
  return '${value.round()} %';
}
