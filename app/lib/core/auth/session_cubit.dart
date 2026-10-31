import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who is using the app: an owner signed in with an email, or an anonymous
/// visitor.
class const SessionState({
  final String? userId,
  final String? email,
  final bool signedIn = false,
}) extends Equatable {
  /// Anonymous visitors (and no session at all) are not signed in.
  factory SessionState.of(User? user) => SessionState(
    userId: user?.id,
    email: user?.email,
    signedIn: user != null && !user.isAnonymous,
  );

  @override
  List<Object?> get props => [userId, email, signedIn];
}

/// The current [SessionState], kept up to date as the user signs in and out,
/// so widgets read state instead of talking to Supabase's auth.
class SessionCubit extends Cubit<SessionState> {
  /// [users] emits the current user whenever the session changes.
  SessionCubit(super.initial, Stream<User?> users) {
    _subscription = users.listen((user) => emit(SessionState.of(user)));
  }

  /// Reads the session from [client].
  factory SessionCubit.of(SupabaseClient client) => SessionCubit(
    SessionState.of(client.auth.currentUser),
    client.auth.onAuthStateChange.map((change) => change.session?.user),
  );

  late final StreamSubscription<User?> _subscription;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
