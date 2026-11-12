/// The weekly check of the estimates and the Deal Score against the ads
/// that likely sold (N.61). Neither site says a bike was sold, so a gone
/// ad counts as a likely sale only when it did not expire, come back or
/// stay on the other site (`exit_kind`), or when its text said "vendida".
/// A report for deciding by hand; it changes nothing and feeds no score.
library;

/// Below this many likely sales a model's figures are only listed.
const minSalesToJudge = 5;

/// A model's likely sales sat this far (percent) from the estimate, on the
/// median, before the report flags the estimate.
const estimateTolerance = 7.0;

/// One model's gone ads in the period (`score_check_models`).
class const ModelCheck({
  required final String model,
  required final int gone,
  required final int soldInText,
  required final int likelySold,
  required final int relisted,
  required final int stillListed,
  required final int expired,

  /// Likely sales with a known market position, and their median position
  /// (percent below the estimate; negative is above).
  required final int soldWithPosition,
  final double? soldPosition,

  /// The same for the model's live ads now.
  required final int liveWithPosition,
  final double? livePosition,

  /// Median drop from the highest price seen, percent, of the likely sales.
  final double? soldDropPct,

  /// Median days on sale of the likely sales.
  final double? soldDays,
}) {
  factory ModelCheck.fromRow(Map<String, dynamic> row) => ModelCheck(
    model: row['model'] as String? ?? '?',
    gone: _int(row['gone']),
    soldInText: _int(row['sold_in_text']),
    likelySold: _int(row['likely_sold']),
    relisted: _int(row['relisted']),
    stillListed: _int(row['still_listed']),
    expired: _int(row['expired']),
    soldWithPosition: _int(row['sold_with_position']),
    soldPosition: _double(row['sold_position']),
    liveWithPosition: _int(row['live_with_position']),
    livePosition: _double(row['live_position']),
    soldDropPct: _double(row['sold_drop_pct']),
    soldDays: _double(row['sold_days']),
  );

  /// Ads that likely sold: said so in the text, or nothing else explains
  /// why they left.
  int get sales => soldInText + likelySold;

  /// Why the estimate looks off for this model, or null: the likely sales
  /// asked, on the median, more than [estimateTolerance] % above the
  /// estimate (it is too low) or below it (too high), from
  /// [minSalesToJudge] sales with a position.
  String? get estimateFlag {
    final position = soldPosition;
    if (position == null || soldWithPosition < minSalesToJudge) return null;
    if (position < -estimateTolerance) {
      return '$model: likely sales asked ${_pct(-position)} above the '
          'estimate on the median; the estimate looks low.';
    }
    if (position > estimateTolerance) {
      return '$model: likely sales asked ${_pct(position)} below the '
          'estimate on the median; the estimate looks high.';
    }
    return null;
  }
}

/// One Deal Score band's ads and how many sold within the horizon
/// (`score_check_bands`).
class const BandCheck({
  required final String band,
  required final int ads,
  required final int soldWithin,
  final double? share,
}) {
  factory BandCheck.fromRow(Map<String, dynamic> row) => BandCheck(
    band: row['band'] as String? ?? '?',
    ads: _int(row['ads']),
    soldWithin: _int(row['sold_within']),
    share: _double(row['share']),
  );

  /// The band's lowest score ('80-100' -> 80).
  int get floor => int.tryParse(band.split('-').first) ?? 0;
}

/// Where the bands are out of order: a higher Deal Score band whose ads
/// sold within the horizon less often than a lower band's, each from
/// [minSalesToJudge] ads. Higher scores should sell sooner.
List<String> bandFlags(List<BandCheck> bands) {
  final judged = [
    for (final b in bands)
      if (b.ads >= minSalesToJudge && b.share != null) b,
  ]..sort((a, b) => b.floor.compareTo(a.floor));
  return [
    for (var i = 0; i + 1 < judged.length; i++)
      if (judged[i].share! < judged[i + 1].share!)
        'Deal Score ${judged[i].band} sold less often '
            '(${_pct(judged[i].share!)}) than ${judged[i + 1].band} '
            '(${_pct(judged[i + 1].share!)}).',
  ];
}

/// The Markdown report: per model how its ads left and where the likely
/// sales sat against the estimate, then the Deal Score bands, then what
/// looks off.
String scoreCheckReport({
  required List<ModelCheck> models,
  required List<BandCheck> bands,
  required int days,
  required int bandDays,
  required int horizon,
}) {
  final out = StringBuffer()
    ..writeln('## Estimates against likely sales')
    ..writeln()
    ..writeln(
      'Ads gone in the last $days days (not duplicates, 300 € or more). '
      'A likely sale: the text said so, or it did not expire (private '
      'ads, 30 days on the site), come back or stay on the other site. '
      'Position: percent below the estimate when last seen (damaged and '
      'unlegalised bikes left out); negative is above it.',
    )
    ..writeln();
  if (models.isEmpty) {
    out
      ..writeln('No ads left the market in the period.')
      ..writeln();
  } else {
    out
      ..writeln(
        '| Model | Gone | Likely sold (text) | Expired | Relisted | '
        'Still listed | Sales position | Live position | Drop | Days |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final m in models) {
      out.writeln(
        '| ${m.model} | ${m.gone} | ${m.sales} (${m.soldInText}) | '
        '${m.expired} | ${m.relisted} | ${m.stillListed} | '
        '${_median(m.soldPosition, m.soldWithPosition)} | '
        '${_median(m.livePosition, m.liveWithPosition)} | '
        '${_value(m.soldDropPct, _pct)} | '
        '${_value(m.soldDays, (d) => d.round().toString())} |',
      );
    }
    out.writeln();
  }

  out
    ..writeln('## Deal Score against sales')
    ..writeln()
    ..writeln(
      'Ads first seen between $bandDays and $horizon days ago, by their last '
      'Deal Score: how many likely sold within $horizon days of being '
      'found.',
    )
    ..writeln();
  if (bands.isEmpty) {
    out
      ..writeln('No scored ads in the period.')
      ..writeln();
  } else {
    out
      ..writeln('| Deal Score | Ads | Sold within $horizon days | Share |')
      ..writeln('|---|---:|---:|---:|');
    for (final b in bands) {
      out.writeln(
        '| ${b.band} | ${b.ads} | ${b.soldWithin} | '
        '${_value(b.share, _pct)} |',
      );
    }
    out.writeln();
  }

  final flags = [for (final m in models) ?m.estimateFlag, ...bandFlags(bands)];
  out
    ..writeln('## To look at')
    ..writeln();
  if (flags.isEmpty) {
    out.writeln(
      'Nothing: no model with $minSalesToJudge+ likely sales is more '
      'than ${_pct(estimateTolerance)} off, and the bands sell in order.',
    );
  } else {
    for (final f in flags) {
      out.writeln('- $f');
    }
  }
  return out.toString();
}

String _median(double? value, int count) =>
    value == null ? '–' : '${_signed(value)} (n=$count)';

String _value(double? value, String Function(double) format) =>
    value == null ? '–' : format(value);

String _pct(double value) => '${value.toStringAsFixed(1)} %';

String _signed(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)} %';

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

double? _double(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};
