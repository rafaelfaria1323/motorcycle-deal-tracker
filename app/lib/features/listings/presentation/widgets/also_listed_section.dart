import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listings_repository.dart';
import '../listing_labels.dart';
import '../../../../core/localization/localizations.dart';

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

        return SectionCard(
          title: context.strings.alsoListedOn,
          children: [
            for (final other in others)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  sourceLabel(other.source, language: context.language),
                ),
                subtitle: Text(
                  other.location ??
                      context.strings.locationNotStatedAlsoListedSection,
                ),
                trailing: Text(
                  Formatters.price(other.price, language: context.language),
                ),
                onTap: () => launchUrl(Uri.parse(other.url)),
              ),
          ],
        );
      },
    );
  }
}
