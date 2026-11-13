import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/open_ad.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../recall_text.dart';

/// The EU's recalls of the listing's model (N.86, Safety Gate): with
/// [applying], those that can cover this bike's year (Avaliação); else
/// the model's other years (Mercado). Each opens the Commission's alert.
/// Nothing when there are none; never part of a score.
class const RecallsCard({
  super.key,
  required final Listing listing,
  required final bool applying,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lines = recallLines(
      listing.recalls,
      applying: applying,
      language: context.language,
    );
    if (lines.isEmpty) return const SizedBox.shrink();
    final strings = context.strings;
    final theme = Theme.of(context);

    return SectionCard(
      title: applying ? strings.recallsTitle : strings.otherRecallsTitle,
      footnote: applying ? strings.recallsNote : strings.otherRecallsNote,
      children: [
        for (final line in lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.report_outlined,
              color: applying ? theme.colorScheme.error : null,
            ),
            title: Text(line.title),
            subtitle: Text([?line.danger, line.facts].join('\n')),
            isThreeLine: line.danger != null,
            trailing: line.link == null ? null : const Icon(Icons.open_in_new),
            onTap: switch (line.link) {
              final link? => () => openAd(link),
              null => null,
            },
          ),
      ],
    );
  }
}
