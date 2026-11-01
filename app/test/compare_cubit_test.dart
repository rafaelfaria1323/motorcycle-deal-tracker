import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/compare/presentation/cubit/compare_cubit.dart';

void main() {
  test('toggles listings in the order picked, up to three', () {
    final cubit = CompareCubit();

    expect(cubit.toggle('a'), isTrue);
    expect(cubit.toggle('b'), isTrue);
    expect(cubit.toggle('c'), isTrue);
    expect(cubit.state, ['a', 'b', 'c']);

    expect(cubit.toggle('d'), isFalse);
    expect(cubit.state, ['a', 'b', 'c']);

    expect(cubit.toggle('b'), isTrue);
    expect(cubit.state, ['a', 'c']);
    expect(cubit.contains('b'), isFalse);

    cubit.clear();
    expect(cubit.state, isEmpty);
  });
}
