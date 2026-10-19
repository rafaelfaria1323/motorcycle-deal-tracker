/// The message shown for a failed sign-in or sign-out, from the auth error
/// code and message.
String authErrorText(String? code, String message) =>
    code == 'invalid_credentials'
    ? 'Email ou palavra-passe incorretos.'
    : message;
