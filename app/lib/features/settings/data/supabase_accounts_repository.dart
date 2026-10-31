import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/accounts_repository.dart';

class SupabaseAccountsRepository(final SupabaseClient _client)
    implements AccountsRepository {
  @override
  Future<bool> isAdmin() async =>
      await _client.rpc<Object?>('is_admin') == true;

  @override
  Future<List<Account>> accounts() async {
    final rows = await _client.rpc<Object?>('admin_accounts') as List<dynamic>;
    return [for (final r in rows) Account.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<List<Invite>> invites() async {
    final rows = await _client
        .from('invites')
        .select('code, note, created_at, expires_at, used_at, used_by')
        .order('created_at', ascending: false);
    return [for (final r in rows) Invite.fromJson(r)];
  }

  @override
  Future<String> createInvite(String? note) async =>
      await _client.rpc<Object?>('create_invite', params: {'p_note': note})
          as String;

  @override
  Future<void> deleteInvite(String code) async {
    await _client.from('invites').delete().eq('code', code);
  }

  @override
  Future<void> setAdmin(String userId, {required bool admin}) async {
    await _client.rpc<Object?>(
      'set_admin',
      params: {'p_user': userId, 'p_admin': admin},
    );
  }

  @override
  Future<void> removeAccount(String userId) async {
    await _client.rpc<Object?>('remove_account', params: {'p_user': userId});
  }

  @override
  Future<InviteStatus> inviteStatus(String code) async {
    final status = await _client.rpc<Object?>(
      'invite_status',
      params: {'p_code': code},
    ) as String;
    return InviteStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => InviteStatus.unknown,
    );
  }

  @override
  Future<void> redeemInvite(String code, String email, String password) async {
    await _client.rpc<Object?>(
      'redeem_invite',
      params: {'p_code': code, 'p_email': email, 'p_password': password},
    );
    await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}
