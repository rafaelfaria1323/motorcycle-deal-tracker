import '../../../core/platform/push.dart';
import '../domain/quiet_hours.dart';
import '../../../core/localization/localizations.dart';

/// The subtitle of "Notificações neste aparelho" in Mais.
String pushSubtitle(
  PushState state, {
  required bool signedIn,
  AppLanguage language = AppLanguage.portuguese,
}) {
  if (!signedIn) return language.messages.signInToReceiveAlertsOnThisDevice;
  return switch (state) {
    PushState.on => language.messages.pushEnabled,
    PushState.off => language.messages.receiveAlertsOnThisDeviceTapToOpen,
    PushState.needsHomeScreen =>
      language.messages.onIPhoneOpenAppFromHomeScreenShare,
    PushState.denied => language.messages.pushBlocked,
    PushState.unsupported =>
      language.messages.thisBrowserDoesNotSupportNotifications,
    PushState.nativeApp => language.messages.pushNotConfiguredAndroid,
  };
}

/// Whether the switch can be used.
bool pushSwitchEnabled(PushState state, {required bool signedIn}) =>
    signedIn && (state == PushState.on || state == PushState.off);

/// The subtitle of "Horas de silêncio" in Mais.
String quietHoursSubtitle(
  QuietHours hours, {
  AppLanguage language = AppLanguage.portuguese,
}) => hours.enabled
    ? language.messages.quietHoursOn(
        start: quietHourText(hours.startHour),
        end: quietHourText(hours.endHour),
      )
    : language.messages.quietHoursOff;

/// An hour of the day as a time: 8 -> "08:00".
String quietHourText(int hour) => '${hour.toString().padLeft(2, '0')}:00';
