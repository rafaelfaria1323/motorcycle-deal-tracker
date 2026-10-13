import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../score_explanation.dart';

class ScoreExplanationCard extends StatelessWidget {
  const ScoreExplanationCard({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final explanation = ScoreExplainer.explain(listing);
    if (explanation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final risk = listing.riskScore;
    final used = explanation.slicesUsed;
    final total = explanation.slicesTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deal Score ${explanation.score} · ${explanation.label}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final line in explanation.lines) _LineRow(line: line),
            if (risk != null) ...[
              const Divider(height: 24),
              Text('Risco $risk/100 · ${ScoreExplainer.riskLabel(risk)}', style: theme.textTheme.titleSmall),
            ],
            if (used != null && total != null) ...[
              const SizedBox(height: 8),
              Text(
                'Baseado em $used de $total fatores',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final ExplanationLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, semantic) = switch (line.tone) {
      ExplanationTone.positive => (Icons.add_circle_outline, const Color(0xFF2E7D32), 'Positivo'),
      ExplanationTone.negative => (Icons.remove_circle_outline, scheme.error, 'Negativo'),
      ExplanationTone.neutral => (Icons.info_outline, scheme.onSurfaceVariant, 'Informação'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color, semanticLabel: semantic),
          const SizedBox(width: 8),
          Expanded(child: Text(line.text)),
        ],
      ),
    );
  }
}
