import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listings_repository.dart';
import '../listing_labels.dart';

class AlsoListedSection extends StatefulWidget {
  const AlsoListedSection({super.key, required this.listing});

  final Listing listing;

  @override
  State<AlsoListedSection> createState() => _AlsoListedSectionState();
}

class _AlsoListedSectionState extends State<AlsoListedSection> {
  late final Future<List<Listing>> _future = getIt<ListingsRepository>()
      .getAlsoListed(widget.listing);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Listing>>(
      future: _future,
      builder: (context, snapshot) {
        final others = snapshot.data;
        if (others == null || others.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Também anunciada em',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final other in others)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sourceLabel(other.source)),
                    subtitle: Text(other.location ?? 'Local não indicado'),
                    trailing: Text(Formatters.price(other.price)),
                    onTap: () => launchUrl(Uri.parse(other.url)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
