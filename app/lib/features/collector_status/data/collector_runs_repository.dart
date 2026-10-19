import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/collector_run.dart';

abstract interface class CollectorRunsRepository {
  /// The most recent run, or null when there is none (or no access).
  Future<CollectorRun?> getLatest();
}

class SupabaseCollectorRunsRepository implements CollectorRunsRepository {
  SupabaseCollectorRunsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CollectorRun?> getLatest() async {
    final rows = await _client
        .from('collector_runs')
        .select('status, started_at, finished_at')
        .order('started_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;

    final row = rows.first;
    return CollectorRun(
      status: row['status'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      finishedAt: DateTime.parse(row['finished_at'] as String),
    );
  }
}
