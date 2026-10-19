import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/collector_run.dart';

abstract interface class CollectorRunsRepository {
  /// The most recent run, or null when there is none (or no access).
  Future<CollectorRun?> getLatest();

  /// The runs started since [since], newest first; empty without access.
  Future<List<CollectorRun>> getSince(DateTime since);
}

class SupabaseCollectorRunsRepository implements CollectorRunsRepository {
  SupabaseCollectorRunsRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'status, started_at, finished_at, requests';

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
  Future<List<CollectorRun>> getSince(DateTime since) async {
    final rows = await _client
        .from('collector_runs')
        .select(_columns)
        .gte('started_at', since.toUtc().toIso8601String())
        .order('started_at', ascending: false);
    return rows.map(_run).toList();
  }

  static CollectorRun _run(Map<String, dynamic> row) => CollectorRun(
    status: row['status'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    finishedAt: DateTime.parse(row['finished_at'] as String),
    requests: {
      for (final MapEntry(:key, :value)
          in (row['requests'] as Map<String, dynamic>? ?? const {}).entries)
        if (value is num) key: value.toInt(),
    },
  );
}
