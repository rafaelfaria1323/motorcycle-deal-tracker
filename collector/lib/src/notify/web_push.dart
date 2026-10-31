import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'fcm.dart';

/// Web Push without a third party: the message is encrypted for the
/// browser (RFC 8291, aes128gcm) and signed with our VAPID key (RFC 8292),
/// then posted to the push service the browser chose (Apple's for an
/// iPhone home-screen app, Google's for Chrome, Mozilla's for Firefox).
/// Nothing but the encrypted text reaches the push service.

final _curve = ECCurve_secp256r1();

/// Our VAPID key pair (P-256). The public key (65 bytes, uncompressed) is
/// what the app subscribes with; the private one signs every request.
class VapidKeys(final BigInt privateKey, final Uint8List publicKey) {
  /// Both keys from their base64url text, as stored.
  factory VapidKeys.fromBase64(String private, String public) => VapidKeys(
    _bigInt(base64UrlDecodeLoose(private)),
    base64UrlDecodeLoose(public),
  );

  /// A new random pair.
  factory VapidKeys.generate() {
    final pair = _newKeyPair();
    return VapidKeys(
      (pair.privateKey as ECPrivateKey).d!,
      (pair.publicKey as ECPublicKey).Q!.getEncoded(false),
    );
  }

  String get privateBase64 => base64UrlNoPad(_bytes(privateKey, 32));
  String get publicBase64 => base64UrlNoPad(publicKey);
}

/// Where and how one browser receives pushes (its PushSubscription).
class const PushTarget({
  required final String endpoint,

  /// The browser's public key (base64url, 65 bytes).
  required final String p256dh,

  /// The browser's auth secret (base64url, 16 bytes).
  required final String auth,
}) {
  /// The Android app's device (FCM), not a browser's.
  bool get isAndroid => endpoint.startsWith(fcmPrefix);
}

/// What a push service answered.
enum PushResult {
  sent,

  /// The subscription no longer exists (404 / 410): forget it.
  gone,

  /// Anything else; try again next run.
  failed,
}

/// The body to post for [plaintext], encrypted for the browser with
/// [uaPublic] and [authSecret] (RFC 8291). [salt] and [ephemeral] are
/// random unless given (tests use the RFC's fixed values).
Uint8List encryptPayload(
  Uint8List plaintext, {
  required Uint8List uaPublic,
  required Uint8List authSecret,
  Uint8List? salt,
  AsymmetricKeyPair<PublicKey, PrivateKey>? ephemeral,
}) {
  final keys = ephemeral ?? _newKeyPair();
  final asPublic = (keys.publicKey as ECPublicKey).Q!.getEncoded(false);
  final saltBytes = salt ?? _randomBytes(16);

  final agreement = ECDHBasicAgreement()..init(keys.privateKey as ECPrivateKey);
  final ecdhSecret = _bytes(
    agreement.calculateAgreement(
      ECPublicKey(_curve.curve.decodePoint(uaPublic), _curve),
    ),
    32,
  );

  final keyInfo = BytesBuilder()
    ..add(utf8.encode('WebPush: info'))
    ..addByte(0)
    ..add(uaPublic)
    ..add(asPublic);
  final ikm = _hkdf(authSecret, ecdhSecret, keyInfo.toBytes(), 32);
  final prk = _hmac(saltBytes, ikm);
  final cek = _expand(prk, _info('aes128gcm'), 16);
  final nonce = _expand(prk, _info('nonce'), 12);

  // One record: the text and the last-record delimiter (2).
  final record = Uint8List(plaintext.length + 1)
    ..setAll(0, plaintext)
    ..[plaintext.length] = 2;
  final gcm = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(cek), 128, nonce, Uint8List(0)));
  final cipherText = gcm.process(record);

  const recordSize = 4096;
  return (BytesBuilder()
        ..add(saltBytes)
        ..add([
          (recordSize >> 24) & 0xff,
          (recordSize >> 16) & 0xff,
          (recordSize >> 8) & 0xff,
          recordSize & 0xff,
        ])
        ..addByte(asPublic.length)
        ..add(asPublic)
        ..add(cipherText))
      .toBytes();
}

/// The Authorization header for a request to [endpoint] (RFC 8292): a
/// JWT signed with [keys] for the push service's origin, valid 12 hours.
String vapidAuthorization(
  Uri endpoint,
  VapidKeys keys, {
  required String subject,
  DateTime? now,
}) {
  final exp =
      (now ?? DateTime.now())
          .toUtc()
          .add(const Duration(hours: 12))
          .millisecondsSinceEpoch ~/
      1000;
  String part(Map<String, Object> json) =>
      base64UrlNoPad(utf8.encode(jsonEncode(json)));
  final unsigned =
      '${part({'typ': 'JWT', 'alg': 'ES256'})}.'
      '${part({'aud': endpoint.origin, 'exp': exp, 'sub': subject})}';

  final signer = Signer('SHA-256/DET-ECDSA')
    ..init(
      true,
      PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(keys.privateKey, _curve)),
    );
  final signature = signer.generateSignature(
    Uint8List.fromList(utf8.encode(unsigned)),
  ) as ECSignature;
  // JOSE wants r and s side by side, 32 bytes each.
  final raw = Uint8List(64)
    ..setAll(0, _bytes(signature.r, 32))
    ..setAll(32, _bytes(signature.s, 32));
  return 'vapid t=$unsigned.${base64UrlNoPad(raw)}, k=${keys.publicBase64}';
}

/// Where the app lives: the subject of our VAPID signatures (push services
/// contact it if our pushes misbehave).
const appOrigin = 'https://motorcycle-deal-tracker.pages.dev';

/// What a push carries: Declarative Web Push (the Push API's `web_push: 8030`
/// form). iOS 18.4+ shows it and opens `navigate` on a tap by itself, also
/// with the home-screen app already open (a service worker that controls no
/// page can't move it there); other browsers hand it to web/push_sw.js.
/// [message] is {title, body, url, tag} with a relative url.
Map<String, Object?> declarativePush(
  Map<String, Object?> message, {
  String origin = appOrigin,
}) => {
  'web_push': 8030,
  'notification': {
    // The title is required and must not be empty.
    'title': switch (message['title']) {
      final String t when t.isNotEmpty => t,
      _ => 'Deal Tracker',
    },
    if (message['body'] case final String body) 'body': body,
    'navigate': Uri.parse(origin)
        .resolve(message['url'] as String? ?? '/')
        .toString(),
    if (message['tag'] case final String tag) 'tag': tag,
    if (message['language'] case final String language) 'lang': language,
  },
};

/// Sends pushes signed with one key pair; the Android app's devices go
/// through [fcm] (none without it: those pushes fail).
class WebPushSender(
  final VapidKeys keys, {
  final String subject = appOrigin,
  final FcmSender? fcm,
}) {
  bool _toldNoFcm = false;

  Future<PushResult> send(
    PushTarget target,
    Map<String, Object?> message,
  ) async {
    if (!target.isAndroid) {
      return await sendWebPush(target, message, keys, subject: subject);
    }
    if (fcm case final fcm?) return await fcm.send(target, message);
    if (!_toldNoFcm) {
      _toldNoFcm = true;
      stderr.writeln(
        'Android device not reached: FIREBASE_SERVICE_ACCOUNT not set',
      );
    }
    return .failed;
  }
}

/// Sends [message] ({title, body, url, tag}, as [declarativePush]) to
/// [target].
/// Never throws: a network problem is [PushResult.failed].
Future<PushResult> sendWebPush(
  PushTarget target,
  Map<String, Object?> message,
  VapidKeys keys, {
  required String subject,
}) async {
  final endpoint = Uri.parse(target.endpoint);
  final Uint8List body;
  try {
    body = encryptPayload(
      Uint8List.fromList(utf8.encode(jsonEncode(declarativePush(message)))),
      uaPublic: base64UrlDecodeLoose(target.p256dh),
      authSecret: base64UrlDecodeLoose(target.auth),
    );
  } on Object {
    // A subscription with unusable keys can never receive anything.
    return .gone;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .postUrl(endpoint)
        .timeout(const Duration(seconds: 15));
    request.headers
      ..set('TTL', '86400')
      ..set('Urgency', 'normal')
      ..set('Content-Encoding', 'aes128gcm')
      ..set(
        'Authorization',
        vapidAuthorization(endpoint, keys, subject: subject),
      )
      ..contentType = ContentType.binary
      ..contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    final status = response.statusCode;
    if (status >= 200 && status < 300) return .sent;
    if (status == 404 || status == 410) return .gone;
    stderr.writeln('Push to ${endpoint.host}: HTTP $status $text');
    return .failed;
  } on Object catch (e) {
    stderr.writeln('Push to ${endpoint.host} not sent: ${e.runtimeType}');
    return .failed;
  } finally {
    client.close(force: true);
  }
}

String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// base64url with or without padding (browsers send it without).
Uint8List base64UrlDecodeLoose(String text) {
  final clean = text.trim().replaceAll('+', '-').replaceAll('/', '_');
  return base64Url.decode(clean.padRight((clean.length + 3) ~/ 4 * 4, '='));
}

Uint8List _info(String type) =>
    Uint8List.fromList([...utf8.encode('Content-Encoding: $type'), 0]);

Uint8List _hmac(Uint8List key, Uint8List data) =>
    (HMac(SHA256Digest(), 64)..init(KeyParameter(key))).process(data);

/// HKDF-Expand for at most one block (all we need: 12, 16 or 32 bytes).
Uint8List _expand(Uint8List prk, Uint8List info, int length) =>
    Uint8List.sublistView(
      _hmac(prk, Uint8List.fromList([...info, 1])),
      0,
      length,
    );

Uint8List _hkdf(Uint8List salt, Uint8List ikm, Uint8List info, int length) =>
    _expand(_hmac(salt, ikm), info, length);

AsymmetricKeyPair<PublicKey, PrivateKey> _newKeyPair() {
  final generator = ECKeyGenerator()
    ..init(
      ParametersWithRandom(ECKeyGeneratorParameters(_curve), _secureRandom()),
    );
  return generator.generateKeyPair();
}

SecureRandom _secureRandom() =>
    FortunaRandom()..seed(KeyParameter(_randomBytes(32)));

Uint8List _randomBytes(int n) {
  final random = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < n; i++) random.nextInt(256)]);
}

/// Big-endian, left-padded to [length] bytes.
Uint8List _bytes(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

BigInt _bigInt(Uint8List bytes) =>
    bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));

/// A key pair from a private key (tests: the RFC's fixed sender key).
AsymmetricKeyPair<PublicKey, PrivateKey> keyPairFromPrivate(Uint8List d) {
  final private = ECPrivateKey(_bigInt(d), _curve);
  return AsymmetricKeyPair(ECPublicKey(_curve.G * private.d, _curve), private);
}
