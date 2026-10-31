import 'package:equatable/equatable.dart';

/// A town, municipality or district (table `places`), matched by [key].
class const Place({required final String key, required final String name})
    extends Equatable {
  @override
  List<Object?> get props => [key, name];
}
