import 'package:equatable/equatable.dart';

class CollectorRun extends Equatable {
  const CollectorRun({
    required this.status,
    required this.startedAt,
    required this.finishedAt,
  });

  /// 'ok', 'blocked' or 'failed'.
  final String status;
  final DateTime startedAt;
  final DateTime finishedAt;

  @override
  List<Object?> get props => [status, startedAt, finishedAt];
}

enum CollectorHealth { unknown, ok, stale, blocked, failed }

/// What the dashboard should say about data freshness.
CollectorHealth collectorHealth(
  CollectorRun? run,
  DateTime now, {
  Duration maxAge = const Duration(hours: 36),
}) {
  if (run == null) return CollectorHealth.unknown;
  if (run.status == 'blocked') return CollectorHealth.blocked;
  if (run.status != 'ok') return CollectorHealth.failed;
  if (now.difference(run.finishedAt) > maxAge) return CollectorHealth.stale;
  return CollectorHealth.ok;
}
