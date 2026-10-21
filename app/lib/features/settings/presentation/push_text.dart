import '../../../core/platform/push.dart';

/// The subtitle of "Notificações neste aparelho" in Mais.
String pushSubtitle(PushState state, {required bool signedIn}) {
  if (!signedIn) return 'Inicie sessão para receber os alertas neste aparelho';
  return switch (state) {
    PushState.on =>
      'Ativas: os alertas chegam depois de cada recolha e, ao tocar, abrem '
          'o anúncio',
    PushState.off =>
      'Receba os alertas neste aparelho; ao tocar, abre o anúncio na app',
    PushState.needsHomeScreen =>
      'No iPhone, abra a app a partir do ecrã principal (Partilhar › '
          'Adicionar ao ecrã principal) para as ativar',
    PushState.denied =>
      'Bloqueadas neste aparelho: permita-as nas definições (no iPhone, '
          'Definições › Notificações)',
    PushState.unsupported => 'Este navegador não recebe notificações',
    PushState.nativeApp =>
      'A app Android ainda não recebe notificações: para as receber, abra a '
          'app no Chrome e ative-as lá',
  };
}

/// Whether the switch can be used.
bool pushSwitchEnabled(PushState state, {required bool signedIn}) =>
    signedIn && (state == PushState.on || state == PushState.off);
