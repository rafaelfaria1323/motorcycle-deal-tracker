import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../data/source_quality_repository.dart';
import '../domain/source_quality.dart';
import 'data_quality_text.dart';
import '../../../core/localization/localizations.dart';

/// Per site: live listings, how many are tracked models, unmatched or
/// duplicates, the facts the scored ones miss, when its listings were last
/// seen and prices that jumped suspiciously.
class DataQualityDetails extends StatefulWidget {
  const DataQualityDetails({super.key});

  @override
  State<DataQualityDetails> createState() => _DataQualityDetailsState();
}

class _DataQualityDetailsState extends State<DataQualityDetails> {
  late final Future<List<SourceQuality>> _future =
      getIt<SourceQualityRepository>().getAll().catchError(
        (_) => const <SourceQuality>[],
      );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    return FutureBuilder<List<SourceQuality>>(
      future: _future,
      builder: (context, snapshot) {
        final sites = snapshot.data;
        if (sites == null) return const SizedBox(height: 56);
        if (sites.isEmpty) {
          return ListTile(
            dense: true,
            title: Text(context.strings.thereAreNoActiveListingsYet),
          );
        }
        return Column(
          children: [
            for (final q in sites)
              ListTile(
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
