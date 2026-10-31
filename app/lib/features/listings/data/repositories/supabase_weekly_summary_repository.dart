import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/weekly_summary.dart';
import '../../domain/repositories/weekly_summary_repository.dart';
import '../models/weekly_summary_model.dart';

class SupabaseWeeklySummaryRepository(final SupabaseClient _client)
    implements WeeklySummaryRepository {
  @override
  Future<WeeklySummary?> getLatest() async {
    // Row-level security returns only the current account's summary.
    final row = await _client
        .from('weekly_summaries')
        .select(WeeklySummaryModel.columns)
        .maybeSingle();
    return row == null ? null : WeeklySummaryModel.fromJson(row);
  }
}
