import 'package:flutter/material.dart';

/// A titled part of a sheet or a form that opens on a tap, so long lists
/// of choices (chips, switches) stay out of the way until asked for. The
/// [summary] says what is chosen inside while it is closed; [active]
/// shows it in the accent colour, so a closed section with a choice
/// stands out.
class CollapsibleSection extends StatelessWidget {
  const CollapsibleSection({
    required this.title,
    required this.summary,
    required this.children,
    this.active = false,
    this.initiallyExpanded = false,
    this.leading,
    this.tilePadding = EdgeInsets.zero,
    this.childrenPadding = const EdgeInsets.only(bottom: 12),
    super.key,
  });

  final String title;
  final String summary;
  final List<Widget> children;
  final bool active;
  final bool initiallyExpanded;
  final Widget? leading;

  /// Zero in a sheet, whose content has its own margins; a card's rows
  /// line up with its other tiles.
  final EdgeInsetsGeometry tilePadding;
  final EdgeInsetsGeometry childrenPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: leading,
      tilePadding: tilePadding,
      childrenPadding: childrenPadding,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      expandedAlignment: Alignment.centerLeft,
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: initiallyExpanded,
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: children,
    );
  }
}
