import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/collector_runs_repository.dart';
import '../domain/collector_run.dart';

class CollectorStatusState extends Equatable {
  const CollectorStatusState({this.run});

  final CollectorRun? run;

  @override
  List<Object?> get props => [run];
}

class CollectorStatusCubit extends Cubit<CollectorStatusState> {
  CollectorStatusCubit(this._repository) : super(const CollectorStatusState());

  final CollectorRunsRepository _repository;

  /// Failures are swallowed: the status line is secondary, and the dashboard
  /// must work without it.
  Future<void> load() async {
    try {
      emit(CollectorStatusState(run: await _repository.getLatest()));
    } on Object catch (e) {
      debugPrint('Collector status unavailable: $e');
      emit(const CollectorStatusState());
    }
  }
}
