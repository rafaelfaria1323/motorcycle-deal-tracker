import '../../../core/formatting/formatters.dart';
import '../domain/accounts_repository.dart';

/// The app's name where it is shared.
const appName = 'Motorcycle Deal Tracker';

/// The address of the app at [origin] (`https://….pages.dev`).
String appLink(String origin) => '$origin/';

/// The invite page for [code] (hash routing, as the app's other links).
String inviteLink(String origin, String code) =>
    '$origin/#/join?code=${Uri.encodeQueryComponent(code)}';

const appShareText =
    'Veja as motas usadas à venda em Portugal, com o preço justo e a '
    'pontuação de cada anúncio:';

const inviteShareText =
    'Tem aqui um convite para o Motorcycle Deal Tracker. Abra o link para '
    'criar a sua conta (válido 14 dias, só para uma conta):';

/// What an invite page says when its code can't be used; null when it can.
String? inviteStatusText(InviteStatus status) => switch (status) {
  InviteStatus.ok => null,
  InviteStatus.used =>
    'Este convite já foi usado. Peça um novo a quem o enviou.',
  InviteStatus.expired => 'Este convite expirou. Peça um novo a quem o enviou.',
  InviteStatus.unknown =>
    'Este convite não existe ou foi cancelado. Verifique o link ou peça um '
        'novo.',
};

/// What is wrong with the form, or null.
String? joinFormProblem(String email, String password, String confirmation) {
  final e = email.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
    return 'Indique um email válido.';
  }
  if (password.length < 8) {
    return 'A palavra-passe precisa de pelo menos 8 caracteres.';
  }
  if (password != confirmation) return 'As palavras-passe não coincidem.';
  return null;
}

/// The message for a failed redeem, from the database's error code.
String redeemErrorText(String? code) => switch (code) {
  'P0002' => inviteStatusText(InviteStatus.unknown)!,
  '23505' =>
    'Este email já tem conta. Inicie sessão em Mais › Conta, ou use outro '
        'email.',
  '22023' => 'Verifique o email e a palavra-passe (pelo menos 8 caracteres).',
  '55000' =>
    'A criação de contas ainda não está disponível. Tente daqui a algumas '
        'horas.',
  _ => 'Não foi possível criar a conta. Tente novamente.',
};

/// The second line of an invite in the admin list.
String inviteSubtitle(
  Invite invite, {
  required DateTime now,
  Map<String, String> emails = const {},
}) {
  if (invite.usedAt != null) {
    final who = emails[invite.usedBy];
    return 'Usado${who == null ? '' : ' por $who'} a '
        '${Formatters.date(invite.usedAt!)}';
  }
  if (!invite.expiresAt.isAfter(now)) {
    return 'Expirou a ${Formatters.date(invite.expiresAt)}';
  }
  final days = invite.expiresAt.difference(now).inHours ~/ 24;
  return 'Por usar · expira '
      '${days < 1 ? 'hoje' : 'dentro de $days ${days == 1 ? 'dia' : 'dias'}'}';
}

/// Whether the invite can still make an account.
bool invitePending(Invite invite, DateTime now) =>
    invite.usedAt == null && invite.expiresAt.isAfter(now);

/// The second line of an account in the admin list.
String accountSubtitle(Account account) {
  final parts = [
    if (account.isAdmin) 'Administrador',
    'Criada a ${Formatters.date(account.createdAt)}',
    account.lastSignInAt == null
        ? 'nunca entrou'
        : 'última entrada a ${Formatters.date(account.lastSignInAt!)}',
  ];
  return parts.join(' · ');
}
