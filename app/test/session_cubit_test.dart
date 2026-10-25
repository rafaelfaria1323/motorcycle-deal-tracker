import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({String? email, bool anonymous = false}) => User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
  email: email,
  isAnonymous: anonymous,
);

void main() {
  test('no user and anonymous visitors are not signed in', () {
    expect(SessionState.of(null).signedIn, isFalse);
    expect(SessionState.of(_user(anonymous: true)).signedIn, isFalse);
  });

  test('a user with an email is signed in', () {
    final state = SessionState.of(_user(email: 'a@b.pt'));
    expect(state.signedIn, isTrue);
    expect(state.userId, 'u1');
    expect(state.email, 'a@b.pt');
  });

  test('follows the user as they sign in and out', () async {
    final users = StreamController<User?>();
    final cubit = SessionCubit(SessionState.of(null), users.stream);
    final seen = <SessionState>[];
    cubit.stream.listen(seen.add);

    users.add(_user(email: 'a@b.pt'));
    users.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [
      const SessionState(userId: 'u1', email: 'a@b.pt', signedIn: true),
      const SessionState(),
    ]);
    await cubit.close();
    await users.close();
  });
}
