import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'web_push.dart';

/// Notifications in the Android app: Web Push is the browser's, so the app
/// registers with Firebase Cloud Messaging and its device is stored as
/// `fcm:<registration token>`. The collector sends to it through FCM's
/// HTTP v1 API, signing in as the Firebase project's service account
/// (Google's `googleapis_auth`: the signed JWT exchanged for an access
/// token). The app shows the message itself (a data message), so a tap
/// opens the page in the app.

/// The prefix of an Android device's endpoint.
const fcmPrefix = 'fcm:';

/// The scope FCM's HTTP v1 API asks for.
const fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

const _timeout = Duration(seconds: 15);

/// The Firebase project's service account: the JSON Google gives as its
/// private key (GitHub secret `FIREBASE_SERVICE_ACCOUNT`).
class FcmAccount({
  required final String projectId,
  required final ServiceAccountCredentials credentials,
}) {
  /// From the service account JSON; throws [FormatException] when a field
  /// is missing or the key can't be read.
  factory FcmAccount.fromJson(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Service account is not JSON');
    }
    final projectId = switch (json) {
      {'project_id': final String id} when id.isNotEmpty => id,
      _ => throw const FormatException('Service account without project_id'),
    };
    try {
      return FcmAccount(
        projectId: projectId,
        credentials: ServiceAccountCredentials.fromJson(json),
      );
    } on ArgumentError catch (e) {
      throw FormatException('Service account not usable: ${e.message}');
    } on FormatException catch (e) {
      throw FormatException('Unreadable private key: ${e.message}');
    }
  }
}

/// FCM's request body for [message] ({title, body, url, tag}): a data
/// message, which the app turns into its notification (and its tap).
Map<String, Object?> fcmMessage(String token, Map<String, Object?> message) => {
  'message': {
    'token': token,
    'data': {
      for (final key in const ['title', 'body', 'url', 'tag', 'language'])
        if (message[key] case final String value) key: value,
    },
    'android': {'priority': 'HIGH', 'ttl': '86400s'},
  },
};

/// Sends to Android devices through FCM, with one access token per run.
class FcmSender(
  final FcmAccount account, {
  final String apiBase = 'https://fcm.googleapis.com',
  http.Client? client,
}) {
  final http.Client _client = client ?? http.Client();

  /// From env `FIREBASE_SERVICE_ACCOUNT`, or null when it isn't set or
  /// can't be read (said on stderr; Android devices then aren't reached).
  static FcmSender? fromEnvironment([Map<String, String>? environment]) {
    final text =
        (environment ?? Platform.environment)['FIREBASE_SERVICE_ACCOUNT'];
    if (text == null || text.trim().isEmpty) return null;
    try {
      return FcmSender(FcmAccount.fromJson(text));
    } on FormatException catch (e) {
      stderr.writeln('FIREBASE_SERVICE_ACCOUNT not usable: ${e.message}');
      return null;
    }
  }

  Future<String?>? _token;

  /// Sends [message] to the device whose endpoint is `fcm:<token>`.
  /// Never throws: a network problem is [PushResult.failed].
  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    final access = await (_token ??= _accessToken());
    if (access == null) return .failed;
    final token = target.endpoint.substring(fcmPrefix.length);
    final url = Uri.parse(
      '$apiBase/v1/projects/${account.projectId}/messages:send',
    );
    final http.Response response;
    try {
      response = await _client
          .post(
            url,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $access',
            },
            body: jsonEncode(fcmMessage(token, message)),
          )
          .timeout(_timeout);
    } on Object catch (e) {
      stderr.writeln('Push to FCM: ${url.host} not reached: ${e.runtimeType}');
      return .failed;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return .sent;
    // UNREGISTERED: the app was removed or its token replaced. A token FCM
    // calls invalid can never receive anything either.
    final text = response.body;
    if (status == 404 ||
        (status == 400 &&
            text.contains('INVALID_ARGUMENT') &&
            text.contains('registration token'))) {
      return .gone;
    }
    stderr.writeln('Push to FCM: HTTP $status $text');
    return .failed;
  }

  Future<String?> _accessToken() async {
    try {
      final credentials = await obtainAccessCredentialsViaServiceAccount(
        account.credentials,
        const [fcmScope],
        _client,
      ).timeout(_timeout);
      return credentials.accessToken.data;
    } on Object catch (e) {
      stderr.writeln('FCM sign-in refused: $e');
      return null;
    }
  }
}
