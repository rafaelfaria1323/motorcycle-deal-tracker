import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';

/// The Alertas tab's two parts above its page: the alerts, and the saved
/// searches that make them (F.9). Each part is its own address in the
/// same tab (`/alerts`, `/searches`), so links and the browser's history
/// keep working; [child] is the part's own content. Labels only: the tab
/// already shows the bell, and with large text on a phone the icons left
/// the words too little room.
class const AlertsSegments({
  required final bool searches,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(context.strings.alerts),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(context.strings.searches),
                  ),
                ],
                selected: {searches},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => context.go(
                  selection.single ? AppRoutes.searches : AppRoutes.alerts,
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
