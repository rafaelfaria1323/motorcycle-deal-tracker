import 'package:equatable/equatable.dart';

/// How much of Supabase's database space is used: the whole database and
/// its biggest tables, biggest first.
class DatabaseUsage extends Equatable {
  const DatabaseUsage({required this.bytes, required this.tables});

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

  final int bytes;
  final List<({String name, int bytes})> tables;

  @override
  List<Object?> get props => [bytes, tables];
}
