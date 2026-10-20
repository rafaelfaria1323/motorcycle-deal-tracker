import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who is using the app: an owner signed in with an email, or an anonymous
/// visitor.
class SessionState extends Equatable {
  const SessionState({this.email, this.signedIn = false});

  /// Anonymous visitors (and no session at all) are not signed in.
  factory SessionState.of(User? user) => SessionState(
    email: user?.email,
    signedIn: user != null && !user.isAnonymous,
  );

  final String? email;
  final bool signedIn;

  @override
  List<Object?> get props => [email, signedIn];
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
