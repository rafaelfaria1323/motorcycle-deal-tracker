import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../new_price_text.dart';
import '../../../../core/localization/localizations.dart';

class NewPriceCard extends StatelessWidget {
  const NewPriceCard({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final lines = newPriceLines(listing, language: context.language);
    if (lines.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: context.strings.comparisonWithNewBike,
      children: [
        for (final line in lines) BulletLine(line, icon: Icons.sell_outlined),
      ],
    );
  }
}
