import 'package:equatable/equatable.dart';

/// Whether GitHub accepts the token that starts the runs (Vault
/// `github_dispatch_token`), and when it expires.
enum GithubTokenState { ok, missing, refused }

class const GithubToken({
  required final GithubTokenState state,
  final int? httpStatus,

  /// Null when the token never expires.
  final DateTime? expiresAt,
}) extends Equatable {
  factory GithubToken.fromJson(Map<String, dynamic> json) => GithubToken(
    state: GithubTokenState.values.firstWhere(
      (s) => s.name == json['state'],
      orElse: () => GithubTokenState.refused,
    ),
    httpStatus: (json['http_status'] as num?)?.toInt(),
    expiresAt: json['expires_at'] == null
        ? null
        : DateTime.parse(json['expires_at'] as String),
  );

  @override
  List<Object?> get props => [state, httpStatus, expiresAt];
}
