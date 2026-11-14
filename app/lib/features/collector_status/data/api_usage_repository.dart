import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/api_usage.dart';

abstract interface class ApiUsageRepository {
  /// The outside APIs' requests (admins only), one entry per API.
  Future<List<ApiUsage>> get();
}

class SupabaseApiUsageRepository(final SupabaseClient _client)
    implements ApiUsageRepository {
  @override
  Future<List<ApiUsage>> get() async {
    final rows = await _client.rpc<List<dynamic>>('api_usage');
    return [for (final r in rows) ApiUsage.fromJson(r as Map<String, dynamic>)];
  }
}
