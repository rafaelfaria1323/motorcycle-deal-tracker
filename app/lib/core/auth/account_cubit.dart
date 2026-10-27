import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/settings/domain/push_repository.dart';
import '../platform/push.dart';
import 'session_bootstrap.dart';

class AccountFailure extends Equatable {
  const AccountFailure.auth(this.code, this.message);

  const AccountFailure.credentialsRequired()
    : code = 'missing_credentials',
      message = '';

  final String? code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

class AccountState extends Equatable {
  const AccountState({this.busy = false, this.done = false, this.error});

  final bool busy;
  final bool done;
  final AccountFailure? error;

  @override
  List<Object?> get props => [busy, done, error];
}

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._client, this._push) : super(const AccountState());

  final SupabaseClient _client;
  final PushRepository _push;

  GoTrueClient get _auth => _client.auth;

  /// True when signed in with an email (not an anonymous visitor).
  bool get hasAccount {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  String? get currentEmail => _auth.currentUser?.email;

  Future<void> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const AccountState(error: AccountFailure.credentialsRequired()));
      return;
    }
    emit(const AccountState(busy: true));
    try {
      await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      emit(const AccountState(done: true));
    } on AuthException catch (e) {
      emit(AccountState(error: AccountFailure.auth(e.code, e.message)));
    }
  }

  /// Back to a fresh anonymous session so the app keeps working. This
  /// device stops receiving the account's notifications first, while the
  /// account may still remove its subscription.
  Future<void> signOut() async {
    emit(const AccountState(busy: true));
    try {
      final endpoint = await DevicePush.disable();
      if (endpoint != null) await _push.remove(endpoint);
    } on Object catch (_) {
      // No Web Push here, or already gone: nothing to stop.
    }
    try {
      await _auth.signOut();
      await ensureSession(_client);
      emit(const AccountState(done: true));
    } on AuthException catch (e) {
      emit(AccountState(error: AccountFailure.auth(e.code, e.message)));
    }
  }
}
