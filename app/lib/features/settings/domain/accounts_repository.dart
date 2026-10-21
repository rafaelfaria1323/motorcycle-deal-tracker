import 'package:equatable/equatable.dart';

/// A real (not anonymous) account, as admins see it.
class Account extends Equatable {
  const Account({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.isAdmin,
    this.isMe = false,
    this.lastSignInAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['user_id'] as String,
    email: json['email'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    lastSignInAt: json['last_sign_in_at'] == null
        ? null
        : DateTime.parse(json['last_sign_in_at'] as String),
    isAdmin: json['is_admin'] as bool? ?? false,
    isMe: json['is_me'] as bool? ?? false,
  );

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final bool isAdmin;

  /// The signed-in account itself.
  final bool isMe;

  @override
  List<Object?> get props => [
    id,
    email,
    createdAt,
    lastSignInAt,
    isAdmin,
    isMe,
  ];
}

/// A link that makes one account.
class Invite extends Equatable {
  const Invite({
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.note,
    this.usedAt,
    this.usedBy,
  });

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
    code: json['code'] as String,
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    usedAt: json['used_at'] == null
        ? null
        : DateTime.parse(json['used_at'] as String),
    usedBy: json['used_by'] as String?,
  );

  final String code;
  final String? note;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String? usedBy;

  @override
  List<Object?> get props => [code, note, createdAt, expiresAt, usedAt, usedBy];
}

/// What an invite page finds for its code.
enum InviteStatus { ok, used, expired, unknown }

abstract interface class AccountsRepository {
  /// Whether the signed-in account may manage accounts.
  Future<bool> isAdmin();

  Future<List<Account>> accounts();

  /// Newest first.
  Future<List<Invite>> invites();

  /// A new invite's code.
  Future<String> createInvite(String? note);

  /// Cancels an unused invite, or forgets a used or expired one.
  Future<void> deleteInvite(String code);

  Future<void> setAdmin(String userId, {required bool admin});

  Future<void> removeAccount(String userId);

  Future<InviteStatus> inviteStatus(String code);

  /// Makes the account and signs in with it.
  Future<void> redeemInvite(String code, String email, String password);
}
