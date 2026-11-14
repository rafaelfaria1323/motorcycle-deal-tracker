import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';

/// A light tag on a listing's photo, in capitals, as in the Stitch design:
/// the site ([strong]) and the ad's age, on the cards and the ad's page.
class const PhotoTag(final String text, {final bool strong = false, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.groupLabel(context)?.copyWith(
            color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
