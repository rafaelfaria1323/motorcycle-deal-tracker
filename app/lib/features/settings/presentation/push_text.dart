import '../../../core/platform/push.dart';
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
