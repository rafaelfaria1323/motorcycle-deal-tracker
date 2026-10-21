import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/push.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/push_text.dart';

void main() {
  test('without a session there is nothing to switch', () {
    expect(
      pushSubtitle(PushState.off, signedIn: false),
      startsWith('Inicie sessão'),
    );
    expect(pushSwitchEnabled(PushState.off, signedIn: false), isFalse);
  });

  test('the iPhone outside the home-screen app is told how', () {
    expect(
      pushSubtitle(PushState.needsHomeScreen, signedIn: true),
      contains('Adicionar ao ecrã principal'),
    );
    expect(
      pushSwitchEnabled(PushState.needsHomeScreen, signedIn: true),
      isFalse,
    );
  });

  test('on and off can be switched; blocked ones point to the settings', () {
    expect(pushSwitchEnabled(PushState.on, signedIn: true), isTrue);
    expect(pushSwitchEnabled(PushState.off, signedIn: true), isTrue);
    expect(pushSwitchEnabled(PushState.denied, signedIn: true), isFalse);
    expect(
      pushSubtitle(PushState.denied, signedIn: true),
      contains('Definições › Notificações'),
    );
  });

  test("reads the browser's subscription", () {
    expect(
      parseSubscription(
        '{"endpoint":"https://web.push.apple.com/abc","expirationTime":null,'
        '"keys":{"p256dh":"BKey","auth":"Auth"}}',
      ),
      (
        endpoint: 'https://web.push.apple.com/abc',
        p256dh: 'BKey',
        auth: 'Auth',
      ),
    );
  });
}
