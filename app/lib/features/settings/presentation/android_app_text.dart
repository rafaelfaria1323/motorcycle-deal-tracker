/// What Mais offers about the Android app: on an Android phone's browser,
/// to install it; in the app itself, the latest version. Null elsewhere, or
/// when the build has no download ([apkUrl] empty).
({String title, String subtitle})? androidAppOffer({
  required bool android,
  required bool web,
  required String apkUrl,
  required String build,
}) {
  if (!android || apkUrl.isEmpty) return null;
  if (web) {
    return (
      title: 'Instalar a app Android',
      subtitle:
          'Descarregue o ficheiro APK e abra-o; o Android pede para permitir '
          'instalações a partir do navegador',
    );
  }
  return (
    title: 'Descarregar a versão mais recente',
    subtitle: build.isEmpty
        ? 'Instale-a por cima desta; a sessão e os dados ficam'
        : 'Esta é a versão $build. Instale a mais recente por cima desta; a '
              'sessão e os dados ficam',
  );
}
