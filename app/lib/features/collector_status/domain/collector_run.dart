import 'package:equatable/equatable.dart';

class CollectorRun extends Equatable {
  const CollectorRun({
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    this.requests = const {},
  });

  /// 'ok', 'blocked' or 'failed'.
  final String status;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// Requests each site used ({'standvirtual': 15, 'olx': 9}).
  final Map<String, int> requests;

  Duration get duration => finishedAt.difference(startedAt);

  @override
  List<Object?> get props => [status, startedAt, finishedAt, requests];
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
