import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/entities/ownership_settings.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../../domain/repositories/ownership_settings_repository.dart';
import '../ownership_cost.dart';
import '../../../../core/localization/localizations.dart';

/// "Custo de ter esta mota": the yearly cost (depreciation, IUC, the
/// owner's insurance, tyres, services, chain) and the total for the years
/// the owner plans to keep it. "Alterar" edits the owner's figures.
class OwnershipCostCard extends StatefulWidget {
  const OwnershipCostCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<OwnershipCostCard> createState() => _OwnershipCostCardState();
}

class _OwnershipCostCardState extends State<OwnershipCostCard> {
  late final Future<(OwnershipSettings, Depreciation?)> _loaded = _load();
  OwnershipSettings? _edited;

  Future<(OwnershipSettings, Depreciation?)> _load() async {
    final id = widget.listing.motorcycleId;
    // Either can fail on its own: the defaults and the general rates still
    // give an estimate.
    final (settings, market) = await (
      getIt<OwnershipSettingsRepository>().get().catchError(
        (Object _) => const OwnershipSettings(),
      ),
      id == null
          ? Future<MarketBehaviour?>.value()
          : getIt<MarketBehaviourRepository>()
                .getForModel(id)
                .catchError((Object _) => null),
    ).wait;
    return (settings, market?.depreciation);
  }

  Future<void> _edit(OwnershipSettings current) async {
    final messageStrings = context.strings;

    final result = await showDialog<OwnershipSettings>(
      context: context,
      builder: (_) => _SettingsDialog(initial: current),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Shown at once; kept on this page even if saving fails.
    setState(() => _edited = result);
    try {
      await getIt<OwnershipSettingsRepository>().save(result);
    } catch (_) {
      showMessage(messenger, messageStrings.couldNotSaveTryAgain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing.price == null || listing.isRemoved) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<(OwnershipSettings, Depreciation?)>(
      future: _loaded,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final settings = _edited ?? data.$1;
        final cost = ownershipCost(
          price: listing.price,
          settings: settings,
          engineCc: listing.engineCc,
          year: listing.year,
          depreciation: data.$2,
        );
        if (cost == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return SectionCard(
          title: context.strings.costOfOwningThisBike,
          action: TextButton(
            onPressed: () => _edit(settings),
            child: Text(context.strings.change),
          ),
          footnote: ownershipFootnote(cost, language: context.language),
          children: [
            Text(
              ownershipHeadline(cost, language: context.language),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(ownershipTotalLine(cost, language: context.language)),
            const SizedBox(height: 8),
            for (final line in ownershipLines(
              cost,
              year: listing.year,
              language: context.language,
            ))
              BulletLine(line),
          ],
        );
      },
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.initial});

  final OwnershipSettings initial;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final _insurance = TextEditingController(
    text: widget.initial.insurancePerYear?.toString() ?? '',
  );
  late final _km = TextEditingController(
    text: widget.initial.kmPerYear.toString(),
  );
  late final _years = TextEditingController(
    text: widget.initial.yearsToKeep.toString(),
  );
  bool _invalid = false;

  @override
  void dispose() {
    _insurance.dispose();
    _km.dispose();
    _years.dispose();
    super.dispose();
  }

  void _save() {
    final settings = parseOwnershipSettings(
      insurance: _insurance.text,
      kmPerYear: _km.text,
      yearsToKeep: _years.text,
    );
    if (settings == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(settings);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
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
    return AlertDialog(
      title: Text(context.strings.yourFigures),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                _insurance,
                context.strings.insurancePerYear,
                suffix: '€',
                helper: context.strings.yourEstimateLeaveBlankIfNotYetKnown,
              ),
              _field(_km, context.strings.kilometresPerYear, suffix: 'km'),
              _field(_years, context.strings.yearsYouPlanToKeepIt),
              if (_invalid)
                Text(
                  context.strings.useWholeNumbersInsuranceUpToEUR20,
                  style: AppTheme.errorText(context),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(context.strings.save)),
      ],
    );
  }
}
