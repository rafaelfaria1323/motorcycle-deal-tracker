import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/github_token.dart';

abstract interface class GithubTokenRepository {
  /// Asks GitHub about the token now (admins only).
  Future<GithubToken> check();
}

class SupabaseGithubTokenRepository(final SupabaseClient _client)
    implements GithubTokenRepository {
  @override
  Future<GithubToken> check() async {
    final rows =
        await _client.rpc<Object?>('github_token_status') as List<dynamic>;
    return GithubToken.fromJson(rows.first as Map<String, dynamic>);
  }
}
