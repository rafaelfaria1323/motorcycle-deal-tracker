import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../negotiation_text.dart';
import '../offer_text.dart';

/// "O vendedor pediu": the seller's counter-offer, typed into [controller]
/// (kept by the card, so it survives the card's rebuilds), and what to
/// answer, with the message to send.
class const CounterOfferReply({
  required final OfferSuggestion offer,
  required final TextEditingController controller,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, typed, _) {
        final counter = parseCounterOffer(
          typed.text,
          language: context.language,
        );
        final reply = counter == null
            ? null
            : offer.reply(counter, language: context.language);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.strings.sellerAskedFor,
                suffixText: '€',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (reply != null) ...[
              const SizedBox(height: 8),
              Text(
                reply.advice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              _MessageBox(
                text: reply.message,
                onCopy: () => copyMessage(context, reply.message),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => copyMessage(
                    context,
                    walkAwayMessage(language: context.language),
                  ),
                  child: Text(context.strings.copyMessageToWalkAway),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The message to send, with a button to copy it.
class const _MessageBox({
  required final String text,
  required final VoidCallback onCopy,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(text)),
          IconButton(
            tooltip: context.strings.copyMessage,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
