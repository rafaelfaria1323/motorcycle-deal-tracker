import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../listings/presentation/offer_text.dart';
import '../../domain/entities/favourite.dart';
import '../cubit/favourites_cubit.dart';

/// A favourite's target price, set from "Quanto oferecer": the listing
/// alerts its owner once it costs that or less. A tap sets or changes it,
/// starting from [suggested] (the opening offer).
class const TargetPriceTile({
  required final Favourite favourite,
  required final double suggested,
  super.key,
}) extends StatelessWidget {
  Future<void> _edit(BuildContext context) async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_TargetResult>(
      context: context,
      builder: (_) => _TargetDialog(
        initial: favourite.targetPrice ?? suggested,
        canClear: favourite.targetPrice != null,
      ),
    );
    if (result == null) return;
    final saved = await getIt<FavouritesCubit>().saveTargetPrice(
      favourite.listingId,
      result.price,
    );
    if (!saved) showMessage(messenger, messageStrings.couldNotSavePrice);
  }

  @override
  Widget build(BuildContext context) {
    final target = favourite.targetPrice;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.flag_outlined),
      title: Text(
        target == null
            ? context.strings.yourTargetPrice
            : context.strings.yourTargetPriceIs(
                price: Formatters.price(target, language: context.language),
              ),
      ),
      subtitle: Text(
        target == null
            ? context.strings.weWillAlertYouWhenPriceDropsTo
            : context.strings.weWillAlertYouWhenListingCostsThis,
      ),
      trailing: TextButton(
        onPressed: () => _edit(context),
        child: Text(
          target == null
              ? context.strings.setTargetPrice
              : context.strings.change,
        ),
      ),
    );
  }
}

/// The dialog's answer: a price, or null to clear it.
class const _TargetResult(final double? price);

class const _TargetDialog({
  required final double initial,
  required final bool canClear,
}) extends StatefulWidget {
  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final _controller = TextEditingController(
    text: widget.initial.round().toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = parseCounterOffer(
      _controller.text,
      language: context.language,
    );
    return AlertDialog(
      title: Text(context.strings.yourTargetPrice),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: context.strings.notifyMeWhenItCostsUpTo,
          suffixText: '€',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _TargetResult(null)),
            child: Text(context.strings.removeTargetPrice),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          onPressed: price == null
              ? null
              : () => Navigator.of(context).pop(_TargetResult(price)),
          child: Text(context.strings.save),
        ),
      ],
    );
  }
}
