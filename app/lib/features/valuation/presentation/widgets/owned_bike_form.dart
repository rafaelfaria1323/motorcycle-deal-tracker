import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../domain/entities/owned_bike.dart';
import '../owned_bike_text.dart';

/// A model the purchase form can name: an ad's, a kept bike's, or one to
/// choose from the followed models or any other.
typedef OwnedBikeModel = ({String id, String name});

/// The purchase form (N.67): the price paid, the km and the date, and the
/// year; the model is fixed ([model]) or chosen ([models], and with
/// [pickOther] "Outra marca ou modelo…": any brand and model, N.120).
/// Gives the bike as typed, or null when cancelled.
Future<OwnedBikeDraft?> showOwnedBikeForm(
  BuildContext context, {
  required OwnedBikeDraft? initial,
  OwnedBikeModel? model,
  List<OwnedBikeModel> models = const [],
  Future<OwnedBikeModel?> Function()? pickOther,
  String? listingId,
}) => showDialog<OwnedBikeDraft>(
  context: context,
  builder: (_) => _OwnedBikeForm(
    initial: initial,
    model: model,
    models: models,
    pickOther: pickOther,
    listingId: listingId,
  ),
);

/// The dropdown's "Outra marca ou modelo…" item.
const _otherModel = '';

class const _OwnedBikeForm({
  required final OwnedBikeDraft? initial,
  required final OwnedBikeModel? model,
  required final List<OwnedBikeModel> models,
  required final Future<OwnedBikeModel?> Function()? pickOther,
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

  /// Models picked with "Outra marca ou modelo…", added to the dropdown.
  final _added = <OwnedBikeModel>[];

  /// Rebuilds the dropdown when a pick is cancelled (back to the choice
  /// before) or made outside it.
  int _resets = 0;

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

  Future<void> _pickOther() async {
    final picked = await widget.pickOther!();
    if (!mounted) return;
    setState(() {
      if (picked != null) {
        if (!widget.models.any((m) => m.id == picked.id) &&
            !_added.any((m) => m.id == picked.id)) {
          _added.add(picked);
        }
        _motorcycleId = picked.id;
      }
      _resets++;
    });
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
              if (fixed == null &&
                  (widget.models.isNotEmpty || widget.pickOther != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_resets),
                    initialValue: _motorcycleId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.myBikeModelLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in [...widget.models, ..._added])
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                      if (widget.pickOther != null)
                        DropdownMenuItem(
                          value: _otherModel,
                          child: Text(strings.bikeValueOtherModel),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == _otherModel) {
                        unawaited(_pickOther());
                      } else {
                        setState(() => _motorcycleId = id);
                      }
                    },
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
