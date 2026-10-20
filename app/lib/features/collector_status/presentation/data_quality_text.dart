import '../../listings/presentation/listing_labels.dart';
import '../domain/source_quality.dart';

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

/// "12 %", rounded; "<1 %" for a small non-zero share.
String percent(int part, int whole) {
  if (whole <= 0 || part <= 0) return '0 %';
  final value = part * 100 / whole;
  if (value < 1) return '<1 %';
  return '${value.round()} %';
}
