import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  test('only the push services are reached', () {
    for (final ok in [
      'https://fcm.googleapis.com/fcm/send/abc',
      'https://web.push.apple.com/QABC',
      'https://updates.push.services.mozilla.com/wpush/v2/x',
      'https://wns2-db5p.notify.windows.com/w/?token=x',
      'https://FCM.googleapis.com:443/x',
    ]) {
      expect(isPushService(Uri.parse(ok)), isTrue, reason: ok);
    }
    for (final refused in [
      'https://example.com/fcm.googleapis.com/',
      'https://fcm.googleapis.com.example.com/x',
      'https://fcm.googleapis.com@example.com/x',
      'https://user@fcm.googleapis.com/x',
      'https://notfcm.googleapis.com/x',
      'https://fcm.googleapis.com:8443/x',
      'http://fcm.googleapis.com/x',
      'fcm:token',
    ]) {
      expect(isPushService(Uri.parse(refused)), isFalse, reason: refused);
    }
  });

  test('another address is never called: the device is gone', () async {
    final result = await sendWebPush(
      const PushTarget(
        endpoint: 'https://example.com/p',
        p256dh: 'k',
        auth: 'a',
      ),
      const {'title': 't'},
      VapidKeys.generate(),
      subject: 'https://app.example',
    );
    expect(result, PushResult.gone);
  });

  test("the database's list is the collector's", () {
    final schema = File('../supabase/schema.sql').readAsStringSync();
    final start = schema.indexOf('FUNCTION public.push_endpoint_allowed');
    final body = schema.substring(start, schema.indexOf(r'$$;', start));
    final hosts = RegExp(r"\(fcm.*?\)\(:443\)", dotAll: true)
        .firstMatch(body)!
        .group(0)!
        .replaceAll(RegExp(r"['\s]"), '')
        .replaceAll(r'\.', '.')
        .replaceAll('(:443)', '');
    expect(hosts.substring(1, hosts.length - 1).split('|'), pushServiceHosts);
  });
}
