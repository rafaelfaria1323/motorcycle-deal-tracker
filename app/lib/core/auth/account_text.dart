import '../localization/localizations.dart';

/// The message shown for a failed sign-in or sign-out, from the auth error
/// code and message.
String authErrorText(
  String? code,
  String message, {
  AppLanguage language = .portuguese,
}) => switch (code) {
  'missing_credentials' => language.messages.enterYourEmailAndPassword,
  'invalid_credentials' => language.messages.incorrectEmailOrPassword,
  'email_not_confirmed' => language.messages.authEmailNotConfirmed,
  'user_banned' || 'user_not_found' => language.messages.authAccountUnavailable,
  'over_request_rate_limit' ||
  'over_email_send_rate_limit' => language.messages.authRateLimited,
  _ => message,
};
