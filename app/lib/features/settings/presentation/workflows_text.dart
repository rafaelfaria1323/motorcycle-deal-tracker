import '../domain/workflows_repository.dart';

/// What a run-now tile says, and asks before starting.
({String title, String subtitle, String started}) workflowText(
  AppWorkflow workflow,
) => switch (workflow) {
  AppWorkflow.collect => (
    title: 'Recolher agora',
    subtitle:
        'Lê os sites já, fora do horário (os pedidos ficam em Estado da '
        'recolha)',
    started:
        'Recolha iniciada. Os anúncios novos aparecem daqui a cerca de 10 '
        'minutos.',
  ),
  AppWorkflow.weeklySummary => (
    title: 'Enviar o resumo da semana',
    subtitle: 'Os últimos 7 dias dos seus modelos, já, neste aparelho',
    started:
        'Resumo pedido. Chega dentro de 1 a 2 minutos e fica em Mais › '
        'Resumo da semana.',
  ),
  AppWorkflow.pushTest => (
    title: 'Enviar notificação de teste',
    subtitle:
        'Escolha qual, para confirmar que os alertas chegam aos seus '
        'aparelhos e abrem a página certa',
    started:
        'Notificação de teste pedida. Chega dentro de 1 a 2 minutos; se '
        'não chegar, desative e volte a ativar as notificações.',
  ),
};

/// How the test notification picker names each example.
String pushTestKindText(PushTestKind kind) => switch (kind) {
  PushTestKind.test => 'Notificação de teste simples',
  PushTestKind.newListing => 'Novo anúncio',
  PushTestKind.priceReduction => 'Baixa de preço',
  PushTestKind.excellentOpportunity => 'Excelente oportunidade',
  PushTestKind.targetPriceReached => 'Chegou ao seu preço',
  PushTestKind.listingRemoved => 'Anúncio removido',
  PushTestKind.backOnMarket => 'Voltou ao mercado',
  PushTestKind.runFailed => 'A recolha falhou (administradores)',
  PushTestKind.runBlocked => 'Um site recusou a recolha (administradores)',
  PushTestKind.runRecovered => 'A recolha voltou a funcionar (administradores)',
};

/// Why `start_workflow` refused, from its error code.
String startErrorText(String? code) => switch (code) {
  '55006' => 'Já foi pedido há pouco. Aguarde um momento e tente novamente.',
  '55000' => 'Falta o token do GitHub no Vault do Supabase.',
  '58000' =>
    'O GitHub recusou o pedido. Verifique o token do GitHub (Actions: '
        'leitura e escrita).',
  '42501' => 'Só um administrador pode fazer isto.',
  _ => 'Não foi possível iniciar. Tente novamente.',
};
