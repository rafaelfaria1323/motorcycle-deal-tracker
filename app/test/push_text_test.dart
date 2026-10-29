import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/core/platform/push.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/quiet_hours.dart';
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

  test('the Android app points to the browser', () {
    expect(
      pushSubtitle(PushState.nativeApp, signedIn: true),
      contains('abra a app no Chrome'),
    );
    expect(pushSwitchEnabled(PushState.nativeApp, signedIn: true), isFalse);
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

  test('quiet hours say when alerts wait, in both languages', () {
    expect(
      quietHoursSubtitle(QuietHours.standard),
      startsWith('Das 23:00 às 08:00 (hora de Portugal)'),
    );
    expect(
      quietHoursSubtitle(
        const QuietHours(enabled: true, startHour: 0, endHour: 9),
        language: AppLanguage.english,
      ),
      startsWith('From 00:00 to 09:00 (Portugal time)'),
    );
    expect(
      quietHoursSubtitle(QuietHours.standard.copyWith(enabled: false)),
      startsWith('Desligadas'),
    );
    expect(quietHourText(8), '08:00');
    expect(quietHourText(23), '23:00');
  });
}
