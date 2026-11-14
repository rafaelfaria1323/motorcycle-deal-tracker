import 'package:supabase/supabase.dart';

/// An outside API whose requests are counted (N.101); the names are the
/// database's (`api_usage.service`).
enum ApiService {
  apiNinjas('api_ninjas'),
  gemini('gemini');

  const ApiService(this.code);

  final String code;
}

/// Adds a run's [requests] to today's count of [service]
/// (`record_api_usage`); nothing for none.
Future<void> recordApiUsage(
  SupabaseClient client,
  ApiService service,
  int requests,
) async {
  if (requests <= 0) return;
  await client.rpc<void>(
    'record_api_usage',
    params: {'p_service': service.code, 'p_requests': requests},
  );
}
