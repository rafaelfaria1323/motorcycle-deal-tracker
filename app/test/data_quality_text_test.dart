import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/source_quality.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/data_quality_text.dart';

SourceQuality quality({
  String source = 'olx',
  int live = 120,
  int unmatched = 0,
  int duplicates = 0,
  int scored = 100,
  int year = 0,
  int mileage = 0,
  int location = 0,
  int pending = 0,
  DateTime? seen,
  int sharp = 0,
}) => SourceQuality(
  source: source,
  liveCount: live,
  unmatchedCount: unmatched,
  duplicateCount: duplicates,
  scoredCount: scored,
  missingYear: year,
  missingMileage: mileage,
  missingLocation: location,
  detailsPending: pending,
  lastSeenAt: seen,
  sharpPriceChanges: sharp,
);

void main() {
  test('percent rounds, keeps small shares visible and survives zero', () {
    expect(percent(12, 100), '12 %');
    expect(percent(1, 3), '33 %');
    expect(percent(1, 200), '<1 %');
    expect(percent(0, 10), '0 %');
    expect(percent(3, 0), '0 %');
    expect(percent(-1, 10), '0 %');
    expect(percent(3, -3), '0 %');
  });

  test('the title names the site and its live listings', () {
    expect(qualityTitle(quality()), 'OLX · 120 anúncios ativos');
    expect(
      qualityTitle(quality(source: 'standvirtual', live: 1)),
      'Standvirtual · 1 anúncio ativo',
    );
  });

  test('the mix line shows only what is there', () {
    expect(qualityMixLine(quality()), '100 dos modelos acompanhados');
    expect(
      qualityMixLine(quality(unmatched: 18, duplicates: 2)),
      '100 dos modelos acompanhados · 18 sem modelo (15 %) · '
      '2 duplicados (2 %)',
    );
    expect(
      qualityMixLine(quality(duplicates: 1)),
      '100 dos modelos acompanhados · 1 duplicado (<1 %)',
    );
  });

  test('missing facts are shares of the scored listings', () {
    expect(qualityMissingLine(quality()), isNull);
    expect(
      qualityMissingLine(quality(year: 2, mileage: 5, location: 1)),
      'Em falta: ano 2 % · km 5 % · localização 1 %',
    );
  });

  test('pending listing pages', () {
    expect(qualityDetailsLine(quality()), isNull);
    expect(
      qualityDetailsLine(quality(pending: 1)),
      '1 página de anúncio por ler',
    );
    expect(
      qualityDetailsLine(quality(pending: 12)),
      '12 páginas de anúncio por ler',
    );
  });

  test('when the site\'s listings were last seen, stale after a day', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    expect(qualitySeenLine(quality(), now), isNull);
    expect(
      qualitySeenLine(
        quality(seen: now.subtract(const Duration(hours: 3))),
        now,
      ),
      'Último anúncio visto no site há 3 h',
    );
    expect(
      qualitySeenLine(quality(seen: now.subtract(staleAfter)), now),
      'Último anúncio visto no site há 24 h',
    );
    expect(
      qualitySeenLine(
        quality(seen: now.subtract(const Duration(hours: 24, minutes: 1))),
        now,
      ),
      'Nenhum anúncio visto no site há 24 h: verifique a recolha',
    );
    expect(
      qualitySeenLine(
        quality(seen: now.subtract(const Duration(days: 3))),
        now,
      ),
      'Nenhum anúncio visto no site há 3 dias: verifique a recolha',
    );
  });

  test('sudden price changes', () {
    expect(qualitySharpPricesLine(quality()), isNull);
    expect(
      qualitySharpPricesLine(quality(sharp: 1)),
      '1 anúncio com o preço alterado em 50 % ou mais de uma só vez nos '
      'últimos 30 dias (possível erro de leitura)',
    );
    expect(
      qualitySharpPricesLine(quality(sharp: 3)),
      startsWith('3 anúncios com o preço alterado'),
    );
  });

  test('reads the view row', () {
    final q = SourceQuality.fromJson({
      'source': 'standvirtual',
      'live_count': 40,
      'unmatched_count': 3,
      'duplicate_count': 1,
      'scored_count': 36,
      'missing_year': 0,
      'missing_mileage': 2,
      'missing_location': null,
      'details_pending': 4,
      'last_seen_at': '2026-10-20T09:00:00+00:00',
      'sharp_price_changes': 2,
    });
    expect(
      q,
      quality(
        source: 'standvirtual',
        live: 40,
        unmatched: 3,
        duplicates: 1,
        scored: 36,
        mileage: 2,
        pending: 4,
        seen: DateTime.utc(2026, 10, 20, 9),
        sharp: 2,
      ),
    );
  });

  test('a view without the newer columns still reads', () {
    final q = SourceQuality.fromJson({'source': 'olx', 'live_count': 3});
    expect(q.lastSeenAt, isNull);
    expect(q.sharpPriceChanges, 0);
  });
}
