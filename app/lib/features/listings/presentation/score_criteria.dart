import 'score_explanation.dart';

/// Minimum Deal Score choices, on the same thresholds as the score labels.
const minDealScoreOptions = [60, 70, 80, 90];

/// Maximum Risk Score choices: below "Médio" (20) and below "Elevado" (50).
const maxRiskScoreOptions = [19, 49];

/// "Muito bom (80+)".
String dealScoreOptionLabel(int min) => '${ScoreExplainer.label(min)} ($min+)';

/// "Risco baixo" or "Risco até médio".
String riskCriterionLabel(int max) => max < 20
    ? 'Risco baixo'
    : 'Risco até ${ScoreExplainer.riskLabel(max).toLowerCase()}';
