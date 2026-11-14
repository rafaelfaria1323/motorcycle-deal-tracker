import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/owned_bike.dart';
import '../owned_bike_text.dart';

/// A model the purchase form can name: an ad's, a kept bike's, or one to
/// choose from the collected models.
typedef OwnedBikeModel = ({String id, String name});

/// The purchase form (N.67): the price paid, the km and the date, and the
/// year; the model is fixed ([model]) or chosen ([models]). Gives the bike
/// as typed, or null when cancelled.
Future<OwnedBikeDraft?> showOwnedBikeForm(
  BuildContext context, {
  required OwnedBikeDraft? initial,
  OwnedBikeModel? model,
  List<OwnedBikeModel> models = const [],
  String? listingId,
}) => showDialog<OwnedBikeDraft>(
  context: context,
  builder: (_) => _OwnedBikeForm(
    initial: initial,
    model: model,
    models: models,
    listingId: listingId,
  ),
);

class const _OwnedBikeForm({
  required final OwnedBikeDraft? initial,
  required final OwnedBikeModel? model,
  required final List<OwnedBikeModel> models,
  required final String? listingId,
}) extends StatefulWidget {
  @override
  State<_OwnedBikeForm> createState() => _OwnedBikeFormState();
}

class _OwnedBikeFormState extends State<_OwnedBikeForm> {
  late String? _motorcycleId = widget.model?.id ?? widget.initial?.motorcycleId;
  late final _year = TextEditingController(
    text: widget.initial?.year.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: widget.initial?.pricePaid?.toString() ?? '',
  );
  late final _mileage = TextEditingController(
    text: widget.initial?.mileageAtPurchase?.toString() ?? '',
  );
  late DateTime _boughtOn = widget.initial?.boughtOn ?? _today;
  bool _invalid = false;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _year.dispose();
    _price.dispose();
    _mileage.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _boughtOn,
      firstDate: DateTime(1990),
      lastDate: _today,
      helpText: context.strings.myBikeBoughtOnLabel,
    );
    if (day != null && mounted) setState(() => _boughtOn = day);
  }

  void _save() {
    final id = _motorcycleId;
    final bike = id == null
        ? null
        : parseOwnedBike(
            motorcycleId: id,
            listingId: widget.listingId ?? widget.initial?.listingId,
            year: _year.text,
            price: _price.text,
            mileage: _mileage.text,
            boughtOn: _boughtOn,
          );
    if (bike == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(bike);
  }

  Widget _number(
    TextEditingController controller,
    String label, {
    String? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fixed = widget.model;
    return AlertDialog(
      title: Text(fixed?.name ?? strings.myBikeAddTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fixed == null && widget.models.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _motorcycleId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.myBikeModelLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in widget.models)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (id) => setState(() => _motorcycleId = id),
                  ),
                ),
              _number(_year, strings.myBikeYearLabel),
              _number(_price, strings.myBikePricePaidLabel, suffix: '€'),
              _number(_mileage, strings.myBikeMileageLabel, suffix: 'km'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(strings.myBikeBoughtOnLabel),
                subtitle: Text(Formatters.date(_boughtOn)),
                onTap: _pickDate,
              ),
              if (_invalid)
                Text(
                  strings.myBikeFormInvalid,
                  style: AppTheme.errorText(context),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(strings.save)),
      ],
    );
  }
}
