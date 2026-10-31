import 'package:equatable/equatable.dart';

import '../../domain/entities/alert_filter.dart';
import '../../domain/entities/listing_alert.dart';

enum AlertsStatus { initial, loading, success, failure }

class const AlertsState({
  final AlertsStatus status = AlertsStatus.initial,
  final List<ListingAlert> alerts = const [],
  final AlertFilter filter = AlertFilter.all,
  final bool hasMore = false,
  final bool loadingMore = false,

  /// Unread alerts not in [alerts]: on later pages or of other types.
  final int unreadElsewhere = 0,
}) extends Equatable {
  /// Every unread alert, loaded or not: the badge on Alertas.
  int get unreadCount =>
      alerts.where((a) => !a.isRead).length + unreadElsewhere;

  /// Whether "Eliminar os lidos" may find any: a read alert is shown, or
  /// some alerts are not loaded.
  bool get mayHaveRead =>
      alerts.any((a) => a.isRead) || hasMore || filter != AlertFilter.all;

  AlertsState copyWith({
    AlertsStatus? status,
    List<ListingAlert>? alerts,
    AlertFilter? filter,
    bool? hasMore,
    bool? loadingMore,
    int? unreadElsewhere,
  }) {
    return AlertsState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      unreadElsewhere: unreadElsewhere ?? this.unreadElsewhere,
    );
  }

  @override
  List<Object?> get props => [
    status,
    alerts,
    filter,
    hasMore,
    loadingMore,
    unreadElsewhere,
  ];
}
