import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Motorcycle Deal Tracker',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.two_wheeler_rounded,
              color: scheme.onPrimary,
              size: 25,
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
