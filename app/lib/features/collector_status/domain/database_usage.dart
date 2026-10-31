import 'package:equatable/equatable.dart';

/// How much of Supabase's database space is used: the whole database and
/// its biggest tables, biggest first.
class const DatabaseUsage({
  required final int bytes,
  required final List<({String name, int bytes})> tables,
}) extends Equatable {
  factory DatabaseUsage.fromJson(Map<String, dynamic> json) => DatabaseUsage(
    bytes: (json['database_bytes'] as num).toInt(),
    tables: [
      for (final t in json['tables'] as List<dynamic>? ?? const [])
        (
          name: (t as Map<String, dynamic>)['name'] as String,
          bytes: (t['bytes'] as num).toInt(),
        ),
    ],
  );

  @override
  List<Object?> get props => [bytes, tables];
}
