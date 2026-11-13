import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/confirm_delete.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../market/domain/repositories/market_behaviour_repository.dart';
import '../../domain/entities/bike_value.dart';
import '../../domain/entities/owned_bike.dart';
import '../../domain/entities/ownership_settings.dart';
import '../../domain/repositories/ownership_settings_repository.dart';
import '../cubit/owned_bikes_cubit.dart';
import '../owned_bike_text.dart';
import '../ownership_cost.dart';
import '../widgets/owned_bike_form.dart';

/// "A minha mota" (Mais, or "Comprei esta" on an ad; N.67): the account's
/// own bikes, each with its value today against what was paid and the
/// next service and valve check by the estimated odometer.
class const MyBikesPage({super.key}) extends StatefulWidget {
  @override
  State<MyBikesPage> createState() => _MyBikesPageState();
}

class _MyBikesPageState extends State<MyBikesPage> {
  final _cubit = getIt<OwnedBikesCubit>();
  final _signedIn = getIt<SessionCubit>().state.signedIn;

  // The owner's km a year (Mais' cost of ownership figures), shared by
  // every bike; the defaults when they can't be read.
  late final Future<OwnershipSettings> _settings =
      getIt<OwnershipSettingsRepository>().get().catchError(
        (Object _) => const OwnershipSettings(),
      );

  @override
  void initState() {
    super.initState();
    if (_signedIn) unawaited(_cubit.load());
  }

  Future<void> _add() async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final models = await getIt<MarketBehaviourRepository>()
        .getTrackedModels()
        .catchError((Object _) => const <Never>[]);
    if (!mounted) return;
    if (models.isEmpty) {
      showMessage(messenger, strings.myBikeNoModels);
      return;
    }
    final bike = await showOwnedBikeForm(
      context,
      initial: null,
      models: [for (final m in models) (id: m.motorcycleId, name: m.name)],
    );
    if (bike == null) return;
    if (!await _cubit.add(bike)) {
      showMessage(messenger, strings.couldNotSaveTryAgain);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(),
      title: Text(context.strings.myBike),
    ),
    floatingActionButton: _signedIn
        ? FloatingActionButton.extended(
            onPressed: () => unawaited(_add()),
            icon: const Icon(Icons.add),
            label: Text(context.strings.myBikeAdd),
          )
        : null,
    body: !_signedIn
        ? StateMessage(
            icon: Icons.lock_outline,
            title: context.strings.availableWhenSignedIn,
            message: context.strings.myBikeSubtitle,
          )
        : BlocBuilder<OwnedBikesCubit, OwnedBikesState>(
            bloc: _cubit,
            builder: (context, state) => switch (state.status) {
              .failure => StateMessage(
                icon: Icons.cloud_off,
                title: context.strings.myBikeCouldNotLoad,
                actionLabel: context.strings.retry,
                onAction: () => unawaited(_cubit.load()),
              ),
              .initial || .loading when state.bikes.isEmpty => const Center(
                child: CircularProgressIndicator(),
              ),
              _ => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  PageIntro(
                    eyebrow: context.strings.personal,
                    title: context.strings.myBike,
                    description: context.strings.myBikeIntro,
                  ),
                  const SizedBox(height: 16),
                  // Not a StateMessage: it scrolls itself, and can't sit
                  // in this list.
                  if (state.bikes.isEmpty)
                    SectionCard(
                      title: context.strings.myBikeNone,
                      children: [Text(context.strings.myBikeNoneHint)],
                    ),
                  for (final bike in state.bikes)
                    _OwnedBikeCard(
                      key: ValueKey(bike.id),
                      bike: bike,
                      settings: _settings,
                    ),
                ],
              ),
            },
          ),
  );
}

class const _OwnedBikeCard({
  required final OwnedBike bike,
  required final Future<OwnershipSettings> settings,
  super.key,
}) extends StatefulWidget {
  @override
  State<_OwnedBikeCard> createState() => _OwnedBikeCardState();
}

class _OwnedBikeCardState extends State<_OwnedBikeCard> {
  late Future<(int?, BikeValue?)> _now = _load();

  @override
  void didUpdateWidget(_OwnedBikeCard old) {
    super.didUpdateWidget(old);
    if (old.bike != widget.bike) _now = _load();
  }

  /// The odometer today, then the value at it (null when it can't be read).
  Future<(int?, BikeValue?)> _load() async {
    final purchase = widget.bike.purchase;
    final settings = await widget.settings;
    final km = mileageNow(
      purchase,
      kmPerYear: settings.kmPerYear,
      today: DateTime.now(),
    );
    final value = await getIt<MarketBehaviourRepository>()
        .getBikeValue(purchase.motorcycleId, year: purchase.year, mileage: km)
        .then<BikeValue?>((v) => v, onError: (Object _) => null);
    return (km, value);
  }

  Future<void> _edit() async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final bike = widget.bike;
    final edited = await showOwnedBikeForm(
      context,
      initial: bike.purchase,
      model: (id: bike.purchase.motorcycleId, name: bike.name),
      listingId: bike.purchase.listingId,
    );
    if (edited == null) return;
    if (!await getIt<OwnedBikesCubit>().edit(bike.id, edited)) {
      showMessage(messenger, strings.couldNotSaveTryAgain);
    }
  }

  Future<void> _delete() async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDelete(
      context,
      title: strings.myBikeDeleteTitle,
      message: strings.myBikeDeleteMessage(name: widget.bike.name),
    );
    if (!confirmed) return;
    if (!await getIt<OwnedBikesCubit>().remove(widget.bike.id)) {
      showMessage(messenger, strings.couldNotDeleteTryAgain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bike = widget.bike;
    final language = context.language;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: '${bike.name} ${bike.purchase.year}',
        action: PopupMenuButton<bool>(
          tooltip: context.strings.options,
          onSelected: (edit) => unawaited(edit ? _edit() : _delete()),
          itemBuilder: (context) => [
            PopupMenuItem(value: true, child: Text(context.strings.edit)),
            PopupMenuItem(value: false, child: Text(context.strings.delete)),
          ],
        ),
        footnote: context.strings.myBikeFootnote,
        children: [
          Text(purchaseText(bike.purchase, language: language), style: muted),
          const SizedBox(height: 12),
          FutureBuilder<(int?, BikeValue?)>(
            future: _now,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) {
                return const LinearProgressIndicator();
              }
              final (km, value) = data;
              final change = value == null
                  ? null
                  : valueChange(value, bike.purchase.pricePaid);
              final costs = runningCostsFor(
                bike.engineCc,
                sport: isSportBike(brand: bike.brand, model: bike.model),
                maintenance: bike.maintenance,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (km != null)
                    Text(
                      context.strings.myBikeMileageNow(
                        mileage: Formatters.mileage(km, language: language),
                      ),
                    ),
                  if (value != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      valueTodayText(value, language: language),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ],
                  if (change != null)
                    Text(valueChangeText(change, language: language)),
                  if (bike.values.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.strings.myBikeValueByMonth,
                      style: AppTheme.groupLabel(context),
                    ),
                    for (final line in monthlyValueLines(
                      bike.values,
                      language: language,
                    ))
                      Text(line, style: muted),
                  ],
                  if (km != null) ...[
                    const SizedBox(height: 8),
                    for (final due in nextMaintenance(km, costs))
                      Text(maintenanceText(due, language: language)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
