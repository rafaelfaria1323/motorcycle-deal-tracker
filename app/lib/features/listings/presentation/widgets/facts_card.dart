import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../listing_detail_text.dart';

/// A titled card of label/value rows ("A mota", "O anúncio").
class FactsCard extends StatelessWidget {
  const FactsCard({required this.title, required this.facts, super.key});

  final String title;
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      children: [
        for (final (i, (label, value)) in facts.indexed) ...[
          if (i > 0) const Divider(height: 1),
          _FactRow(label, value),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
