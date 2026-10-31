import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class const AppBrand({final bool compact = false, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Motorcycle Deal Tracker',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The app icon (assets/icon/app_icon.jpeg) cut down to 144 px,
          // enough for 36 px on a 4x screen.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/brand/app_logo.png',
              width: 36,
              height: 36,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(
              'MOTO',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'DEAL\nTRACKER',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: 1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
