import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/bike_condition.dart';
import '../../domain/entities/bike_value.dart';
import '../../domain/entities/bike_value_request.dart';
import '../../../market/domain/entities/exit_price.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../../market/domain/entities/model_market.dart';
import '../../../listings/domain/repositories/catalog_repository.dart';
import '../../../market/domain/repositories/market_behaviour_repository.dart';
import '../ad_link.dart';
import '../ad_link_model.dart';
import '../bike_value_text.dart';
import '../../../listings/presentation/widgets/add_model_sheet.dart';
import '../widgets/bike_condition_fields.dart';
import '../widgets/bike_value_card.dart';
import '../widgets/bike_value_requests.dart';
import '../widgets/import_cost_card.dart';
import '../../../listings/presentation/widgets/tracked_models_builder.dart';

/// "Quanto vale a minha mota": the market value of a bike, the price to
/// ask for it and a dealer's trade-in. Anonymous sessions value the
/// collected models; accounts value any make and model: one nobody
/// collects yet is asked for, collected at the next collection, and
/// answered with a notification ([requestId] opens that answer).
/// With [importing] ("Comprar no estrangeiro", `/import`) the same value
/// is what a bike seen abroad is weighed against ([ImportCostCard], shown
/// first). With [checkingAd] ("Avaliar um anúncio", `/check-ad`, N.102)
/// the form also takes an ad's link: a stored ad opens at once, else the
/// request collects the model and the run that finds the ad pushes its
/// scores. The link's words choose the model when they name one (N.104).
class const BikeValuePage({
  /// The request to show (`/worth?request=<id>`, from the notification).
  final String? requestId,

  /// Whether the page is "Comprar no estrangeiro".
  final bool importing = false,

  /// Whether the page is "Avaliar um anúncio".
  final bool checkingAd = false,

  /// The link the form opens with (`/check-ad?link=…`: an ad shared to
  /// the Android app from the OLX or Standvirtual app, N.103).
  final String? initialLink,
  super.key,
}) extends StatefulWidget {
  /// The oldest year the form takes (as request_bike_value).
  static const firstYear = 1990;

  @override
  State<BikeValuePage> createState() => _BikeValuePageState();
}

/// What "Calcular" gave: the value, or null while the request waits for a
/// collection ([ad]: an ad check waiting for its ad; [signIn]: an ad not
/// stored, asked by an anonymous session, which can't wait for it).
typedef _Outcome = ({
  bool ad,
  bool signIn,
  String name,
  int year,
  int? mileage,
  BikeValue? value,
  MarketBehaviour? market,
  ExitPrice? exit,
});

/// The dropdown's entry that opens the make and model form.
const _otherModel = '';

class _BikeValuePageState extends State<BikeValuePage> {
  final _repository = getIt<MarketBehaviourRepository>();
  final _signedIn = getIt<SessionCubit>().state.signedIn;
  late Future<List<ModelMarket>> _models = _loadModels();
  List<BikeValueRequest> _requests = const [];
  final _form = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _mileage = TextEditingController();
  final _link = TextEditingController();
  String? _motorcycleId;

  /// What the owner says of the bike; it adjusts the value shown, at once,
  /// and is not part of the request.
  BikeCondition _condition = const BikeCondition();

  /// Bumped to reset the dropdown when the make and model form is closed
  /// without a model.
  int _resets = 0;

  /// Models added through "Outra marca ou modelo…" on this visit.
  final _added = <String, String>{};

  /// The ad link whose model was looked for, so each link is read once.
  String? _guessedLink;

  /// The model the link named (N.104); a model the person chose
  /// themselves is never replaced.
  String? _guessedModel;

  /// What was asked and its value, once "Calcular" was pressed (null when
  /// it opened the ad).
  Future<_Outcome?>? _outcome;
  String? _shownRequest;

  Future<List<ModelMarket>> _loadModels() async {
    final models = await _repository.getTrackedModels();
    return [...models]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    _link.text = widget.initialLink ?? '';
    unawaited(_loadRequests());
    unawaited(_guessModel());
  }

  /// Chooses the model the ad's link names: a collected one, else (an
  /// account) one of the sites' lists, found or added as "Outra marca ou
  /// modelo…" does. Nothing fits, or it fails: the choice stays open.
  Future<void> _guessModel() async {
    if (!widget.checkingAd) return;
    final link = adLinkOf(_link.text);
    if (link == null || link == _guessedLink) return;
    _guessedLink = link;
    bool mayChoose() =>
        mounted &&
        _guessedLink == link &&
        (_motorcycleId == null || _motorcycleId == _guessedModel);
    if (!mayChoose()) return;
    final words = adLinkWords(link);
    try {
      final tracked = modelInWords(
        words,
        await _models,
        brand: (m) => m.brand,
        model: (m) => m.model,
      );
      var guess = tracked == null
          ? null
          : (id: tracked.motorcycleId, name: tracked.name);
      if (guess == null && _signedIn) {
        final catalog = getIt<CatalogRepository>();
        final make = makeInWords(words, await catalog.getSiteMakes());
        final site = make == null
            ? null
            : siteModelInWords(
                words,
                make,
                await catalog.getSiteModels(make.id),
              );
        if (site != null && mayChoose()) {
          final id = await _repository.bikeValueModel(
            brand: site.brand,
            model: site.model,
            olxSearch: site.olxSearch,
            standvirtualSearch: site.standvirtualSearch,
          );
          guess = (id: id, name: '${site.brand} ${site.model}');
        }
      }
      if (guess == null || !mayChoose()) return;
      final (:id, :name) = guess;
      setState(() {
        _added.putIfAbsent(id, () => name);
        _motorcycleId = id;
        _guessedModel = id;
      });
    } catch (_) {
      // The model is chosen by hand, as before.
    }
  }

  /// The account's requests; a failed read leaves the list as it was (it
  /// is only a shortcut to earlier answers).
  Future<void> _loadRequests() async {
    if (!_signedIn) return;
    try {
      final requests = await _repository.getBikeValueRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
      _openRequest(requests);
    } catch (_) {
      // Kept as it was.
    }
  }

  @override
  void didUpdateWidget(BikeValuePage old) {
    super.didUpdateWidget(old);
    if (widget.requestId != old.requestId) unawaited(_loadRequests());
    if (widget.initialLink case final link? when link != old.initialLink) {
      _link.text = link;
      unawaited(_guessModel());
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _mileage.dispose();
    _link.dispose();
    super.dispose();
  }

  int get _lastYear => DateTime.now().year + 1;

  /// The mileage as typed, with thousands separators allowed.
  int? _mileageValue() {
    final digits = _mileage.text.replaceAll(RegExp(r'[\s.]'), '');
    return RegExp(r'^\d+$').hasMatch(digits) ? int.parse(digits) : null;
  }

  /// The models to choose from: the collected ones, those of the account's
  /// requests and those added now, by id.
  Map<String, String> _choices(
    List<ModelMarket> models,
    List<BikeValueRequest> requests,
  ) {
    final choices = {
      for (final m in models) m.motorcycleId: m.name,
      for (final r in requests) r.motorcycleId: r.name,
      ..._added,
    };
    final sorted = choices.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Map.fromEntries(sorted);
  }

  /// Opens the request the notification named, once.
  void _openRequest(List<BikeValueRequest> requests) {
    final id = widget.requestId;
    if (id == null || id == _shownRequest) return;
    for (final request in requests) {
      if (request.id == id) {
        _shownRequest = id;
        _show(request);
      }
    }
  }

  /// Fills the form with [request] and shows its value or that it waits;
  /// an ad check whose ad was found opens the ad.
  void _show(BikeValueRequest request) {
    if (request.adListingId case final listing? when !request.waiting) {
      unawaited(context.push(AppRoutes.listingDetail(listing)));
      return;
    }
    if (request.adUrl case final url?) _link.text = url;
    _year.text = '${request.year}';
    _mileage.text = request.mileage?.toString() ?? '';
    setState(() {
      _added.putIfAbsent(request.motorcycleId, () => request.name);
      _motorcycleId = request.motorcycleId;
      _outcome = _valueOf(
        request.motorcycleId,
        request.name,
        year: request.year,
        mileage: request.mileage,
        waiting: request.waiting,
        ad: request.isAd,
      );
    });
  }

  Future<_Outcome> _valueOf(
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
    bool waiting = false,
    bool ad = false,
    bool signIn = false,
  }) async {
    if (waiting || signIn) {
      return (
        ad: ad,
        signIn: signIn,
        name: name,
        year: year,
        mileage: mileage,
        value: null,
        market: null,
        exit: null,
      );
    }
    final (value, market, exit) = await (
      _repository.getBikeValue(motorcycleId, year: year, mileage: mileage),
      _repository.getForModel(motorcycleId),
      // Extra: without it the value still shows.
      _repository
          .getExitPrice(motorcycleId, year: year, mileage: mileage)
          .then<ExitPrice?>((e) => e, onError: (Object _) => null),
    ).wait;
    return (
      ad: false,
      signIn: false,
      name: name,
      year: year,
      mileage: mileage,
      value: value,
      market: market,
      exit: exit,
    );
  }

  Future<_Outcome> _ask(
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
  }) async {
    if (!_signedIn) {
      return await _valueOf(motorcycleId, name, year: year, mileage: mileage);
    }
    final asked = await _repository.requestBikeValue(
      motorcycleId,
      year: year,
      mileage: mileage,
    );
    await _loadRequests();
    return await _valueOf(
      motorcycleId,
      name,
      year: year,
      mileage: mileage,
      waiting: !asked.ready,
    );
  }

  /// "Avaliar": the stored ad opens at once (null outcome); else the
  /// request waits for the collection (an anonymous session is asked to
  /// sign in: it can't be told when the ad is found).
  Future<_Outcome?> _checkAd(
    String url,
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
  }) async {
    String? listing;
    var waiting = true;
    if (_signedIn) {
      final asked = await _repository.requestAdCheck(
        url,
        motorcycleId: motorcycleId,
        year: year,
        mileage: mileage,
      );
      listing = asked.listingId;
      await _loadRequests();
    } else {
      listing = await _repository.listingForAd(url);
      waiting = false;
    }
    if (listing != null) {
      if (mounted) unawaited(context.push(AppRoutes.listingDetail(listing)));
      return null;
    }
    return await _valueOf(
      motorcycleId,
      name,
      year: year,
      mileage: mileage,
      waiting: waiting,
      ad: true,
      signIn: !waiting,
    );
  }

  void _calculate(Map<String, String> choices) {
    if (!_form.currentState!.validate()) return;
    final id = _motorcycleId!;
    final year = int.parse(_year.text.trim());
    final mileage = _mileage.text.trim().isEmpty ? null : _mileageValue();
    if (widget.checkingAd) {
      final url = adLinkOf(_link.text)!;
      setState(() {
        _added.putIfAbsent(id, () => choices[id]!);
        _outcome = _checkAd(
          url,
          id,
          choices[id]!,
          year: year,
          mileage: mileage,
        );
      });
      return;
    }
    setState(() {
      _added.putIfAbsent(id, () => choices[id]!);
      _outcome = _ask(id, choices[id]!, year: year, mileage: mileage);
    });
  }

  /// "Outra marca ou modelo…": the make and model form, then the catalog
  /// model for it (added when new, not followed).
  Future<void> _pickOther() async {
    final picked = await showAddModelSheet(
      context,
      getIt<CatalogRepository>(),
      forValue: true,
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _resets++);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.bikeValueCouldNotUseModel;
    try {
      final id = await _repository.bikeValueModel(
        brand: picked.brand,
        model: picked.model,
        olxSearch: picked.olxSearch,
        standvirtualSearch: picked.standvirtualSearch,
        engineCcMin: picked.engineCcMin,
        engineCcMax: picked.engineCcMax,
      );
      if (!mounted) return;
      setState(() {
        _added[id] = '${picked.brand} ${picked.model}';
        _motorcycleId = id;
      });
    } catch (_) {
      if (mounted) setState(() => _resets++);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The title is the page's heading (PageIntro), as on the tabs.
      appBar: AppBar(leading: const PageBackButton()),
      body: TrackedModelsBuilder(
        future: _models,
        allowEmpty: _signedIn,
        onRetry: () => setState(() => _models = _loadModels()),
        builder: (context, models) {
          final choices = _choices(models, _requests);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              PageIntro(
                eyebrow: context.strings.bikeValueTools,
                title: widget.checkingAd
                    ? context.strings.checkAdTitle
                    : widget.importing
                    ? context.strings.importPageTitle
                    : context.strings.bikeValueTitle,
                description: switch ((widget.importing, _signedIn)) {
                  _ when widget.checkingAd => context.strings.checkAdIntro,
                  (true, _) => context.strings.importPageIntro,
                  (false, true) => context.strings.bikeValueIntroAnyModel,
                  (false, false) => context.strings.bikeValueIntro,
                },
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _formFields(context, choices),
                ),
              ),
              const SizedBox(height: 16),
              if (_outcome != null) _result(context, choices),
              if (_requests.isNotEmpty)
                BikeValueRequests(requests: _requests, onTap: _show),
            ],
          );
        },
      ),
    );
  }

  Widget _formFields(BuildContext context, Map<String, String> choices) {
    final strings = context.strings;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.checkingAd) ...[
            TextFormField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: strings.checkAdLink,
                hintText: strings.checkAdLinkHint,
                border: const OutlineInputBorder(),
              ),
              validator: (text) => adLinkOf(text ?? '') == null
                  ? strings.checkAdLinkInvalid
                  : null,
              onChanged: (_) => unawaited(_guessModel()),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            // Rebuilt when a model is picked from outside the dropdown.
            key: ValueKey((_motorcycleId, _resets)),
            initialValue: _motorcycleId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.model,
              helperText:
                  _motorcycleId != null && _motorcycleId == _guessedModel
                  ? strings.checkAdModelFromLink
                  : null,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final MapEntry(:key, :value) in choices.entries)
                DropdownMenuItem(value: key, child: Text(value)),
              if (_signedIn)
                DropdownMenuItem(
                  value: _otherModel,
                  child: Text(strings.bikeValueOtherModel),
                ),
            ],
            validator: (value) => value == null || value == _otherModel
                ? strings.chooseModel
                : null,
            onChanged: (value) {
              if (value == _otherModel) {
                unawaited(_pickOther());
              } else {
                setState(() => _motorcycleId = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.yearLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (text) {
              final year = int.tryParse(text?.trim() ?? '');
              return year == null ||
                      year < BikeValuePage.firstYear ||
                      year > _lastYear
                  ? strings.bikeValueYearInvalid(
                      first: BikeValuePage.firstYear,
                      last: _lastYear,
                    )
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mileage,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.bikeValueMileage,
              border: const OutlineInputBorder(),
            ),
            validator: (text) =>
                (text?.trim() ?? '').isEmpty || _mileageValue() != null
                ? null
                : strings.bikeValueMileageInvalid,
          ),
          const SizedBox(height: 20),
          BikeConditionFields(
            condition: _condition,
            onChanged: (condition) => setState(() => _condition = condition),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _calculate(choices),
            icon: Icon(
              widget.checkingAd
                  ? Icons.manage_search
                  : Icons.calculate_outlined,
            ),
            label: Text(
              widget.checkingAd
                  ? strings.checkAdButton
                  : strings.bikeValueCalculate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context, Map<String, String> choices) {
    return FutureBuilder<_Outcome?>(
      future: _outcome,
      builder: (context, snapshot) {
        final strings = context.strings;
        if (snapshot.error is BikeValueRequestLimit) {
          return StateMessage(
            icon: Icons.hourglass_top,
            title: strings.bikeValueRequestLimit,
          );
        }
        if (snapshot.hasError) {
          return StateMessage(
            icon: Icons.cloud_off_outlined,
            title: strings.bikeValueCouldNotCalculate,
            actionLabel: strings.retry,
            onAction: () => _calculate(choices),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // The ad opened: nothing to show under the form.
        final outcome = snapshot.data;
        if (outcome == null) return const SizedBox.shrink();
        if (outcome.signIn) {
          return StateMessage(icon: Icons.login, title: strings.checkAdSignIn);
        }
        if (outcome.ad && outcome.value == null) {
          return StateMessage(
            icon: Icons.hourglass_top,
            title: strings.checkAdWaitingTitle,
            message: strings.checkAdWaitingBody,
          );
        }
        final value = outcome.value;
        final card = BikeValueCard(
          name: outcome.name,
          year: outcome.year,
          value: value,
          market: outcome.market,
          condition: _condition,
          exit: outcome.exit,
        );
        if (value == null || !widget.importing) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImportCostCard(
              estimate: conditionEstimate(value, _condition),
              year: outcome.year,
              mileage: outcome.mileage,
            ),
            const SizedBox(height: 16),
            card,
          ],
        );
      },
    );
  }
}
