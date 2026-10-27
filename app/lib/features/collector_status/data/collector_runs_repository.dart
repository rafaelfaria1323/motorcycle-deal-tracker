import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/collector_run.dart';

abstract interface class CollectorRunsRepository {
  /// The most recent run, or null when there is none (or no access).
  Future<CollectorRun?> getLatest();

  /// The runs started since [since] with their problems, newest first;
  /// empty without access.
  Future<List<CollectorRun>> getSince(DateTime since);

  /// The last [limit] runs with their problems, sites and searches, newest
  /// first.
  Future<List<CollectorRun>> getRecent(int limit);
}

class SupabaseCollectorRunsRepository implements CollectorRunsRepository {
  SupabaseCollectorRunsRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'status, started_at, finished_at, requests, counts, scoring_ms';

  @override
  Future<CollectorRun?> getLatest() async {
    final rows = await _client
        .from('collector_runs')
        .select(_columns)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : _run(rows.first);
  }

  @override
  Future<List<CollectorRun>> getRecent(int limit) async {
    final rows = await _client
        .from('collector_runs')
        .select('$_columns, problems, sites, searches, run_url')
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map(_run).toList();
  }

  @override
  Future<List<CollectorRun>> getSince(DateTime since) async {
    final rows = await _client
        .from('collector_runs')
        .select('$_columns, problems')
        .gte('started_at', since.toUtc().toIso8601String())
        .order('started_at', ascending: false);
    return rows.map(_run).toList();
  }

  static CollectorRun _run(Map<String, dynamic> row) => CollectorRun(
    status: row['status'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    finishedAt: DateTime.parse(row['finished_at'] as String),
    requests: _ints(row['requests']),
    counts: _ints(row['counts']),
    problems: [
      for (final p in row['problems'] as List<dynamic>? ?? const []) '$p',
    ],
    sites: {
      for (final MapEntry(:key, :value)
          in (row['sites'] as Map<String, dynamic>? ?? const {}).entries)
        if (value is Map<String, dynamic>) key: SiteBudget.fromJson(value),
    },
    searches: [
      for (final s in row['searches'] as List<dynamic>? ?? const [])
        if (s is Map<String, dynamic>) SearchRead.fromJson(s),
    ],
    runUrl: row['run_url'] as String?,
    scoringTime: switch (row['scoring_ms']) {
      final num ms => Duration(milliseconds: ms.toInt()),
      _ => null,
    },
  );

  static Map<String, int> _ints(Object? json) => {
    for (final MapEntry(:key, :value)
        in (json as Map<String, dynamic>? ?? const {}).entries)
      if (value is num) key: value.toInt(),
  };
}
