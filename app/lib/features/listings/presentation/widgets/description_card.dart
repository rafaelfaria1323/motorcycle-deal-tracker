import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';

/// The seller's text, folded after a few lines: it is often long. Above
/// it the ad's own title or version ([title], labelled [titleLabel]), which
/// the rules read with the description (N.122: an A2 version or an extra
/// named only there).
class const DescriptionCard({
  final String? description,
  final String? title,
  final String? titleLabel,
  super.key,
}) extends StatefulWidget {
  @override
  State<DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  static const _foldedLines = 8;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final title = widget.title;
    final description = widget.description ?? '';

    return SectionCard(
      title: context.strings.description,
      children: [
        if (title != null && title.isNotEmpty) ...[
          Text(
            widget.titleLabel ?? context.strings.adTitleOnSite,
            style: AppTheme.figureLabel(context),
          ),
          const SizedBox(height: 2),
          Text(title, style: theme.textTheme.titleSmall),
          if (description.isNotEmpty) const SizedBox(height: 12),
        ],
        if (description.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: description, style: style),
                maxLines: _foldedLines,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final foldable = painter.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: style,
                    maxLines: _expanded || !foldable ? null : _foldedLines,
                    overflow: _expanded || !foldable
                        ? null
                        : TextOverflow.ellipsis,
                  ),
                  if (foldable)
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded
                            ? context.strings.showLess
                            : context.strings.showAll,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
