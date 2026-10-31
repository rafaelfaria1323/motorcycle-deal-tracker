import 'package:flutter/material.dart';

/// The one card layout of the detail page: a title (with an optional action
/// on the right), the content, and an optional muted footnote. Every card
/// uses it so they all line up.
class const SectionCard({
  required final String title,
  required final List<Widget> children,
  final Widget? action,
  final String? footnote,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footnote = this.footnote;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...children,
            if (footnote != null) ...[
              const SizedBox(height: 12),
              Text(
                footnote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of a list inside a [SectionCard]: a small muted icon (a dot by
/// default) and the text.
class const BulletLine(final String text, {final IconData? icon, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = this.icon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 20,
            child: icon == null
                ? Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : Icon(icon, size: 18, color: muted),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
