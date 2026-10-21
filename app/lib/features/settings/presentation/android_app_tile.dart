import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/platform/app_build.dart';
import 'android_app_text.dart';

/// "App Android" in Mais: the latest APK, opened in the browser, which
/// downloads it. Nothing outside Android.
class AndroidAppTile extends StatelessWidget {
  const AndroidAppTile({super.key});

  static final _offer = androidAppOffer(
    android: defaultTargetPlatform == TargetPlatform.android,
    web: kIsWeb,
    apkUrl: AppBuild.apkUrl,
    build: AppBuild.number,
  );

  /// Whether there is anything to show here.
  static bool get shown => _offer != null;

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    if (offer == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.android),
      title: Text(offer.title),
      subtitle: Text(offer.subtitle),
      trailing: const Icon(Icons.download_outlined),
      onTap: () => unawaited(
        launchUrl(
          Uri.parse(AppBuild.apkUrl),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }
}
