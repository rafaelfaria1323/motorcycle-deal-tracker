import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/workflows_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/workflows_text.dart';

void main() {
  test('each workflow names its own file', () {
    expect(AppWorkflow.collect.file, 'collect.yml');
    expect(AppWorkflow.weeklySummary.file, 'weekly-summary.yml');
    expect(AppWorkflow.pushTest.file, 'push-test.yml');
  });

  test('the collection warns that it uses the daily budget', () {
    expect(workflowText(AppWorkflow.collect).subtitle, contains('limite'));
    expect(workflowText(AppWorkflow.weeklySummary).title, contains('resumo'));
    expect(workflowText(AppWorkflow.pushTest).title, contains('teste'));
  });

  test('each test notification kind has its code and a name', () {
    expect(PushTestKind.values.map((k) => k.code), [
      'test',
      'new_listing',
      'price_reduction',
      'excellent_opportunity',
      'target_price_reached',
      'listing_removed',
      'back_on_market',
      'run_failed',
      'run_blocked',
      'run_recovered',
    ]);
    final names = PushTestKind.values.map(pushTestKindText).toSet();
    expect(names, hasLength(PushTestKind.values.length));
    expect(pushTestKindText(PushTestKind.priceReduction), 'Baixa de preço');
  });

  test('refusals are explained by their code', () {
    expect(startErrorText('55006'), contains('há pouco'));
    expect(startErrorText('55000'), contains('token'));
    expect(startErrorText('58000'), contains('GitHub recusou'));
    expect(startErrorText('42501'), contains('administrador'));
    expect(startErrorText(null), contains('Tente novamente'));
  });
}
