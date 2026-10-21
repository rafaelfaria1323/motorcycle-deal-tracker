import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/collector_runs_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/collector_status_cubit.dart';

final _run = CollectorRun(
  status: 'ok',
  startedAt: DateTime.utc(2026, 10, 19, 6),
  finishedAt: DateTime.utc(2026, 10, 19, 6, 10),
);

class _Repository implements CollectorRunsRepository {
  _Repository({this.run, this.fails = false});

  final CollectorRun? run;
  final bool fails;

  @override
  Future<CollectorRun?> getLatest() async {
    if (fails) throw Exception('no access');
    return run;
  }

  @override
  Future<List<CollectorRun>> getSince(DateTime since) async => const [];

  @override
  Future<List<CollectorRun>> getRecent(int limit) async => const [];
}

void main() {
  test('starts without a run', () {
    expect(CollectorStatusCubit(_Repository()).state.run, isNull);
  });

  test('load publishes the latest run', () async {
    final cubit = CollectorStatusCubit(_Repository(run: _run));
    await cubit.load();
    expect(cubit.state.run, _run);
  });

  test('load with no runs leaves the state empty', () async {
    final cubit = CollectorStatusCubit(_Repository());
    await cubit.load();
    expect(cubit.state.run, isNull);
  });

  test('a failure is swallowed and leaves no run', () async {
    final cubit = CollectorStatusCubit(_Repository(fails: true));
    await expectLater(cubit.load(), completes);
    expect(cubit.state.run, isNull);
  });
}
