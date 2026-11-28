/// The weekly check of the estimates and the Deal Score against the ads
/// that likely sold (N.61). Neither site says a bike was sold, so a gone
/// ad counts as a likely sale only when it did not expire, come back or
/// stay on the other site (`exit_kind`), or when its text said "vendida";
/// an ad only one run saw (`seen_once`, N.92) is no sale either.
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

  /// Gone ads only one run saw: how they left is unknown (N.92).
  required final int seenOnce,

  /// Likely sales with a known market position, and their median position
  /// (percent below the estimate; negative is above).
  required final int soldWithPosition,
  final double? soldPosition,

  /// The same for the model's live ads now.
  required final int liveWithPosition,
  final double? livePosition,

  /// Likely sales whose last price was 1 % or more below the highest seen,
  /// and their median drop (percent; null when none dropped).
  required final int soldDropped,
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
    seenOnce: _int(row['seen_once']),
    soldWithPosition: _int(row['sold_with_position']),
    soldPosition: _double(row['sold_position']),
    liveWithPosition: _int(row['live_with_position']),
    livePosition: _double(row['live_position']),
    soldDropped: _int(row['sold_dropped']),
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

/// From this share of a band's likely sales gone within a day of going
/// up, the report says good deals go faster than the collection (N.138).
const fastSaleShare = 0.25;

/// From this share of a band's ads seen by one run only, the report says
/// good deals go before the next run (N.138).
const seenOnceShare = 0.1;

/// How fast one Deal Score band's ads went (`score_check_speed`, N.138).
/// Hours are medians, counted from when the ad went up on the site.
class const SpeedCheck({
  required final String band,
  required final int ads,

  /// How long after going up the collection found them, and the slowest
  /// tenth.
  final double? foundHours,
  final double? foundP90Hours,

  /// Those put up from 00:00 to 08:00 Lisbon time, the longest gap
  /// between collections, and how long they waited.
  required final int nightAds,
  final double? nightFoundHours,

  /// Likely sales, those gone within a day, and how long they were up.
  required final int sales,
  required final int salesWithinDay,
  final double? saleHours,

  /// Ads only one run saw.
  required final int seenOnce,

  /// Ads with an alert, and when the first came.
  required final int alerted,
  final double? alertHours,
}) {
  factory SpeedCheck.fromRow(Map<String, dynamic> row) => SpeedCheck(
    band: row['band'] as String? ?? '?',
    ads: _int(row['ads']),
    foundHours: _double(row['found_hours']),
    foundP90Hours: _double(row['found_p90_hours']),
    nightAds: _int(row['night_ads']),
    nightFoundHours: _double(row['night_found_hours']),
    sales: _int(row['sales']),
    salesWithinDay: _int(row['sales_within_day']),
    saleHours: _double(row['sale_hours']),
    seenOnce: _int(row['seen_once']),
    alerted: _int(row['alerted']),
    alertHours: _double(row['alert_hours']),
  );

  /// The band's lowest score ('80-100' -> 80).
  int get floor => int.tryParse(band.split('-').first) ?? 0;
}

/// Whether the good deals (Deal Score 80+) go faster than the collection
/// finds them: many likely sales gone within a day of going up, or many
/// ads only one run saw, each from [minSalesToJudge].
List<String> speedFlags(List<SpeedCheck> speed) {
  final flags = <String>[];
  for (final s in speed) {
    if (s.floor < 80) continue;
    if (s.sales >= minSalesToJudge &&
        s.salesWithinDay >= fastSaleShare * s.sales) {
      final night = s.nightFoundHours;
      flags.add(
        'Good deals go fast: ${s.salesWithinDay} of ${s.sales} likely sales '
        'at Deal Score ${s.band} left within a day of going up; the '
        'collection found them after ${_hours(s.foundHours)} on the median'
        '${night == null ? '' : ' (${_hours(night)} when put up at night)'}. '
        'Collecting more often would find them sooner; that loosens the '
        "fetching rules, so it is Rafael's decision.",
      );
    }
    if (s.ads >= minSalesToJudge && s.seenOnce >= seenOnceShare * s.ads) {
      flags.add(
        '${s.seenOnce} of ${s.ads} ads at Deal Score ${s.band} were seen by '
        'one run only: they went before the next.',
      );
    }
  }
  return flags;
}

/// The Markdown report: per model how its ads left and where the likely
/// sales sat against the estimate, then the Deal Score bands, how fast
/// each band's ads went, then what looks off.
String scoreCheckReport({
  required List<ModelCheck> models,
  required List<BandCheck> bands,
  required int days,
  required int bandDays,
  required int horizon,
  List<SpeedCheck> speed = const [],
}) {
  final out = StringBuffer()
    ..writeln('## Estimates against likely sales')
    ..writeln()
    ..writeln(
      'Ads gone in the last $days days (not duplicates, 300 € or more). '
      'A likely sale: the text said so, or it did not expire (private '
      'ads, 30 days on the site), come back or stay on the other site, '
      'and more than one run saw it. '
      'Dropped: likely sales whose last price was 1 % or more below the '
      'highest seen, with their median drop. '
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
        'Still listed | Seen once | Sales position | Live position | Dropped | '
        'Days |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final m in models) {
      out.writeln(
        '| ${m.model} | ${m.gone} | ${m.sales} (${m.soldInText}) | '
        '${m.expired} | ${m.relisted} | ${m.stillListed} | ${m.seenOnce} | '
        '${_median(m.soldPosition, m.soldWithPosition)} | '
        '${_median(m.livePosition, m.liveWithPosition)} | '
        '${_dropped(m)} | '
        '${_value(m.soldDays, (d) => d.round().toString())} |',
      );
    }
    out.writeln();
  }

  out
    ..writeln('## Deal Score against sales')
    ..writeln()
    ..writeln(
      'Ads first seen between $bandDays and $horizon days ago, and not '
      'before 12 Nov 2026, when last Deal Scores began to be kept, by their '
      'last Deal Score: how many likely sold within $horizon days of being '
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

  out
    ..writeln('## How fast good deals go')
    ..writeln()
    ..writeln(
      'Ads found in the last $bandDays days (and not before 12 Nov 2026), '
      'a day ago or more, at most 2 days after they went up on the site, '
      'by their last Deal Score. Hours from when the ad went up: when the '
      'collection found it (median, and the slowest tenth), the same for '
      'ads put up from 00:00 to 08:00 Lisbon time (the longest gap between '
      'collections), how long the likely sales stayed up, how many of them '
      'left within a day, how many ads one run saw, and when the first '
      'alert came. If the best ads go within hours, the limit is how often '
      'the collection runs, not the scoring.',
    )
    ..writeln();
  if (speed.isEmpty) {
    out
      ..writeln('No scored ads found in the period.')
      ..writeln();
  } else {
    out
      ..writeln(
        '| Deal Score | Ads | Found after | Put up at night | Likely sold | '
        'Within a day | Up for | Seen once | Alerted | First alert |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final s in speed) {
      out.writeln(
        '| ${s.band} | ${s.ads} | ${_hours(s.foundHours)} '
        '(${_hours(s.foundP90Hours)}) | ${_night(s)} | ${s.sales} | '
        '${s.salesWithinDay} | ${_hours(s.saleHours)} | ${s.seenOnce} | '
        '${s.alerted} | ${_hours(s.alertHours)} |',
      );
    }
    out.writeln();
  }

  final flags = [
    for (final m in models) ?m.estimateFlag,
    ...bandFlags(bands),
    ...speedFlags(speed),
  ];
  out
    ..writeln('## To look at')
    ..writeln();
  if (flags.isEmpty) {
    out.writeln(
      'Nothing: no model with $minSalesToJudge+ likely sales is more '
      'than ${_pct(estimateTolerance)} off, the bands sell in order, and '
      'good deals do not go faster than the collection.',
    );
  } else {
    for (final f in flags) {
      out.writeln('- $f');
    }
  }
  return out.toString();
}

/// "2 of 8, -6.5 %": how many likely sales dropped, and by how much.
String _dropped(ModelCheck m) {
  if (m.sales == 0) return '–';
  final drop = m.soldDropPct;
  return '${m.soldDropped} of ${m.sales}'
      '${drop == null ? '' : ', -${_pct(drop)}'}';
}

/// "6.0 h", or days from 48 h ("3.5 d").
String _hours(double? hours) => switch (hours) {
  null => '–',
  final h when h >= 48 => '${(h / 24).toStringAsFixed(1)} d',
  final h => '${h.toStringAsFixed(1)} h',
};

/// "3 (6.0 h)": the ads put up at night and how long they waited.
String _night(SpeedCheck s) =>
    s.nightAds == 0 ? '0' : '${s.nightAds} (${_hours(s.nightFoundHours)})';

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
