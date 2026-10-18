import 'package:equatable/equatable.dart';

import '../../domain/entities/listing_alert.dart';

enum AlertsStatus { initial, loading, success, failure }

class AlertsState extends Equatable {
  const AlertsState({
    this.status = AlertsStatus.initial,
    this.alerts = const [],
  });

  final AlertsStatus status;
  final List<ListingAlert> alerts;

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
