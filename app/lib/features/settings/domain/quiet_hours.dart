import 'package:equatable/equatable.dart';

/// The hours (Portugal time) an account's alerts are not pushed (table
/// `quiet_hours`): they wait and go with the first collection after
/// [endHour]. An account without a row has [QuietHours.standard].
class QuietHours extends Equatable {
  const QuietHours({
    required this.enabled,
    required this.startHour,
    required this.endHour,
  });

  /// The database's default: on, 23:00 to 08:00.
  static const standard = QuietHours(enabled: true, startHour: 23, endHour: 8);

  final bool enabled;
  final int startHour;
  final int endHour;

  QuietHours copyWith({bool? enabled, int? startHour, int? endHour}) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        startHour: startHour ?? this.startHour,
        endHour: endHour ?? this.endHour,
      );

  @override
  List<Object?> get props => [enabled, startHour, endHour];
}
