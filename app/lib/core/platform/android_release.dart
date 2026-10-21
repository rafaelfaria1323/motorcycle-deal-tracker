import 'dart:convert';

/// The version file the deploy publishes next to the APK
/// (`{"build": 123}`), at the same address with its own name.
String releaseInfoUrl(String apkUrl) =>
    apkUrl.replaceFirst(RegExp(r'[^/]*$'), 'android.json');

/// The latest build named in the version file; null when it can't be read.
int? latestBuild(String json) {
  try {
    final Object? data = jsonDecode(json);
    if (data is Map<String, Object?>) {
      final build = data['build'];
      if (build is int) return build;
    }
  } on FormatException {
    return null;
  }
  return null;
}
