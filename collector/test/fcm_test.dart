import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collector/src/notify/fcm.dart';
import 'package:collector/src/notify/web_push.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

/// A key made for the test (never a real one in the repository), as the
/// PKCS#8 PEM Google puts in a service account's JSON.
final _pair = () {
  final random = Random.secure();
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
        FortunaRandom()..seed(
          KeyParameter(
            Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
          ),
        ),
      ),
    );
  return generator.generateKeyPair();
}();

String _pem(RSAPrivateKey key) {
  final one = BigInt.one;
  final rsa = ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero),
      ASN1Integer(key.modulus),
      ASN1Integer(key.publicExponent),
      ASN1Integer(key.privateExponent),
      ASN1Integer(key.p),
      ASN1Integer(key.q),
      ASN1Integer(key.privateExponent! % (key.p! - one)),
      ASN1Integer(key.privateExponent! % (key.q! - one)),
      ASN1Integer(key.q!.modInverse(key.p!)),
    ],
  );
  final info = ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero),
      ASN1Sequence(
        elements: [
          ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
          ASN1Null(),
        ],
      ),
      ASN1OctetString(octets: rsa.encode()),
    ],
  );
  final text = base64.encode(info.encode());
  final lines = [
    for (var i = 0; i < text.length; i += 64)
      text.substring(i, min(i + 64, text.length)),
  ];
  return '-----BEGIN PRIVATE KEY-----\n${lines.join('\n')}\n-----END PRIVATE KEY-----\n';
}

String _account() => jsonEncode({
  'type': 'service_account',
  'project_id': 'deal-tracker',
  'client_id': '1234',
  'client_email': 'push@deal-tracker.iam.gserviceaccount.com',
  'private_key': _pem(_pair.privateKey),
  'token_uri': 'https://oauth2.googleapis.com/token',
});

bool _verifies(String jwt) {
  final parts = jwt.split('.');
  final verifier = Signer('SHA-256/RSA')
    ..init(false, PublicKeyParameter<RSAPublicKey>(_pair.publicKey));
  return verifier.verifySignature(
    Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}')),
    RSASignature(base64UrlDecodeLoose(parts[2])),
  );
}

Map<String, Object?> _claims(String jwt) =>
    jsonDecode(utf8.decode(base64UrlDecodeLoose(jwt.split('.')[1])))
        as Map<String, Object?>;

void main() {
  test('reads the service account and its key', () {
    final account = FcmAccount.fromJson(_account());
    expect(account.projectId, 'deal-tracker');
    expect(
      account.credentials.email,
      'push@deal-tracker.iam.gserviceaccount.com',
    );
    expect(
      () => FcmAccount.fromJson('{"project_id": "x"}'),
      throwsFormatException,
    );
    expect(
      () => FcmAccount.fromJson(
        jsonEncode({
          'type': 'service_account',
          'project_id': 'x',
          'client_id': '1',
          'client_email': 'e',
          'private_key': 'junk',
        }),
      ),
      throwsFormatException,
    );
    expect(() => FcmAccount.fromJson('not json'), throwsFormatException);
  });

  test('the message is data the app shows itself', () {
    expect(
      fcmMessage('tok', {
        'title': 'T',
        'body': 'B',
        'url': '/#/deals/1',
        'tag': null,
        'language': 'en',
      }),
      {
        'message': {
          'token': 'tok',
          'data': {
            'title': 'T',
            'body': 'B',
            'url': '/#/deals/1',
            'language': 'en',
          },
          'android': {'priority': 'HIGH', 'ttl': '86400s'},
        },
      },
    );
  });

  test('without the secret there is no sender', () {
    expect(FcmSender.fromEnvironment({}), isNull);
    expect(
      FcmSender.fromEnvironment({'FIREBASE_SERVICE_ACCOUNT': '{}'}),
      isNull,
    );
    expect(
      FcmSender.fromEnvironment({'FIREBASE_SERVICE_ACCOUNT': _account()}),
      isNotNull,
    );
  });

  group('sending', () {
    var tokenStatus = 200;
    var sendStatus = 200;
    var sendText = '{}';
    var tokenRequests = 0;
    final sent = <Map<String, Object?>>[];
    String? authorization;

    setUp(() {
      tokenRequests = 0;
      sent.clear();
    });

    final google = MockClient((request) async {
      if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
        tokenRequests++;
        final form = request.bodyFields;
        expect(
          form['grant_type'],
          'urn:ietf:params:oauth:grant-type:jwt-bearer',
        );
        final jwt = form['assertion']!;
        expect(_verifies(jwt), isTrue);
        expect(_claims(jwt), {
          'iss': 'push@deal-tracker.iam.gserviceaccount.com',
          'scope': 'https://www.googleapis.com/auth/firebase.messaging',
          'aud': 'https://oauth2.googleapis.com/token',
          'iat': isA<int>(),
          'exp': isA<int>(),
        });
        return http.Response(
          jsonEncode({
            'access_token': 'ya29.test',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          tokenStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(
        request.url.toString(),
        'https://fcm.googleapis.com/v1/projects/deal-tracker/messages:send',
      );
      authorization = request.headers['authorization'];
      sent.add(jsonDecode(request.body) as Map<String, Object?>);
      return http.Response(sendText, sendStatus);
    });

    FcmSender sender({http.Client? client}) =>
        FcmSender(FcmAccount.fromJson(_account()), client: client ?? google);
    const phone = PushTarget(endpoint: 'fcm:abc:DEF_123', p256dh: '', auth: '');

    test('signs in once and sends each message to the token', () async {
      tokenStatus = sendStatus = 200;
      final fcm = sender();
      expect(await fcm.send(phone, {'title': 'Olá'}), PushResult.sent);
      expect(await fcm.send(phone, {'title': 'Outra'}), PushResult.sent);
      expect(tokenRequests, 1);
      expect(authorization, 'Bearer ya29.test');
      expect(sent.map((m) => (m['message']! as Map)['token']), [
        'abc:DEF_123',
        'abc:DEF_123',
      ]);
    });

    test('an unregistered or invalid token is gone; others fail', () async {
      tokenStatus = 200;
      final fcm = sender();
      sendStatus = 404;
      expect(await fcm.send(phone, {}), PushResult.gone);
      sendStatus = 400;
      sendText =
          '{"error": {"status": "INVALID_ARGUMENT", "message": '
          '"The registration token is not a valid FCM registration token"}}';
      expect(await fcm.send(phone, {}), PushResult.gone);
      sendText =
          '{"error": {"status": "INVALID_ARGUMENT", "message": "bad data"}}';
      expect(await fcm.send(phone, {}), PushResult.failed);
      sendStatus = 503;
      expect(await fcm.send(phone, {}), PushResult.failed);
    });

    test('a refused sign-in fails every push without sending', () async {
      tokenStatus = 401;
      final fcm = sender();
      expect(await fcm.send(phone, {}), PushResult.failed);
      expect(await fcm.send(phone, {}), PushResult.failed);
      expect(sent, isEmpty);
      expect(tokenRequests, 1);
    });

    test('a network problem fails the push', () async {
      final down = MockClient(
        (_) async => throw const SocketException('unreachable'),
      );
      expect(await sender(client: down).send(phone, {}), PushResult.failed);
    });

    test('the Web Push sender hands Android devices to FCM', () async {
      tokenStatus = sendStatus = 200;
      final push = WebPushSender(VapidKeys.generate(), fcm: sender());
      expect(await push.send(phone, {'title': 'Olá'}), PushResult.sent);
      expect(sent, hasLength(1));
      expect(
        await WebPushSender(VapidKeys.generate()).send(phone, {}),
        PushResult.failed,
      );
    });
  });
}
