import '../../../core/formatting/formatters.dart';
import '../domain/accounts_repository.dart';
import '../../../core/localization/localizations.dart';

/// The address of the app at [origin] (`https://….pages.dev`).
String appLink(String origin) => '$origin/';

/// The invite page for [code] (hash routing, as the app's other links).
String inviteLink(String origin, String code) =>
    '$origin/#/join?code=${Uri.encodeQueryComponent(code)}';

String appShareText({AppLanguage language = .portuguese}) =>
    language.messages.seeUsedMotorcyclesForSaleInPortugalWith;

String inviteShareText({AppLanguage language = .portuguese}) =>
    language.messages.hereIsInviteToMotorcycleDealTrackerOpen;

/// What an invite page says when its code can't be used; null when it can.
String? inviteStatusText(
  InviteStatus status, {
  AppLanguage language = .portuguese,
}) => switch (status) {
  InviteStatus.ok => null,
  InviteStatus.used => language.messages.thisInviteHasAlreadyBeenUsedAskSender,
  InviteStatus.expired => language.messages.thisInviteHasExpiredAskSenderForNew,
  InviteStatus.unknown =>
    language.messages.thisInviteDoesNotExistOrWasCancelled,
};

/// What is wrong with the form, or null.
String? joinFormProblem(
  String email,
  String password,
  String confirmation, {
  AppLanguage language = .portuguese,
}) {
  final e = email.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
    return language.messages.enterValidEmailAddress;
  }
  if (password.length < 8) {
    return language.messages.yourPasswordNeedsAtLeast8Characters;
  }
  if (password != confirmation) return language.messages.passwordsDoNotMatch;
  return null;
}

/// The message for a failed redeem, from the database's error code.
String redeemErrorText(String? code, {AppLanguage language = .portuguese}) =>
    switch (code) {
      'P0002' => inviteStatusText(InviteStatus.unknown, language: language)!,
      '23505' => language.messages.thisEmailAlreadyHasAccountSignInThrough,
      '22023' => language.messages.checkYourEmailAndPasswordAtLeast8,
      '55000' => language.messages.inviteServiceNotReady,
      _ => language.messages.couldNotCreateAccountTryAgain,
    };

/// The second line of an invite in the admin list.
String inviteSubtitle(
  Invite invite, {
  required DateTime now,
  Map<String, String> emails = const {},
  AppLanguage language = .portuguese,
}) {
  if (invite.usedAt != null) {
    final who = emails[invite.usedBy];
    return language.messages.inviteUsed(
      byWho: who == null ? '' : language.messages.by(who: who),
      date: Formatters.date(invite.usedAt!),
    );
  }
  if (!invite.expiresAt.isAfter(now)) {
    return language.messages.expiredOn(date: Formatters.date(invite.expiresAt));
  }
  final days = invite.expiresAt.difference(now).inHours ~/ 24;
  return language.messages.inviteUnused(
    expires: days < 1
        ? language.messages.today
        : language.messages.inDays(days: days),
  );
}

/// Whether the invite can still make an account.
bool invitePending(Invite invite, DateTime now) =>
    invite.usedAt == null && invite.expiresAt.isAfter(now);

/// The second line of an account in the admin list.
String accountSubtitle(Account account, {AppLanguage language = .portuguese}) {
  final parts = [
    if (account.isAdmin) language.messages.administrator,
    language.messages.createdOn(date: Formatters.date(account.createdAt)),
    account.lastSignInAt == null
        ? language.messages.neverSignedIn
        : language.messages.lastSignedInOn(
            date: Formatters.date(account.lastSignInAt!),
          ),
  ];
  return parts.join(' · ');
}
