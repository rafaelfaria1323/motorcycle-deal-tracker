import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'web_push.dart';

/// Notifications in the Android app: Web Push is the browser's, so the app
/// registers with Firebase Cloud Messaging and its device is stored as
/// `fcm:<registration token>`. The collector sends to it through FCM's
/// HTTP v1 API, signing in as the Firebase project's service account (a
/// JWT signed RS256 with its key, exchanged for an access token); no
/// Google library. The app shows the message itself (a data message), so
/// a tap opens the page in the app.

/// The prefix of an Android device's endpoint.
const fcmPrefix = 'fcm:';

const _googleTokenUri = 'https://oauth2.googleapis.com/token';

/// The Firebase project's service account: the JSON Google gives as its
/// private key (GitHub secret `FIREBASE_SERVICE_ACCOUNT`).
class FcmAccount({
  required final String projectId,
  required final String clientEmail,
  required final RSAPrivateKey privateKey,
  final String tokenUri = _googleTokenUri,
}) {
  /// From the service account JSON; throws [FormatException] when a field
  /// is missing or the key can't be read.
  factory FcmAccount.fromJson(String text) {
    final json = jsonDecode(text);
    String field(String name) => switch (json is Map ? json[name] : null) {
      final String value when value.isNotEmpty => value,
      _ => throw FormatException('Service account without $name'),
    };
    return FcmAccount(
      projectId: field('project_id'),
      clientEmail: field('client_email'),
      privateKey: rsaKeyFromPem(field('private_key')),
      tokenUri: switch (json) {
        {'token_uri': final String uri} when uri.isNotEmpty => uri,
        _ => _googleTokenUri,
      },
    );
  }
}

/// The RSA key of a PKCS#8 PEM ("BEGIN PRIVATE KEY", as Google gives it).
RSAPrivateKey rsaKeyFromPem(String pem) {
  final base64Text = pem
      .replaceAll(RegExp('-----[A-Z ]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  try {
    final info = ASN1Parser(base64.decode(base64Text)).nextObject();
    final key = (info as ASN1Sequence).elements![2] as ASN1OctetString;
    final rsa = ASN1Parser(key.octets).nextObject() as ASN1Sequence;
    BigInt at(int i) => (rsa.elements![i] as ASN1Integer).integer!;
    return RSAPrivateKey(at(1), at(3), at(4), at(5));
  } on Object catch (e) {
    throw FormatException('Unreadable private key: ${e.runtimeType}');
  }
}

/// The signed JWT that asks Google for an FCM access token (valid 1 hour).
String fcmAssertion(FcmAccount account, {DateTime? now}) {
  final issued = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
  String part(Map<String, Object> json) =>
      base64UrlNoPad(utf8.encode(jsonEncode(json)));
  final unsigned =
      '${part({'alg': 'RS256', 'typ': 'JWT'})}.'
      '${part({'iss': account.clientEmail, 'scope': 'https://www.googleapis.com/auth/firebase.messaging', 'aud': account.tokenUri, 'iat': issued, 'exp': issued + 3600})}';
  final signer = Signer('SHA-256/RSA')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(account.privateKey));
  final signature = signer.generateSignature(
    Uint8List.fromList(utf8.encode(unsigned)),
  ) as RSASignature;
  return '$unsigned.${base64UrlNoPad(signature.bytes)}';
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
}) {
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
    final (status, text) = await _post(
      Uri.parse('$apiBase/v1/projects/${account.projectId}/messages:send'),
      jsonEncode(fcmMessage(token, message)),
      contentType: ContentType.json,
      authorization: 'Bearer $access',
    );
    if (status >= 200 && status < 300) return .sent;
    // UNREGISTERED: the app was removed or its token replaced. A token FCM
    // calls invalid can never receive anything either.
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
    final (status, text) = await _post(
      Uri.parse(account.tokenUri),
      'grant_type=${Uri.encodeQueryComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}'
      '&assertion=${fcmAssertion(account)}',
      contentType: ContentType('application', 'x-www-form-urlencoded'),
    );
    if (status == 200) {
      try {
        final Object? reply = jsonDecode(text);
        if (reply case {'access_token': final String token}) {
          return token;
        }
      } on FormatException {
        // Reported below.
      }
    }
    stderr.writeln('FCM sign-in refused: HTTP $status $text');
    return null;
  }
}

/// POSTs [body]; a network problem is status 0.
Future<(int, String)> _post(
  Uri url,
  String body, {
  required ContentType contentType,
  String? authorization,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .postUrl(url)
        .timeout(const Duration(seconds: 15));
    final bytes = utf8.encode(body);
    request.headers
      ..contentType = contentType
      ..contentLength = bytes.length;
    if (authorization != null) {
      request.headers.set('Authorization', authorization);
    }
    request.add(bytes);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    return (response.statusCode, text);
  } on Object catch (e) {
    return (0, '${url.host} not reached: ${e.runtimeType}');
  } finally {
    client.close(force: true);
  }
}
