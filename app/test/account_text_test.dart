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
