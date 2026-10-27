import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionFixture {
  SessionFixture({String? accountId = 'owner'}) {
    cubit = SessionCubit(
      accountId == null
          ? const SessionState()
          : SessionState(userId: accountId, signedIn: true),
      _users.stream,
    );
    addTearDown(() async {
      await cubit.close();
      await _users.close();
    });
  }

  final _users = StreamController<User?>();
  late final SessionCubit cubit;

  T track<T extends BlocBase<Object?>>(T value) {
    addTearDown(() async {
      if (!value.isClosed) await value.close();
    });
    return value;
  }

  Future<void> changeAccount(String? id, {bool anonymous = false}) async {
    _users.add(
      id == null
          ? null
          : User(
              id: id,
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: '2026-10-27T00:00:00Z',
              email: anonymous ? null : 'owner@example.pt',
              isAnonymous: anonymous,
            ),
    );
    await Future<void>.delayed(Duration.zero);
  }
}
