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
    this.runUrl,
  });

  /// 'ok', 'blocked' or 'failed'.
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

  /// The GitHub Actions run's page.
  final String? runUrl;

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
    runUrl,
  ];
}

/// One site's requests used today (UTC day) out of its daily limit, and
/// until when it is paused after the site pushed back.
class SiteBudget extends Equatable {
  const SiteBudget({
    required this.requestsToday,
    required this.dailyLimit,
    this.pausedUntil,
  });

  factory SiteBudget.fromJson(Map<String, dynamic> json) => SiteBudget(
    requestsToday: (json['requests_today'] as num?)?.toInt() ?? 0,
    dailyLimit: (json['daily_limit'] as num?)?.toInt() ?? 120,
    pausedUntil: json['paused_until'] == null
        ? null
        : DateTime.parse(json['paused_until'] as String),
  );

  final int requestsToday;
  final int dailyLimit;
  final DateTime? pausedUntil;

  @override
  List<Object?> get props => [requestsToday, dailyLimit, pausedUntil];
}

enum CollectorHealth { unknown, ok, stale, blocked, failed }

/// What the dashboard should say about data freshness.
CollectorHealth collectorHealth(
  CollectorRun? run,
  DateTime now, {
  Duration maxAge = const Duration(hours: 12),
}) {
  if (run == null) return CollectorHealth.unknown;
  if (run.status == 'blocked') return CollectorHealth.blocked;
  if (run.status != 'ok') return CollectorHealth.failed;
  if (now.difference(run.finishedAt) > maxAge) return CollectorHealth.stale;
  return CollectorHealth.ok;
}
