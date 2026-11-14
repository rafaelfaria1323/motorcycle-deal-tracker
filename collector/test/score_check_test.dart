import 'package:collector/collector.dart';
import 'package:test/test.dart';

ModelCheck _model({
  String model = 'Yamaha MT-07',
  int withPosition = 6,
  double? position = 2.0,
}) => ModelCheck(
  model: model,
  gone: 12,
  soldInText: 1,
  likelySold: 7,
  relisted: 2,
  stillListed: 1,
  expired: 1,
  seenOnce: 3,
  soldWithPosition: withPosition,
  soldPosition: position,
  liveWithPosition: 20,
  livePosition: -1.5,
  soldDropped: 2,
  soldDropPct: 3.0,
  soldDays: 21.4,
);

void main() {
  test('reads the database rows, numbers as text or numbers', () {
    final m = ModelCheck.fromRow({
      'model': 'Honda CB650R',
      'gone': 9,
      'sold_in_text': 2,
      'likely_sold': 4,
      'relisted': 1,
      'still_listed': 1,
      'expired': 1,
      'seen_once': 4,
      'sold_with_position': 5,
      'sold_position': '-8.5',
      'live_with_position': 11,
      'live_position': 1.25,
      'sold_dropped': 0,
      'sold_drop_pct': null,
      'sold_days': 30,
    });
    expect(m.sales, 6);
    expect(m.seenOnce, 4);
    expect(m.soldPosition, -8.5);
    expect(m.livePosition, 1.25);
    expect(m.soldDropped, 0);
    expect(m.soldDropPct, isNull);
    expect(m.soldDays, 30.0);

    final b = BandCheck.fromRow({
      'band': '60-79',
      'ads': 10,
      'sold_within': 3,
      'share': 30.0,
    });
    expect(
      (b.band, b.ads, b.soldWithin, b.share, b.floor),
      ('60-79', 10, 3, 30.0, 60),
    );
  });

  test('flags an estimate the likely sales sit far from', () {
    expect(_model(position: -7.5).estimateFlag, contains('looks low'));
    expect(_model(position: 7.5).estimateFlag, contains('looks high'));
    expect(_model(position: 7.0).estimateFlag, isNull, reason: 'within');
    expect(_model(position: -7.0).estimateFlag, isNull);
    expect(
      _model(position: 20, withPosition: 4).estimateFlag,
      isNull,
      reason: 'too few sales',
    );
    expect(_model(position: null).estimateFlag, isNull);
  });

  test('flags bands that sell out of order', () {
    const top = BandCheck(band: '80-100', ads: 10, soldWithin: 2, share: 20);
    const mid = BandCheck(band: '60-79', ads: 20, soldWithin: 6, share: 30);
    const low = BandCheck(band: '0-39', ads: 8, soldWithin: 1, share: 12.5);
    expect(bandFlags([low, mid, top]), [
      'Deal Score 80-100 sold less often (20.0 %) than 60-79 (30.0 %).',
    ]);
    const fewTop = BandCheck(band: '80-100', ads: 4, soldWithin: 0, share: 0);
    expect(bandFlags([fewTop, mid, low]), isEmpty, reason: 'too few ads');
    const same = BandCheck(band: '80-100', ads: 10, soldWithin: 3, share: 30);
    expect(bandFlags([same, mid]), isEmpty, reason: 'equal is in order');
  });

  test('the report lists models, bands and what to look at', () {
    final report = scoreCheckReport(
      models: [
        _model(),
        _model(model: 'Honda CB650R', position: -9),
      ],
      bands: const [
        BandCheck(band: '80-100', ads: 10, soldWithin: 4, share: 40),
        BandCheck(band: '0-39', ads: 6, soldWithin: 3, share: 50),
      ],
      days: 28,
      bandDays: 60,
      horizon: 14,
    );
    expect(report, contains('Ads gone in the last 28 days'));
    expect(
      report,
      contains(
        '| Yamaha MT-07 | 12 | 8 (1) | 1 | 2 | 1 | 3 | +2.0 % (n=6) | '
        '-1.5 % (n=20) | 2 of 8, -3.0 % | 21 |',
      ),
    );
    expect(report, contains('between 60 and 14 days ago'));
    expect(report, contains('not before 12 Nov 2026'));
    expect(report, contains('| 80-100 | 10 | 4 | 40.0 % |'));
    expect(report, contains('- Honda CB650R: likely sales asked 9.0 % above'));
    expect(report, contains('- Deal Score 80-100 sold less often'));
    expect(report, isNot(contains('- Yamaha MT-07')));
  });

  test('an empty period says so', () {
    final report = scoreCheckReport(
      models: const [],
      bands: const [],
      days: 28,
      bandDays: 60,
      horizon: 14,
    );
    expect(report, contains('No ads left the market in the period.'));
    expect(report, contains('No scored ads in the period.'));
    expect(report, contains('Nothing: no model with 5+ likely sales'));
    expect(report, isNot(contains('|---|')));
  });

  test('sales that never dropped say so, not a 0 % median', () {
    const m = ModelCheck(
      model: 'Honda CB650R',
      gone: 6,
      soldInText: 0,
      likelySold: 5,
      relisted: 0,
      stillListed: 0,
      expired: 1,
      seenOnce: 0,
      soldWithPosition: 0,
      liveWithPosition: 0,
      soldDropped: 0,
    );
    final report = scoreCheckReport(
      models: const [m],
      bands: const [],
      days: 28,
      bandDays: 60,
      horizon: 14,
    );
    expect(report, contains('| – | – | 0 of 5 | – |'));
  });

  test('a missing figure shows a dash', () {
    final report = scoreCheckReport(
      models: [
        const ModelCheck(
          model: 'Honda CBR650R',
          gone: 1,
          soldInText: 0,
          likelySold: 0,
          relisted: 1,
          stillListed: 0,
          expired: 0,
          seenOnce: 0,
          soldWithPosition: 0,
          liveWithPosition: 0,
          soldDropped: 0,
        ),
      ],
      bands: const [BandCheck(band: '40-59', ads: 0, soldWithin: 0)],
      days: 7,
      bandDays: 30,
      horizon: 7,
    );
    expect(
      report,
      contains('| Honda CBR650R | 1 | 0 (0) | 0 | 1 | 0 | 0 | – | – | – | – |'),
    );
    expect(report, contains('| 40-59 | 0 | 0 | – |'));
  });
}
