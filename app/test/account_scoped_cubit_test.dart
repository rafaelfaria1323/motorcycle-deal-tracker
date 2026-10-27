import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/auth/account_scoped_cubit.dart';
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';

import 'helpers/session_fixture.dart';

class _ScopedCubit extends AccountScopedCubit<List<String>> {
  _ScopedCubit(SessionCubit session) : super(session, const []);

  int loads = 0;

  void show(String value) => emit([value]);

  @override
  Future<void> load() async => loads++;
}

void main() {
  test(
    'a different account clears data and reloads without a screen',
    () async {
      final session = SessionFixture();
      final cubit = session.track(_ScopedCubit(session.cubit))..show('private');
      final generation = cubit.accountGeneration;
      expect(cubit.loads, 0);

      await session.changeAccount('other');

      expect(cubit.state, isEmpty);
      expect(cubit.loads, 1);
      expect(cubit.isCurrentAccount(generation), isFalse);
      expect(cubit.isCurrentAccount(cubit.accountGeneration), isTrue);
    },
  );

  test('signing out clears private data before reloading', () async {
    final session = SessionFixture();
    final cubit = session.track(_ScopedCubit(session.cubit))..show('private');

    await session.changeAccount(null);

    expect(cubit.state, isEmpty);
    expect(cubit.loads, 1);
  });

  test('a refresh of the same identity does not reset or reload', () async {
    final session = SessionFixture();
    final cubit = session.track(_ScopedCubit(session.cubit))..show('current');
    final generation = cubit.accountGeneration;

    await session.changeAccount('owner');

    expect(cubit.state, ['current']);
    expect(cubit.loads, 0);
    expect(cubit.isCurrentAccount(generation), isTrue);
  });

  test('anonymous startup preserves the public prefetch scope', () async {
    final session = SessionFixture(accountId: null);
    final cubit = session.track(_ScopedCubit(session.cubit))..show('public');
    final generation = cubit.accountGeneration;

    await session.changeAccount('visitor', anonymous: true);
    await session.changeAccount('another-visitor', anonymous: true);

    expect(cubit.state, ['public']);
    expect(cubit.loads, 0);
    expect(cubit.isCurrentAccount(generation), isTrue);
  });

  test(
    'returning to the same account does not revive old operations',
    () async {
      final session = SessionFixture();
      final cubit = session.track(_ScopedCubit(session.cubit));
      final generation = cubit.accountGeneration;

      await session.changeAccount('other');
      await session.changeAccount('owner');

      expect(cubit.loads, 2);
      expect(cubit.isCurrentAccount(generation), isFalse);
    },
  );

  test('the source identity invalidates work before stream delivery', () async {
    final session = SessionFixture();
    late _ScopedCubit cubit;
    bool? currentBeforeDelivery;
    final observer = session.cubit.stream.listen((_) {
      currentBeforeDelivery = cubit.isCurrentAccount(0);
      expect(cubit.accountGeneration, 0);
    });
    addTearDown(observer.cancel);
    cubit = session.track(_ScopedCubit(session.cubit));

    await session.changeAccount('other');

    expect(currentBeforeDelivery, isFalse);
  });

  test('closing invalidates work and cancels session reloads', () async {
    final session = SessionFixture();
    final cubit = session.track(_ScopedCubit(session.cubit));
    final generation = cubit.accountGeneration;

    await cubit.close();
    await session.changeAccount('other');

    expect(cubit.isCurrentAccount(generation), isFalse);
    expect(cubit.isCurrentAccount(cubit.accountGeneration), isFalse);
    expect(cubit.loads, 0);
  });
}
