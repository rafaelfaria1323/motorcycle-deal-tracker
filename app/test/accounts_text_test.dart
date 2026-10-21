import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/accounts_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/accounts_text.dart';

void main() {
  const origin = 'https://motorcycle-deal-tracker.pages.dev';
  final now = DateTime(2026, 10, 21, 12);

  Invite invite({DateTime? expiresAt, DateTime? usedAt, String? usedBy}) =>
      Invite(
        code: 'abc',
        createdAt: now.subtract(const Duration(days: 1)),
        expiresAt: expiresAt ?? now.add(const Duration(days: 13, hours: 2)),
        usedAt: usedAt,
        usedBy: usedBy,
      );

  test('links open the app and the invite page', () {
    expect(appLink(origin), '$origin/');
    expect(inviteLink(origin, 'a-b_c'), '$origin/#/join?code=a-b_c');
  });

  test('only a usable invite has no status message', () {
    expect(inviteStatusText(InviteStatus.ok), isNull);
    expect(inviteStatusText(InviteStatus.used), contains('já foi usado'));
    expect(inviteStatusText(InviteStatus.expired), contains('expirou'));
    expect(inviteStatusText(InviteStatus.unknown), contains('não existe'));
  });

  test('the form needs an email, 8 characters and the same twice', () {
    expect(
      joinFormProblem('ana', 'longenough', 'longenough'),
      contains('email'),
    );
    expect(joinFormProblem('a@b.pt', 'short', 'short'), contains('8'));
    expect(
      joinFormProblem('a@b.pt', 'longenough', 'longenougH'),
      contains('não coincidem'),
    );
    expect(joinFormProblem(' a@b.pt ', 'longenough', 'longenough'), isNull);
  });

  test('database errors become messages', () {
    expect(redeemErrorText('23505'), contains('já tem conta'));
    expect(redeemErrorText('55000'), contains('ainda não está disponível'));
    expect(redeemErrorText('P0002'), contains('não existe'));
    expect(redeemErrorText(null), contains('Tente novamente'));
  });

  test('an invite says whether it is pending, used or expired', () {
    expect(invitePending(invite(), now), isTrue);
    expect(
      inviteSubtitle(invite(), now: now),
      'Por usar · expira dentro de 13 dias',
    );
    expect(
      inviteSubtitle(
        invite(expiresAt: now.add(const Duration(hours: 30))),
        now: now,
      ),
      'Por usar · expira dentro de 1 dia',
    );
    expect(
      inviteSubtitle(
        invite(expiresAt: now.add(const Duration(hours: 3))),
        now: now,
      ),
      'Por usar · expira hoje',
    );

    final expired = invite(expiresAt: now.subtract(const Duration(days: 1)));
    expect(invitePending(expired, now), isFalse);
    expect(inviteSubtitle(expired, now: now), startsWith('Expirou a '));

    final used = invite(usedAt: now, usedBy: 'u2');
    expect(invitePending(used, now), isFalse);
    expect(
      inviteSubtitle(used, now: now, emails: {'u2': 'ana@b.pt'}),
      'Usado por ana@b.pt a 21/10/2026',
    );
    expect(inviteSubtitle(used, now: now), 'Usado a 21/10/2026');
  });

  test('an account shows its role and last sign-in', () {
    final account = Account(
      id: 'u1',
      email: 'ana@b.pt',
      createdAt: DateTime(2026, 10, 1, 12),
      isAdmin: true,
    );
    expect(
      accountSubtitle(account),
      'Administrador · Criada a 01/10/2026 · nunca entrou',
    );
    expect(
      Account.fromJson({
        'user_id': 'u2',
        'email': 'b@c.pt',
        'created_at': '2026-10-01T10:00:00Z',
        'last_sign_in_at': '2026-10-20T10:00:00Z',
        'is_admin': false,
        'is_me': true,
      }).isMe,
      isTrue,
    );
  });
}
