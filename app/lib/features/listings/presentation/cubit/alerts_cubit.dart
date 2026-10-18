import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/alerts_repository.dart';
import 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit(this._repository) : super(const AlertsState());

  final AlertsRepository _repository;

  /// Loads (or refreshes) the alerts. A failed refresh keeps the list that is
  /// already on screen.
  Future<void> load() async {
    if (state.status != AlertsStatus.success) {
      emit(state.copyWith(status: AlertsStatus.loading));
    }
    try {
      final alerts = await _repository.getAll();
      emit(state.copyWith(status: AlertsStatus.success, alerts: alerts));
    } catch (_) {
      if (state.status != AlertsStatus.success) {
        emit(state.copyWith(status: AlertsStatus.failure));
      }
    }
  }

  /// Marks one alert as read right away, and undoes it if saving fails.
  Future<void> markRead(String id) async {
    final before = state.alerts;
    final target = before.where((a) => a.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    final now = DateTime.now();
    emit(
      state.copyWith(
        alerts: [
          for (final a in before) a.id == id ? a.copyWith(readAt: now) : a,
        ],
      ),
    );
    try {
      await _repository.markRead(id);
    } catch (_) {
      emit(state.copyWith(alerts: before));
    }
  }

  Future<void> markAllRead() async {
    final before = state.alerts;
    if (state.unreadCount == 0) return;

    final now = DateTime.now();
    emit(
      state.copyWith(
        alerts: [
          for (final a in before) a.isRead ? a : a.copyWith(readAt: now),
        ],
      ),
    );
    try {
      await _repository.markAllRead();
    } catch (_) {
      emit(state.copyWith(alerts: before));
    }
  }
}
