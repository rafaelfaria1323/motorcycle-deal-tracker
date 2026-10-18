import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gives every visitor an identity. The first visit creates an anonymous
/// Supabase user; after that the stored session is reused, so the same
/// browser keeps the same user (and the same saved searches).
///
/// Never blocks the app: browsing listings works without a session.
Future<void> ensureSession(SupabaseClient client) async {
  if (client.auth.currentSession != null) return;
  try {
    await client.auth.signInAnonymously();
  } on AuthException catch (e) {
    debugPrint('Anonymous sign-in failed: ${e.message}');
  }
}
