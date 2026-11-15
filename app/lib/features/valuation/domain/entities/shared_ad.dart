import 'package:equatable/equatable.dart';

/// An ad the iPhone shortcut sent from Safari (N.110), waiting in the
/// account's inbox: what that Safari showed, as the shortcut's script read
/// it (the seller's name never; phone numbers removed by the database).
class const SharedAd({
  required final String id,
  required final DateTime receivedAt,
  required final String url,
  final String? title,
  final String? description,
  final String? price,
  final List<String> lines = const [],
  final List<String> photos = const [],
  final int scriptVersion = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [
    id,
    receivedAt,
    url,
    title,
    description,
    price,
    lines,
    photos,
    scriptVersion,
  ];
}
