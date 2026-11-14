import 'package:material_ui/material_ui.dart';

/// A settings row's icon in a rounded tinted square, after the Stitch
/// design of Mais (UI.6); [strong] fills it with the primary colour for
/// the row that matters most. Otherwise the icon keeps the row's colour
/// (a tinted row's icon follows its text).
class const SettingsIcon(
  final IconData icon, {
  final bool strong = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 22, color: strong ? scheme.onPrimary : null),
      ),
    );
  }
}
