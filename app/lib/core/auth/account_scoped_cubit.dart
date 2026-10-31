import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'session_cubit.dart';

/// Clears shared state when its account changes, regardless of which
/// screen initiated the change. Anonymous sessions share the public scope.
abstract class AccountScopedCubit<State> extends Cubit<State> {
  AccountScopedCubit(this._session, this._initialState)
    : _accountId = _accountOf(_session.state),
      super(_initialState) {
    _subscription = _session.stream.listen((session) {
      final accountId = _accountOf(session);
      if (isClosed || accountId == _accountId) return;
      _accountId = accountId;
      ++_accountGeneration;
      resetForAccount();
      unawaited(load());
    });
  }

  final SessionCubit _session;
  final State _initialState;
  late final StreamSubscription<SessionState> _subscription;
  String? _accountId;
  int _accountGeneration = 0;

  static String? _accountOf(SessionState session) =>
      session.signedIn ? session.userId : null;

  int get accountGeneration => _accountGeneration;

  /// Also checks the source state: its stream may not have delivered the
  /// account change yet. The generation rejects an A -> B -> A round trip.
  bool isCurrentAccount(int generation) =>
      !isClosed &&
      generation == _accountGeneration &&
      _accountId == _accountOf(_session.state);

  void resetForAccount() => emit(_initialState);

  Future<void> load();

  @override
  Future<void> close() async {
    ++_accountGeneration;
    await Future.wait([_subscription.cancel(), super.close()]);
  }
}
