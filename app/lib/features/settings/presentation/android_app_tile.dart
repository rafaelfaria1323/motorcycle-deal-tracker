import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/platform/android_release.dart';
import '../../../core/platform/apk_installer.dart';
import '../../../core/platform/app_build.dart';
import 'android_app_text.dart';
import '../../../core/localization/localizations.dart';

/// "App Android" in Mais. In an Android phone's browser: the latest APK,
/// opened in the browser, which downloads it. In the app: whether a newer
/// version is out, and a tap downloads it and opens Android's installer
/// (no browser). Nothing outside Android.
class const AndroidAppTile({super.key}) extends StatefulWidget {
  static final _android = defaultTargetPlatform == TargetPlatform.android;

  /// Whether there is anything to show here.
  static bool get shown => _android && AppBuild.apkUrl.isNotEmpty;

  @override
  State<AndroidAppTile> createState() => _AndroidAppTileState();
}

class _AndroidAppTileState extends State<AndroidAppTile> {
  int? _latest;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && AndroidAppTile.shown) unawaited(_checkLatest());
  }

  /// The latest published build; left unknown when offline (a tap then
  /// installs the latest anyway).
  Future<void> _checkLatest() async {
    try {
      final text = await ApkInstaller.readText(releaseInfoUrl(AppBuild.apkUrl));
      final latest = text == null ? null : latestBuild(text);
      if (mounted) setState(() => _latest = latest);
    } on Exception {
      return;
    }
  }

  Future<void> _update() async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);
    try {
      await ApkInstaller.install(AppBuild.apkUrl);
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(messageStrings.apkDownloadFailed)),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = androidAppOffer(
      android: AndroidAppTile._android,
      web: kIsWeb,
      apkUrl: AppBuild.apkUrl,
      build: AppBuild.number,
      latest: _latest,
      downloading: _downloading,
      language: context.language,
    );
    if (offer == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.android),
      title: Text(offer.title),
      subtitle: Text(offer.subtitle),
      trailing: _downloading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              offer.enabled
                  ? Icons.download_outlined
                  : Icons.check_circle_outline,
            ),
      onTap: !offer.enabled
          ? null
          : kIsWeb
          ? () => unawaited(
              launchUrl(
                Uri.parse(AppBuild.apkUrl),
                mode: LaunchMode.externalApplication,
              ),
            )
          : () => unawaited(_update()),
    );
  }
}
