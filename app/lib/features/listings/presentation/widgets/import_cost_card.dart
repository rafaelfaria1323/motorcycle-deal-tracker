import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../import_cost.dart';
import '../import_cost_text.dart';

/// "E se a comprar no estrangeiro?": the same bike seen in Spain, France
/// or Germany, its price there and engine size, gives its cost on the road
/// here against [estimate]: the value of the bike here (null with too few
/// listings) or, [against] a listing, its asking price. Worked out as the
/// person types; nothing is saved.
class const ImportCostCard({
  required final double? estimate,
  required final int? year,
  required final int? mileage,
  final ImportComparison against = ImportComparison.value,

  /// The model's engine size, filled in for the person (it can be changed).
  final int? engineCc,
  super.key,
}) extends StatefulWidget {
  @override
  State<ImportCostCard> createState() => _ImportCostCardState();
}

class _ImportCostCardState extends State<ImportCostCard> {
  final _price = TextEditingController();
  late final _engineCc = TextEditingController(
    text: widget.engineCc?.toString() ?? '',
  );
  final _transport = TextEditingController();
  ImportCountry _country = ImportCountry.spain;

  @override
  void dispose() {
    _price.dispose();
    _engineCc.dispose();
    _transport.dispose();
    super.dispose();
  }

  /// The cost once the price and the engine size are typed; null before.
  ImportCost? _cost() {
    final price = parseWholeAmount(_price.text);
    final engineCc = parseWholeAmount(_engineCc.text);
    if (price == null || price == 0 || engineCc == null || engineCc == 0) {
      return null;
    }
    return importCost(
      price: price.toDouble(),
      engineCc: engineCc,
      country: _country,
      transport: parseWholeAmount(_transport.text)?.toDouble(),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String suffix,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final cost = _cost();
    return SectionCard(
      title: strings.importCostTitle,
      footnote: importCostNote(language: context.language),
      children: [
        Text(switch (widget.against) {
          ImportComparison.value => strings.importCostIntro,
          ImportComparison.listing => strings.importCostIntroAd,
        }),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<ImportCountry>(
            initialValue: _country,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.importCostCountry,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final country in ImportCountry.values)
                DropdownMenuItem(
                  value: country,
                  child: Text(switch (country) {
                    ImportCountry.spain => strings.importCountrySpain,
                    ImportCountry.france => strings.importCountryFrance,
                    ImportCountry.germany => strings.importCountryGermany,
                  }),
                ),
            ],
            onChanged: (country) {
              if (country != null) setState(() => _country = country);
            },
          ),
        ),
        _field(_price, strings.importCostPrice, suffix: '€'),
        _field(_engineCc, strings.importCostEngineCc, suffix: 'cc'),
        _field(
          _transport,
          strings.importCostTransport,
          suffix: '€',
          helper: strings.importCostTransportHint(
            amount: _country.transport.round().toString(),
          ),
        ),
        if (cost != null)
          for (final line in importCostLines(
            cost,
            estimate: widget.estimate,
            year: widget.year,
            mileage: widget.mileage,
            now: DateTime.now(),
            against: widget.against,
            language: context.language,
          ))
            BulletLine(line.text, icon: _icons[line.kind]),
      ],
    );
  }
}

const _icons = {
  ImportLineKind.cost: Icons.local_shipping_outlined,
  ImportLineKind.comparison: Icons.compare_arrows,
  ImportLineKind.vat: Icons.warning_amber_outlined,
};
