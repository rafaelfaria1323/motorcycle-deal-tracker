import '../domain/workflows_repository.dart';

/// What a run-now tile says, and asks before starting.
({String title, String subtitle, String started}) workflowText(
  AppWorkflow workflow,
) => switch (workflow) {
  AppWorkflow.collect => (
    title: 'Recolher agora',
    subtitle:
        'Lê os sites já, fora do horário. Usa pedidos do limite diário de '
        'cada site',
    started:
        'Recolha iniciada. Os anúncios novos aparecem daqui a cerca de 10 '
        'minutos.',
  ),
  AppWorkflow.weeklySummary => (
    title: 'Enviar o resumo da semana',
    subtitle: 'Envia já para o Telegram o resumo dos últimos 7 dias',
    started: 'Resumo pedido. Chega ao Telegram dentro de alguns minutos.',
  ),
  AppWorkflow.pushTest => (
    title: 'Enviar notificação de teste',
    subtitle: 'Para confirmar que os alertas chegam aos seus aparelhos',
    started:
        'Notificação de teste pedida. Chega dentro de 1 a 2 minutos; se '
        'não chegar, desative e volte a ativar as notificações.',
  ),
};

/// Why `start_workflow` refused, from its error code.
String startErrorText(String? code) => switch (code) {
  '55006' => 'Já foi pedido há poucos minutos. Tente mais tarde.',
  '55000' => 'Falta o token do GitHub no Vault do Supabase.',
  '58000' =>
    'O GitHub recusou o pedido. Verifique o token do GitHub (Actions: '
        'leitura e escrita).',
  '42501' => 'Só um administrador pode fazer isto.',
  _ => 'Não foi possível iniciar. Tente novamente.',
};
