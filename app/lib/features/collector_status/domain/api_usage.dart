import 'package:equatable/equatable.dart';

/// The requests the weekly steps sent to an outside API (N.101), as they
/// counted them: this month's and last month's (Lisbon), and the last day
/// with any (null: never).
class const ApiUsage({
  required final String service,
  required final int monthRequests,
  required final int lastMonthRequests,
  final DateTime? lastUsedOn,
}) extends Equatable {
  /// A row of `api_usage()`.
  factory ApiUsage.fromJson(Map<String, dynamic> json) => ApiUsage(
    service: json['service'] as String,
    monthRequests: (json['month_requests'] as num).toInt(),
    lastMonthRequests: (json['last_month_requests'] as num).toInt(),
    lastUsedOn: switch (json['last_used_on']) {
      final String day => DateTime.parse(day),
      _ => null,
    },
  );

  @override
  List<Object?> get props => [
    service,
    monthRequests,
    lastMonthRequests,
    lastUsedOn,
  ];
}
