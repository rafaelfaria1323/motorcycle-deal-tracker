import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../listing_detail_text.dart';

/// A titled card of label/value rows ("A mota", "O anúncio").
class const FactsCard({
  required final String title,
  required final List<Fact> facts,
  super.key,
}) extends StatelessWidget {
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

class const _FactRow(final String label, final String value)
    extends StatelessWidget {
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
