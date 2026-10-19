import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_text.dart';
import 'session_bootstrap.dart';

class AccountState extends Equatable {
  const AccountState({this.busy = false, this.done = false, this.error});

  final bool busy;
  final bool done;
  final String? error;

  @override
  List<Object?> get props => [busy, done, error];
}

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._client) : super(const AccountState());

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// True when signed in with an email (not an anonymous visitor).
  bool get hasAccount {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  String? get currentEmail => _auth.currentUser?.email;

  Future<void> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const AccountState(error: 'Indique o email e a palavra-passe.'));
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
      emit(AccountState(error: authErrorText(e.code, e.message)));
    }
  }

  /// Back to a fresh anonymous session so the app keeps working.
  Future<void> signOut() async {
    emit(const AccountState(busy: true));
    try {
      await _auth.signOut();
      await ensureSession(_client);
      emit(const AccountState(done: true));
    } on AuthException catch (e) {
      emit(AccountState(error: authErrorText(e.code, e.message)));
    }
  }
}
