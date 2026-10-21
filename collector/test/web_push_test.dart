import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collector/src/notify/web_push.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  test('encrypts exactly as RFC 8291 appendix A', () {
    final body = encryptPayload(
      Uint8List.fromList(
        utf8.encode('When I grow up, I want to be a watermelon'),
      ),
      uaPublic: base64UrlDecodeLoose(
        'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',
      ),
      authSecret: base64UrlDecodeLoose('BTBZMqHH6r4Tts7J_aSIgg'),
      salt: base64UrlDecodeLoose('DGv6ra1nlYgDCS1FRnbzlw'),
      ephemeral: keyPairFromPrivate(
        base64UrlDecodeLoose('yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw'),
      ),
    );

    expect(
      base64UrlNoPad(body),
      'DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN',
    );
  });

  test('a generated key round-trips through its stored text', () {
    final keys = VapidKeys.generate();
    final again = VapidKeys.fromBase64(keys.privateBase64, keys.publicBase64);

    expect(keys.publicKey, hasLength(65));
    expect(again.privateKey, keys.privateKey);
    expect(again.publicBase64, keys.publicBase64);
  });

  test(
    'the VAPID header is a JWT for the push service, signed with our key',
    () {
      final keys = VapidKeys.generate();
      final header = vapidAuthorization(
        Uri.parse('https://web.push.apple.com/QGuQyavXutnMH-abc'),
        keys,
        subject: 'https://example.pages.dev',
        now: DateTime.utc(2026, 10, 21, 8),
      );

      final match = RegExp(
        r'^vapid t=([^.]+)\.([^.]+)\.([^,]+), k=(.+)$',
      ).firstMatch(header)!;
      final claims =
          jsonDecode(utf8.decode(base64UrlDecodeLoose(match[2]!))) as Map;
      expect(claims, {
        'aud': 'https://web.push.apple.com',
        'exp': DateTime.utc(2026, 10, 21, 20).millisecondsSinceEpoch ~/ 1000,
        'sub': 'https://example.pages.dev',
      });
      expect(match[4], keys.publicBase64);

      final raw = base64UrlDecodeLoose(match[3]!);
      expect(raw, hasLength(64));
      final curve = ECCurve_secp256r1();
      final verifier = Signer('SHA-256/ECDSA')
        ..init(
          false,
          PublicKeyParameter<ECPublicKey>(
            ECPublicKey(curve.curve.decodePoint(keys.publicKey), curve),
          ),
        );
      BigInt big(List<int> b) =>
          b.fold(BigInt.zero, (a, x) => (a << 8) | BigInt.from(x));
      expect(
        verifier.verifySignature(
          Uint8List.fromList(utf8.encode('${match[1]}.${match[2]}')),
          ECSignature(big(raw.sublist(0, 32)), big(raw.sublist(32))),
        ),
        isTrue,
      );
    },
  );

  group('sending', () {
    late HttpServer server;
    var status = 201;
    HttpHeaders? headers;
    var bodyLength = 0;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        headers = request.headers;
        bodyLength = (await request.toList()).fold(0, (n, c) => n + c.length);
        request.response.statusCode = status;
        await request.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    // A real browser key pair stands in for the device.
    final device = VapidKeys.generate();
    PushTarget target(String path) => PushTarget(
      endpoint: 'http://127.0.0.1:${server.port}/$path',
      p256dh: device.publicBase64,
      auth: base64UrlNoPad(List.filled(16, 7)),
    );
    final sender = WebPushSender(VapidKeys.generate());

    test('an accepted push is sent, encrypted and signed', () async {
      status = 201;
      expect(await sender.send(target('a'), {'title': 'Olá'}), PushResult.sent);
      expect(headers!.value('content-encoding'), 'aes128gcm');
      expect(headers!.value('ttl'), '86400');
      expect(headers!.value('authorization'), startsWith('vapid t='));
      // Salt, record size, key length and key (86) + text + tag (16).
      expect(bodyLength, greaterThan(86 + 16));
    });

    test('404 and 410 mean the device is gone; others fail', () async {
      status = 410;
      expect(await sender.send(target('b'), {}), PushResult.gone);
      status = 404;
      expect(await sender.send(target('b'), {}), PushResult.gone);
      status = 500;
      expect(await sender.send(target('b'), {}), PushResult.failed);
    });

    test('a device with unusable keys is gone without a request', () async {
      final broken = PushTarget(
        endpoint: 'http://127.0.0.1:${server.port}/c',
        p256dh: 'bm90LWEta2V5',
        auth: 'x',
      );
      expect(await sender.send(broken, {}), PushResult.gone);
    });

    test('an unreachable push service fails', () async {
      final port = server.port;
      await server.close(force: true);
      final away = PushTarget(
        endpoint: 'http://127.0.0.1:$port/d',
        p256dh: device.publicBase64,
        auth: base64UrlNoPad(List.filled(16, 7)),
      );
      expect(await sender.send(away, {}), PushResult.failed);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });
  });
}
