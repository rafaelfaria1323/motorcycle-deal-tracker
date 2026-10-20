import 'package:equatable/equatable.dart';

/// A town, municipality or district (table `places`), matched by [key].
class Place extends Equatable {
  const Place({required this.key, required this.name});

  final String key;
  final String name;

  @override
  List<Object?> get props => [key, name];
}
