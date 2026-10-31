import 'package:equatable/equatable.dart';

import '../../domain/entities/listing_alert.dart';

enum AlertsStatus { initial, loading, success, failure }

class const AlertsState({
  final AlertsStatus status = AlertsStatus.initial,
  final List<ListingAlert> alerts = const [],
}) extends Equatable {
  int get unreadCount => alerts.where((a) => !a.isRead).length;

  AlertsState copyWith({AlertsStatus? status, List<ListingAlert>? alerts}) {
    return AlertsState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
    );
  }

  @override
  List<Object?> get props => [status, alerts];
}
