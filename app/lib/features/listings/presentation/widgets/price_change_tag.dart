import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import '../../../../core/localization/localizations.dart';

/// "↓ 300 €" in green when the price dropped, "↑ 150 €" in red when it rose.
class PriceChangeTag extends StatelessWidget {
  const PriceChangeTag({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final change = listing.priceChange;
    if (!listing.hasPriceChanged || change == null) {
      return const SizedBox.shrink();
    }
    final dropped = change < 0;
    final colors = AppColors.of(context);
    final color = dropped ? colors.positive : colors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${dropped ? '↓' : '↑'} ${Formatters.price(change.abs(), language: context.language)}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
