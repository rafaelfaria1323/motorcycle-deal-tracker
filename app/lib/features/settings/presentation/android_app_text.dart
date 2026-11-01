import '../../../core/localization/localizations.dart';

/// What Mais offers about the Android app: on an Android phone's browser,
/// to install it; in the app itself, to update it (it compares its own
/// [build] with the [latest] one published, null while unknown). Null
/// elsewhere, or when the build has no download ([apkUrl] empty). [enabled]:
/// whether a tap does something.
({String title, String subtitle, bool enabled})? androidAppOffer({
  required bool android,
  required bool web,
  required String apkUrl,
  required String build,
  int? latest,
  bool downloading = false,
  AppLanguage language = .portuguese,
}) {
  if (!android || apkUrl.isEmpty) return null;
  if (web) {
    return (
      title: language.messages.installAndroidApp,
      subtitle: language.messages.downloadAndOpenAPKFileAndroidWillAsk,
      enabled: true,
    );
  }
  if (downloading) {
    return (
      title: language.messages.downloadingLatestVersion,
      subtitle: language.messages.androidWillThenAskYouToConfirmUpdate,
      enabled: false,
    );
  }
  final current = int.tryParse(build);
  if (latest != null && current != null && latest <= current) {
    return (
      title: language.messages.appIsUpToDate,
      subtitle: language.messages.version(build: build),
      enabled: false,
    );
  }
  final keeps = language.messages.tapToInstallItOverThisVersionYour;
  if (latest != null) {
    return (
      title: language.messages.newVersionIsAvailable,
      subtitle: current == null
          ? language.messages.androidVersionLine(
              latest: (latest).toString(),
              keeps: keeps,
            )
          : language.messages.youHaveVersionVersionIsAvailable(
              build: build,
              latest: (latest).toString(),
              keeps: keeps,
            ),
      enabled: true,
    );
  }
  final latestOnTop = language.messages.tapToInstallLatestVersionOverThisOne;
  return (
    title: language.messages.updateApp,
    subtitle: current == null
        ? latestOnTop
        : language.messages.thisIsVersion(
            build: build,
            latestOnTop: latestOnTop,
          ),
    enabled: true,
  );
}
