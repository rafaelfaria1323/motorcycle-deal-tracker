import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../new_price_text.dart';
import '../../../../core/localization/localizations.dart';

class const NewPriceCard({required final Listing listing, super.key})
    extends StatelessWidget {
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
