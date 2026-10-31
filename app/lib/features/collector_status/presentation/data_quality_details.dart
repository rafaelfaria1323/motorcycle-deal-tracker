import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../domain/source_quality.dart';
import 'data_quality_text.dart';
import '../../../core/localization/localizations.dart';

/// Per site: live listings, how many are tracked models, unmatched or
/// duplicates, the facts the scored ones miss, when its listings were last
/// seen and prices that jumped suspiciously. In "Estado da recolha" (F.5);
/// null [quality] once it could not be read.
class const DataQualityDetails({
  required final Future<List<SourceQuality>?> quality,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    return FutureBuilder<List<SourceQuality>?>(
      future: quality,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return BulletLine(context.strings.readingDataQuality);
        }
        final sites = snapshot.data;
        if (sites == null) {
          return BulletLine(context.strings.couldNotReadDataQuality);
        }
        if (sites.isEmpty) {
          return BulletLine(context.strings.thereAreNoActiveListingsYet);
        }
        return Column(
          children: [
            for (final q in sites)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.fact_check_outlined, color: muted),
                title: Text(qualityTitle(q, language: context.language)),
                subtitle: Text(
                  [
                    qualityMixLine(q, language: context.language),
                    ?qualityMissingLine(q, language: context.language),
                    ?qualityDetailsLine(q, language: context.language),
                    ?qualitySeenLine(q, now, language: context.language),
                    ?qualitySharpPricesLine(q, language: context.language),
                  ].join('\n'),
                ),
              ),
          ],
        );
      },
    );
  }
}
