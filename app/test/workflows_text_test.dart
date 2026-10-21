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

  test('refusals are explained by their code', () {
    expect(startErrorText('55006'), contains('há poucos minutos'));
    expect(startErrorText('55000'), contains('token'));
    expect(startErrorText('58000'), contains('GitHub recusou'));
    expect(startErrorText('42501'), contains('administrador'));
    expect(startErrorText(null), contains('Tente novamente'));
  });
}
