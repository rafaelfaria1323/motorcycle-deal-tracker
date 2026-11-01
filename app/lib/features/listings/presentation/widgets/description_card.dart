import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';

/// The seller's text, folded after a few lines: it is often long.
class const DescriptionCard({required final String description, super.key})
    extends StatefulWidget {
  @override
  State<DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  static const _foldedLines = 8;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return SectionCard(
      title: context.strings.description,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(text: widget.description, style: style),
              maxLines: _foldedLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            final foldable = painter.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
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
