import 'dart:math';

import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/alert_filter.dart';
import '../../domain/entities/listing_alert.dart';
import '../../domain/repositories/alerts_repository.dart';
import 'alerts_state.dart';

class AlertsCubit extends AccountScopedCubit<AlertsState> {
  AlertsCubit(this._repository, SessionCubit session)
    : super(session, const AlertsState());

  final AlertsRepository _repository;

  /// Alerts per request; the list asks for more as it scrolls (F.6).
  static const pageSize = 40;

  // An in-flight refresh may still contain an alert just dismissed.
  final _dismissedIds = <String>{};

  /// Bumped by each [load]: an answer to an older one, or a page asked for
  /// before it, is dropped.
  int _loadGeneration = 0;

  @override
  void resetForAccount() {
    _dismissedIds.clear();
    super.resetForAccount();
  }

  /// Loads (or refreshes) the alerts of the current filter, as many as are
  /// shown (at least a page, so a refresh keeps the place in a long list),
  /// and how many are unread. A failed refresh keeps the list on screen.
  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: state.status == .success ? null : AlertsStatus.loading,
        loadingMore: false,
      ),
    );
    final filter = state.filter;
    final limit = max(1, (state.alerts.length / pageSize).ceil()) * pageSize;
    try {
      final (alerts, unread) = await (
        _repository.getPage(types: filter.types, limit: limit),
        _repository.countUnread(),
      ).wait;
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      final shown = [
        for (final alert in alerts)
          if (!_dismissedIds.contains(alert.id)) alert,
      ];
      emit(
        state.copyWith(
          status: AlertsStatus.success,
          alerts: shown,
          hasMore: alerts.length == limit,
          // The count saw what the page saw, an alert deleted meanwhile
          // included.
          unreadElsewhere: max(0, unread - _unread(alerts)),
        ),
      );
    } catch (_) {
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      if (state.status != .success) {
        emit(state.copyWith(status: AlertsStatus.failure));
      }
    }
  }

  static int _unread(Iterable<ListingAlert> alerts) =>
      alerts.where((alert) => !alert.isRead).length;

  /// Appends the next page; does nothing while one is loading or when
  /// there are no more.
  Future<void> loadMore() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account) ||
        state.status != .success ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    final generation = _loadGeneration;
    final filter = state.filter;
    // Alerts deleted here left the server's list too, so the offset is
    // what is shown.
    final offset = state.alerts.length;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getPage(
        types: filter.types,
        offset: offset,
        limit: pageSize,
      );
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      // Alerts made since the first page push the older ones down: skip
      // those already shown.
      final shown = {for (final alert in state.alerts) alert.id};
      final added = [
        for (final alert in page)
          if (!shown.contains(alert.id) && !_dismissedIds.contains(alert.id))
            alert,
      ];
      emit(
        state.copyWith(
          alerts: [...state.alerts, ...added],
          hasMore: page.length == pageSize,
          loadingMore: false,
          unreadElsewhere: max(0, state.unreadElsewhere - _unread(added)),
        ),
      );
    } catch (_) {
      // Keep what is shown; scrolling again retries.
      if (isCurrentAccount(account) && generation == _loadGeneration) {
        emit(state.copyWith(loadingMore: false));
      }
    }
  }

  /// Shows only [filter]'s alerts, from the first page. The badge keeps
  /// its count while they load.
  Future<void> applyFilter(AlertFilter filter) async {
    if (!isCurrentAccount(accountGeneration) || filter == state.filter) return;
    emit(
      state.copyWith(
        filter: filter,
        status: AlertsStatus.loading,
        alerts: const [],
        hasMore: false,
        loadingMore: false,
        unreadElsewhere: state.unreadCount,
      ),
    );
    await load();
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

  /// Marks every alert read, also those not loaded or of other types.
  Future<void> markAllRead() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final before = state.alerts;
    final elsewhere = state.unreadElsewhere;
    if (state.unreadCount == 0) return;

    final now = DateTime.now();
    emit(
      state.copyWith(
        alerts: [
          for (final a in before) a.isRead ? a : a.copyWith(readAt: now),
        ],
        unreadElsewhere: 0,
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
      // A refresh in between counted them again itself.
      if (!isClosed && state.unreadElsewhere == 0) {
        emit(state.copyWith(unreadElsewhere: elsewhere));
      }
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

  /// "Eliminar os lidos": hides every read alert, loaded or not, then loads
  /// the list again (the alerts after them moved up). How many went, or
  /// null when it failed.
  Future<int?> dismissRead() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return null;
    try {
      final count = await _repository.dismissRead();
      if (!isCurrentAccount(account)) return null;
      emit(
        state.copyWith(
          alerts: [
            for (final alert in state.alerts)
              if (!alert.isRead) alert,
          ],
        ),
      );
      await load();
      return count;
    } catch (_) {
      return null;
    }
  }
}
