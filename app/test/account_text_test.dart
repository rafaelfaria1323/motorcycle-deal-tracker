import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/auth/account_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/tracked_models_text.dart';

void main() {
  test('wrong credentials get a Portuguese message', () {
    expect(
      authErrorText('invalid_credentials', 'Invalid login credentials'),
      'Email ou palavra-passe incorretos.',
    );
  });

  test('each known auth code has its own message', () {
    const unavailable =
        'Esta conta não pode iniciar sessão. Contacte um administrador.';
    const limited =
        'Demasiadas tentativas. Aguarde um momento e tente novamente.';
    for (final (code, text) in [
      (
        'email_not_confirmed',
        'Este email ainda não foi confirmado. '
            'Contacte um administrador.',
      ),
      ('user_banned', unavailable),
      ('user_not_found', unavailable),
      ('over_request_rate_limit', limited),
      ('over_email_send_rate_limit', limited),
    ]) {
      expect(authErrorText(code, 'server text'), text, reason: code);
    }
  });

  test('other auth errors keep the server message', () {
    expect(authErrorText(null, 'Network down'), 'Network down');
  });

  test('catalog save errors map Postgres codes to messages', () {
    expect(catalogSaveErrorText('23505'), 'Esse modelo já está na lista.');
    expect(catalogSaveErrorText('42501'), contains('sessão iniciada'));
    expect(catalogSaveErrorText(null), contains('Tente novamente'));
    expect(catalogSaveErrorText('99999'), contains('Tente novamente'));
  });
}
