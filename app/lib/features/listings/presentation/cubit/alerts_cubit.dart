import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/repositories/alerts_repository.dart';
import 'alerts_state.dart';

class AlertsCubit extends AccountScopedCubit<AlertsState> {
  AlertsCubit(this._repository, SessionCubit session)
    : super(session, const AlertsState());

  final AlertsRepository _repository;
  // An in-flight refresh may still contain an alert just dismissed.
  final _dismissedIds = <String>{};
  int _loadGeneration = 0;

  @override
  void resetForAccount() {
    _dismissedIds.clear();
    super.resetForAccount();
  }

  /// Loads (or refreshes) the alerts. A failed refresh keeps the list that is
  /// already on screen.
  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_loadGeneration;
    if (state.status != .success) {
      emit(state.copyWith(status: AlertsStatus.loading));
    }
    try {
      final alerts = await _repository.getAll();
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
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
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      if (state.status != .success) {
        emit(state.copyWith(status: AlertsStatus.failure));
      }
    }
  }

  /// Marks one alert as read right away, and undoes it if saving fails.
  Future<void> markRead(String id) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
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
      if (isCurrentAccount(account)) _restoreUnread({id}, now);
    }
  }

  Future<void> markAllRead() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
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
      if (!isCurrentAccount(account)) return;
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
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    try {
      await _repository.dismiss(id);
      if (!isCurrentAccount(account)) return false;
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
