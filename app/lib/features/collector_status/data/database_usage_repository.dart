import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/database_usage.dart';

abstract interface class DatabaseUsageRepository {
  /// The database's size now (admins only).
  Future<DatabaseUsage> get();
}

class SupabaseDatabaseUsageRepository(final SupabaseClient _client)
    implements DatabaseUsageRepository {
  @override
  Future<DatabaseUsage> get() async {
    final json = await _client.rpc<Object?>('database_usage');
    return DatabaseUsage.fromJson(json! as Map<String, dynamic>);
  }
}
