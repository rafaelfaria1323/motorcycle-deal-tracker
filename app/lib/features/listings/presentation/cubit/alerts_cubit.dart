import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/alerts_repository.dart';
import 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit(this._repository) : super(const AlertsState());

  final AlertsRepository _repository;
  // An in-flight refresh may still contain an alert just dismissed.
  final _dismissedIds = <String>{};
  int _loadGeneration = 0;

  /// Loads (or refreshes) the alerts. A failed refresh keeps the list that is
  /// already on screen.
  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_loadGeneration;
    if (state.status != AlertsStatus.success) {
      emit(state.copyWith(status: AlertsStatus.loading));
    }
    try {
      final alerts = await _repository.getAll();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: AlertsStatus.success,
          alerts: [
            for (final alert in alerts)
              if (!_dismissedIds.contains(alert.id)) alert,
          ],
        ),
      );
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
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
      _restoreUnread({id}, now);
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
      _restoreUnread({
        for (final alert in before)
          if (!alert.isRead) alert.id,
      }, now);
    }
  }

  void _restoreUnread(Set<String> ids, DateTime changedAt) {
    if (isClosed) return;
    emit(
      state.copyWith(
        alerts: [
          for (final alert in state.alerts)
            ids.contains(alert.id) && alert.readAt == changedAt
                ? alert.copyWith(clearReadAt: true)
                : alert,
        ],
      ),
    );
  }

  Future<bool> dismiss(String id) async {
    try {
      await _repository.dismiss(id);
      if (isClosed) return false;
      _dismissedIds.add(id);
      emit(
        state.copyWith(
          alerts: [
            for (final alert in state.alerts)
              if (alert.id != id) alert,
          ],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
