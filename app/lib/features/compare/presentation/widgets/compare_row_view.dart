import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../compare_text.dart';

/// One row of a side-by-side comparison: its label, then one value per
/// column, the best ones in the positive colour with a tick. Shared by the
/// comparison of listings and the comparison of two models (N.81).
class const CompareRowView(final CompareRow row, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, value) in row.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: row.best.contains(i)
                            ? theme.textTheme.bodyMedium?.copyWith(
                                color: colors.positive,
                                fontWeight: FontWeight.w700,
                              )
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (row.best.contains(i))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.check_circle,
                          size: 14,
                          color: colors.positive,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
