import 'package:flutter/material.dart';

class PageIntro extends StatelessWidget {
  const PageIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              child: Divider(color: scheme.primary, thickness: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 36,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
