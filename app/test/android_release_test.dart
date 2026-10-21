import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/android_release.dart';

void main() {
  test('the version file sits next to the APK', () {
    expect(
      releaseInfoUrl(
        'https://github.com/o/r/releases/download/android/app.apk',
      ),
      'https://github.com/o/r/releases/download/android/android.json',
    );
  });

  test('the latest build is read from the version file', () {
    expect(latestBuild('{"build": 57, "commit": "abc"}'), 57);
  });

  test('anything else is unknown', () {
    for (final text in ['', 'Not Found', '[57]', '{"build": "57"}', '{}']) {
      expect(latestBuild(text), isNull, reason: text);
    }
  });
}
