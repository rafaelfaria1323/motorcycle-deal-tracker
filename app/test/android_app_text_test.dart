import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/android_app_text.dart';

void main() {
  const apk = 'https://github.com/o/r/releases/download/android/app.apk';

  test('an Android browser is offered the app', () {
    final offer = androidAppOffer(
      android: true,
      web: true,
      apkUrl: apk,
      build: '',
    );
    expect(offer?.title, 'Instalar a app Android');
  });

  test('the app itself offers the latest version and says its own', () {
    final offer = androidAppOffer(
      android: true,
      web: false,
      apkUrl: apk,
      build: '42',
    );
    expect(offer?.title, 'Descarregar a versão mais recente');
    expect(offer?.subtitle, startsWith('Esta é a versão 42.'));
    expect(
      androidAppOffer(android: true, web: false, apkUrl: apk, build: ''),
      isNotNull,
    );
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
