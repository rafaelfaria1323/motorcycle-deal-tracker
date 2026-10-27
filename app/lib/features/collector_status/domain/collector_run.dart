import 'package:equatable/equatable.dart';

class CollectorRun extends Equatable {
  const CollectorRun({
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    this.requests = const {},
    this.counts = const {},
    this.problems = const [],
    this.sites = const {},
    this.searches = const [],
    this.runUrl,
    this.scoringTime,
  });

  /// 'ok', 'partial' (only a site's passing fetch failure: the rest was
  /// read and scored), 'blocked' or 'failed'.
  final String status;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// Requests each site used ({'standvirtual': 15, 'olx': 9}).
  final Map<String, int> requests;

  /// What the run did, over both sites ({'new': 3, 'price_changes': 2,
  /// 'removed': 1, 'alerts': 4}); empty for older runs.
  final Map<String, int> counts;

  /// What went wrong in a run that was not ok, one line per error.
  final List<String> problems;

  /// Each site's budget and pause after the run; empty for older runs.
  final Map<String, SiteBudget> sites;

  /// What each search cost and gave, in the order read; empty for older
  /// runs.
  final List<SearchRead> searches;

  /// The GitHub Actions run's page.
  final String? runUrl;

  /// How long the scores took to work out; null for older runs or one that
  /// stopped before them.
  final Duration? scoringTime;

  Duration get duration => finishedAt.difference(startedAt);

  @override
  List<Object?> get props => [
    status,
    startedAt,
    finishedAt,
    requests,
    counts,
    problems,
    sites,
    searches,
    runUrl,
    scoringTime,
  ];
}

/// One search in a run: the pages read of the [spans] the site said it has
/// (null when its first page wasn't read), the ads found, how many are a
/// followed model, and whether it was read in full (only then are its
/// missing ads marked as gone).
class SearchRead extends Equatable {
  const SearchRead({
    required this.site,
    required this.search,
    required this.pages,
    required this.spans,
    required this.ads,
    required this.followed,
    required this.inFull,
  });

  factory SearchRead.fromJson(Map<String, dynamic> json) => SearchRead(
    site: json['site'] as String? ?? '',
    search: json['search'] as String? ?? '',
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    spans: (json['spans'] as num?)?.toInt(),
    ads: (json['ads'] as num?)?.toInt() ?? 0,
    followed: (json['followed'] as num?)?.toInt() ?? 0,
    inFull: json['in_full'] as bool? ?? false,
  );

  final String site;

  /// Its models ("yamaha-mt-07, yamaha-r7"), or its address.
  final String search;
  final int pages;
  final int? spans;
  final int ads;
  final int followed;
  final bool inFull;

  @override
  List<Object?> get props => [
    site,
    search,
    pages,
    spans,
    ads,
    followed,
    inFull,
  ];
}

/// One site's requests used today (UTC day), and until when it is paused
/// after the site pushed back. (Older runs also sent a `daily_limit`; the
/// caps are gone, so it is ignored.)
class SiteBudget extends Equatable {
  const SiteBudget({required this.requestsToday, this.pausedUntil});

  factory SiteBudget.fromJson(Map<String, dynamic> json) => SiteBudget(
    requestsToday: (json['requests_today'] as num?)?.toInt() ?? 0,
    pausedUntil: json['paused_until'] == null
        ? null
        : DateTime.parse(json['paused_until'] as String),
  );

  final int requestsToday;
  final DateTime? pausedUntil;

  @override
  List<Object?> get props => [requestsToday, pausedUntil];
}

enum CollectorHealth { unknown, ok, stale, blocked, failed }

/// What the dashboard should say about data freshness. A partial run is
/// fine here: its lost search is read again by the next run, and the
/// admins hear of it when the same site fails twice in a row.
CollectorHealth collectorHealth(
  CollectorRun? run,
  DateTime now, {
  Duration maxAge = const Duration(hours: 12),
}) {
  if (run == null) return CollectorHealth.unknown;
  if (run.status == 'blocked') return CollectorHealth.blocked;
  if (run.status != 'ok' && run.status != 'partial') {
    return CollectorHealth.failed;
  }
  if (now.difference(run.finishedAt) > maxAge) return CollectorHealth.stale;
  return CollectorHealth.ok;
}
