import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_criteria.dart';

void main() {
  test('options use the same words as the score labels', () {
    expect(
      [for (final m in minDealScoreOptions) dealScoreOptionLabel(m)],
      [
        'Normal (60+)',
        'Interessante (70+)',
        'Muito bom (80+)',
        'Excelente (90+)',
      ],
    );
    expect(
      [for (final m in maxRiskScoreOptions) riskCriterionLabel(m)],
      ['Risco baixo', 'Risco até médio'],
    );
  });
}
