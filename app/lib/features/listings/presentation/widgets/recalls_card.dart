import 'package:material_ui/material_ui.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/open_ad.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/vehicle_recall.dart';
import '../recall_text.dart';

/// The EU's recalls of a listing's model (N.86, Safety Gate): with
/// [applying], those that can cover this bike's year (Avaliação); else
/// the model's other years (Mercado). Each opens the Commission's alert.
/// Nothing when there are none; never part of a score.
class const RecallsCard({
  super.key,
  required final List<VehicleRecall> recalls,
  required final bool applying,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lines = recallLines(
      recalls,
      applying: applying,
      language: context.language,
    );
    if (lines.isEmpty) return const SizedBox.shrink();
    final strings = context.strings;

    return SectionCard(
      title: applying ? strings.recallsTitle : strings.otherRecallsTitle,
      footnote: applying ? strings.recallsNote : strings.otherRecallsNote,
      children: [
        for (final line in lines) RecallTile(line: line, warning: applying),
      ],
    );
  }
}

/// One recall: its name, what it can do and its facts; a tap opens the
/// Commission's alert. With [warning], the icon in the error colour (it
/// can cover the bike in question). Also "A minha mota" and Mercado's
/// models (N.87).
class const RecallTile({
  super.key,
  required final RecallLine line,
  final bool warning = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      Icons.report_outlined,
      color: warning ? Theme.of(context).colorScheme.error : null,
    ),
    title: Text(line.title),
    subtitle: Text([?line.danger, line.facts].join('\n')),
    isThreeLine: line.danger != null,
    trailing: line.link == null ? null : const Icon(Icons.open_in_new),
    onTap: switch (line.link) {
      final link? => () => openAd(link),
      null => null,
    },
  );
}
