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
}) {
  if (!android || apkUrl.isEmpty) return null;
  if (web) {
    return (
      title: 'Instalar a app Android',
      subtitle:
          'Descarregue o ficheiro APK e abra-o; o Android pede para permitir '
          'instalações a partir do navegador',
      enabled: true,
    );
  }
  if (downloading) {
    return (
      title: 'A descarregar a versão mais recente',
      subtitle: 'Depois, o Android pede para confirmar a atualização',
      enabled: false,
    );
  }
  final current = int.tryParse(build);
  if (latest != null && current != null && latest <= current) {
    return (
      title: 'A app está atualizada',
      subtitle: 'Versão $build',
      enabled: false,
    );
  }
  const keeps =
      'Toque para a instalar por cima desta; a sessão e os dados ficam';
  if (latest != null) {
    return (
      title: 'Há uma versão nova',
      subtitle: current == null
          ? 'Versão $latest. $keeps'
          : 'Tem a versão $build e já há a $latest. $keeps',
      enabled: true,
    );
  }
  const latestOnTop =
      'Toque para instalar a mais recente por cima desta; a sessão e os '
      'dados ficam';
  return (
    title: 'Atualizar a app',
    subtitle: current == null
        ? latestOnTop
        : 'Esta é a versão $build. $latestOnTop',
    enabled: true,
  );
}
