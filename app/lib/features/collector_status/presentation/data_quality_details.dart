import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../data/source_quality_repository.dart';
import '../domain/source_quality.dart';
import 'data_quality_text.dart';

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
          return const ListTile(
            dense: true,
            title: Text('Ainda não há anúncios ativos.'),
          );
        }
        return Column(
          children: [
            for (final q in sites)
              ListTile(
                leading: Icon(Icons.fact_check_outlined, color: muted),
                title: Text(qualityTitle(q)),
                subtitle: Text(
                  [
                    qualityMixLine(q),
                    ?qualityMissingLine(q),
                    ?qualityDetailsLine(q),
                    ?qualitySeenLine(q, now),
                    ?qualitySharpPricesLine(q),
                  ].join('\n'),
                ),
              ),
          ],
        );
      },
    );
  }
}
