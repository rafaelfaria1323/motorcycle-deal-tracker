import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/android_app_text.dart';

void main() {
  const apk = 'https://github.com/o/r/releases/download/android/app.apk';

  ({String title, String subtitle, bool enabled})? inApp({
    String build = '42',
    int? latest,
    bool downloading = false,
  }) => androidAppOffer(
    android: true,
    web: false,
    apkUrl: apk,
    build: build,
    latest: latest,
    downloading: downloading,
  );

  test('an Android browser is offered the app', () {
    final offer = androidAppOffer(
      android: true,
      web: true,
      apkUrl: apk,
      build: '',
    );
    expect(offer?.title, 'Instalar a app Android');
    expect(offer?.enabled, isTrue);
  });

  test('a newer build is offered with both numbers', () {
    final offer = inApp(latest: 45);
    expect(offer?.title, 'Há uma versão nova');
    expect(offer?.subtitle, startsWith('Tem a versão 42 e já há a 45.'));
    expect(offer?.enabled, isTrue);
    expect(inApp(build: '', latest: 45)?.subtitle, startsWith('Versão 45.'));
  });

  test('the same or an older build is up to date, with nothing to tap', () {
    for (final latest in [42, 41]) {
      final offer = inApp(latest: latest);
      expect(offer?.title, 'A app está atualizada');
      expect(offer?.subtitle, 'Versão 42');
      expect(offer?.enabled, isFalse);
    }
  });

  test('without the latest build it still offers the update', () {
    final offer = inApp();
    expect(offer?.title, 'Atualizar a app');
    expect(offer?.subtitle, startsWith('Esta é a versão 42.'));
    expect(offer?.enabled, isTrue);
    expect(inApp(build: '', latest: 3)?.title, 'Há uma versão nova');
    expect(inApp(build: '')?.subtitle, startsWith('Toque para instalar'));
  });

  test('while downloading, a tap does nothing', () {
    final offer = inApp(latest: 45, downloading: true);
    expect(offer?.title, 'A descarregar a versão mais recente');
    expect(offer?.enabled, isFalse);
  });

  test('nothing outside Android or without a download', () {
    expect(
      androidAppOffer(android: false, web: true, apkUrl: apk, build: ''),
      isNull,
    );
    expect(
      androidAppOffer(android: true, web: true, apkUrl: '', build: ''),
      isNull,
    );
  });
}
