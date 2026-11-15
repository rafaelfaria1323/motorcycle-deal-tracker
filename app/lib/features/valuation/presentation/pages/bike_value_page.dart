import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/bike_condition.dart';
import '../../domain/entities/bike_value.dart';
import '../../domain/entities/bike_value_request.dart';
import '../../domain/entities/shared_ad.dart';
import '../../domain/repositories/shared_ads_repository.dart';
import '../../../market/domain/entities/exit_price.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../../market/domain/entities/model_market.dart';
import '../../../listings/domain/entities/catalog_model.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../../listings/domain/repositories/catalog_repository.dart';
import '../../../market/domain/repositories/market_behaviour_repository.dart';
import '../ad_link.dart';
import '../ad_link_model.dart';
import '../bike_value_text.dart';
import '../comparable_years.dart';
import '../shared_ad_text.dart';
import '../typed_ad.dart';
import '../typed_ad_history.dart';
import '../../../listings/presentation/widgets/add_model_sheet.dart';
import '../../../listings/presentation/new_price_text.dart';
import '../../../listings/presentation/widgets/new_price_card.dart';
import '../../../listings/presentation/widgets/listing_header.dart'
    show ListingScoreTiles;
import '../../../listings/presentation/widgets/offer_card.dart';
import '../../../listings/presentation/widgets/score_explanation_card.dart';
import '../../../listings/presentation/widgets/seller_message_card.dart';
import '../widgets/bike_condition_fields.dart';
import '../widgets/bike_value_card.dart';
import '../widgets/bike_value_requests.dart';
import '../widgets/import_cost_card.dart';
import '../widgets/shared_ads_inbox.dart';
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
/// An ad on another site (Facebook Marketplace, CustoJusto…; N.105) is
/// typed instead: its price and seller with the rest give its value, the
/// cheaper ads we have, the offer plan and the message to the seller.
/// Ads the iPhone shortcut sent (N.110) wait above the form, and "Usar"
/// fills the typed ad with one.
class const BikeValuePage({
  /// The request to show (`/worth?request=<id>`, from the notification).
  final String? requestId,

  /// Whether the page is "Comprar no estrangeiro".
  final bool importing = false,

  /// Whether the page is "Avaliar um anúncio".
  final bool checkingAd = false,

  /// The link the form opens with (`/check-ad?link=…`: an ad shared to
  /// the Android app from the OLX or Standvirtual app, N.103); a link to
  /// another site opens the typed ad (N.110).
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
/// stored, asked by an anonymous session, which can't wait for it;
/// [typed]: the ad typed by hand, N.105, with its model's catalog row
/// [catalog] for the new-bike price; [waiting]: its model is still being
/// collected for that year, so the value comes from the ads stored so far).
typedef _Outcome = ({
  bool ad,
  bool signIn,
  bool waiting,
  _TypedAd? typed,
  String name,
  int year,
  int? mileage,
  ComparableYears years,
  BikeValue? value,
  MarketBehaviour? market,
  ExitPrice? exit,
  CatalogModel? catalog,
});

/// The model, price, seller and pasted text of an ad typed by hand, and
/// how long it has been on sale and its price before a drop (N.109).
typedef _TypedAd = ({
  String motorcycleId,
  double price,
  SellerType seller,
  String? description,
  int? daysListed,
  double? initialPrice,
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
  final _price = TextEditingController();
  final _adText = TextEditingController();
  final _daysListed = TextEditingController();
  final _initialPrice = TextEditingController();
  final _fromYear = TextEditingController();
  final _toYear = TextEditingController();
  String? _motorcycleId;

  /// "O anúncio é de outro site": the ad is typed, not linked (N.105).
  bool _otherSite = false;
  SellerType _seller = SellerType.private;

  /// The typed ad's listing, kept while the outcome and condition stay, so
  /// its cards keep what they loaded.
  (_Outcome, BikeCondition, Listing)? _typedListing;

  /// The typed ad's Deal Score and Risk Score (N.107), asked again only
  /// when the outcome or the condition changes.
  (_Outcome, BikeCondition, Future<TypedAdScore?>)? _typedScore;

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

  /// The ads the iPhone shortcut sent, waiting (N.110).
  List<SharedAd> _sharedAds = const [];

  /// The shared ad the typed form was filled with: its photos are shown
  /// and its title chose the model.
  SharedAd? _usedAd;

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
    _takeLink(widget.initialLink);
    unawaited(_loadRequests());
    unawaited(_loadSharedAds());
    unawaited(_guessModel());
  }

  /// The link the page opened with; one that is not an OLX or Standvirtual
  /// ad (shared from Facebook's app, say) is typed (N.110).
  void _takeLink(String? text) {
    if (text == null) return;
    _link.text = text;
    if (widget.checkingAd &&
        adLinkOf(text) == null &&
        RegExp(r'https?://\S', caseSensitive: false).hasMatch(text)) {
      _otherSite = true;
    }
  }

  /// Chooses the model the ad's link names (N.104).
  Future<void> _guessModel() async {
    if (!widget.checkingAd) return;
    final link = adLinkOf(_link.text);
    if (link == null || link == _guessedLink) return;
    _guessedLink = link;
    await _chooseModelFrom(
      adLinkWords(link),
      stillWanted: () => _guessedLink == link,
    );
  }

  /// Chooses the model [words] name: a collected one, else (an account)
  /// one of the sites' lists, found or added as "Outra marca ou modelo…"
  /// does. Nothing fits, it fails, [stillWanted] turns false or the person
  /// chose a model meanwhile: the choice stays as it is.
  Future<void> _chooseModelFrom(
    List<String> words, {
    required bool Function() stillWanted,
  }) async {
    bool mayChoose() =>
        mounted &&
        stillWanted() &&
        (_motorcycleId == null || _motorcycleId == _guessedModel);
    if (!mayChoose()) return;
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

  /// The ads the shortcut sent; a failed read shows none (the form still
  /// works by hand).
  Future<void> _loadSharedAds() async {
    if (!widget.checkingAd || !_signedIn) return;
    try {
      final ads = await getIt<SharedAdsRepository>().waiting();
      if (mounted) setState(() => _sharedAds = ads);
    } catch (_) {
      // None shown.
    }
  }

  /// "Usar": the typed ad's form filled with what [ad] says; the person
  /// checks it and presses "Avaliar". The ad leaves the inbox.
  void _useSharedAd(SharedAd ad) {
    final facts = sharedAdFacts(ad, now: DateTime.now());
    _price.text = facts.price == null ? '' : '${facts.price!.round()}';
    _year.text = facts.year == null ? '' : '${facts.year}';
    _mileage.text = facts.mileage == null ? '' : '${facts.mileage}';
    _daysListed.text = facts.daysListed == null ? '' : '${facts.daysListed}';
    _initialPrice.text = facts.initialPrice == null
        ? ''
        : '${facts.initialPrice!.round()}';
    _adText.text = facts.description ?? '';
    setState(() {
      _condition = facts.condition;
      _usedAd = ad;
      _otherSite = true;
      _sharedAds = [
        for (final waiting in _sharedAds)
          if (waiting.id != ad.id) waiting,
      ];
      // Another bike: its model is chosen again.
      _motorcycleId = null;
      _guessedModel = null;
      _outcome = null;
    });
    showMessage(ScaffoldMessenger.of(context), context.strings.sharedAdUsed);
    unawaited(_dismissSharedAd(ad, shown: false));
    unawaited(
      _chooseModelFrom(facts.words, stillWanted: () => _usedAd?.id == ad.id),
    );
  }

  /// Takes [ad] out of the inbox; when that fails it comes back with the
  /// next read.
  Future<void> _dismissSharedAd(SharedAd ad, {bool shown = true}) async {
    if (shown) {
      setState(
        () => _sharedAds = [
          for (final waiting in _sharedAds)
            if (waiting.id != ad.id) waiting,
        ],
      );
    }
    try {
      await getIt<SharedAdsRepository>().dismiss(ad.id);
    } catch (_) {
      if (shown) await _loadSharedAds();
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
      setState(() => _takeLink(link));
      unawaited(_guessModel());
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _mileage.dispose();
    _link.dispose();
    _price.dispose();
    _adText.dispose();
    _daysListed.dispose();
    _initialPrice.dispose();
    _fromYear.dispose();
    _toYear.dispose();
    super.dispose();
  }

  int get _lastYear => DateTime.now().year + 1;

  /// The mileage as typed, with thousands separators allowed.
  int? _mileageValue() {
    final digits = _mileage.text.replaceAll(RegExp(r'[\s.]'), '');
    return RegExp(r'^\d+$').hasMatch(digits) ? int.parse(digits) : null;
  }

  /// "Comparar com anúncios de" (N.108): not for a linked ad.
  bool get _comparableYearsShown => !widget.checkingAd || _otherSite;

  /// The years typed there; null when they are not valid.
  ComparableYears? _comparableYears() => parseComparableYears(
    _fromYear.text,
    _toYear.text,
    first: BikeValuePage.firstYear,
    last: _lastYear,
  );

  /// The typed ad's price, at least [minRealPrice].
  double? _priceValue() {
    final price = Formatters.parsePrice(
      _price.text,
      language: context.language,
    );
    return price != null && price >= minRealPrice ? price : null;
  }

  /// The typed ad's time on sale and earlier price; null when invalid.
  TypedAdHistory? _history() => parseTypedAdHistory(
    _daysListed.text,
    _initialPrice.text,
    price: _priceValue(),
    language: context.language,
  );

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
    _TypedAd? typed,
    ComparableYears years = (from: null, to: null),
  }) async {
    // A typed ad is valued and scored at once, from the ads stored so far.
    if ((waiting && typed == null) || signIn) {
      return (
        ad: ad,
        signIn: signIn,
        waiting: waiting,
        typed: typed,
        name: name,
        year: year,
        mileage: mileage,
        years: years,
        value: null,
        market: null,
        exit: null,
        catalog: null,
      );
    }
    final (value, market, exit, catalog) = await (
      _repository.getBikeValue(
        motorcycleId,
        year: year,
        mileage: mileage,
        fromYear: years.from,
        toYear: years.to,
      ),
      _repository.getForModel(motorcycleId),
      // Extra: without it the value still shows.
      _repository
          .getExitPrice(motorcycleId, year: year, mileage: mileage)
          .then<ExitPrice?>((e) => e, onError: (Object _) => null),
      // The typed ad's new-bike price; extra too.
      typed == null
          ? Future<CatalogModel?>.value()
          : getIt<CatalogRepository>().getModels().then<CatalogModel?>(
              (models) => models.where((m) => m.id == motorcycleId).firstOrNull,
              onError: (Object _) => null,
            ),
    ).wait;
    return (
      ad: false,
      signIn: false,
      waiting: waiting,
      typed: typed,
      name: name,
      year: year,
      mileage: mileage,
      years: years,
      value: value,
      market: market,
      exit: exit,
      catalog: catalog,
    );
  }

  Future<_Outcome> _ask(
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
    _TypedAd? typed,
    ComparableYears years = (from: null, to: null),
  }) async {
    if (!_signedIn) {
      return await _valueOf(
        motorcycleId,
        name,
        year: year,
        mileage: mileage,
        typed: typed,
        years: years,
      );
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
      typed: typed,
      years: years,
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
    // Hidden for a linked ad, whose ad is scored as it is stored.
    final years = _comparableYearsShown
        ? _comparableYears()!
        : (from: null, to: null);
    if (widget.checkingAd && _otherSite) {
      final typed = (
        motorcycleId: id,
        price: _priceValue()!,
        seller: _seller,
        description: _adText.text.trim().isEmpty ? null : _adText.text.trim(),
        daysListed: _history()!.daysListed,
        initialPrice: _history()!.initialPrice,
      );
      setState(() {
        _added.putIfAbsent(id, () => choices[id]!);
        _outcome = _ask(
          id,
          choices[id]!,
          year: year,
          mileage: mileage,
          typed: typed,
          years: years,
        );
      });
      return;
    }
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
      _outcome = _ask(
        id,
        choices[id]!,
        year: year,
        mileage: mileage,
        years: years,
      );
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
              if (_sharedAds.isNotEmpty) ...[
                SharedAdsInbox(
                  ads: _sharedAds,
                  onUse: _useSharedAd,
                  onDismiss: (ad) => unawaited(_dismissSharedAd(ad)),
                ),
                const SizedBox(height: 16),
              ],
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.checkAdOtherSite),
              subtitle: Text(strings.checkAdOtherSiteHint),
              value: _otherSite,
              onChanged: (value) => setState(() => _otherSite = value),
            ),
            if (_otherSite && _signedIn)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.adShortcut),
                  icon: const Icon(Icons.ios_share),
                  label: Text(strings.checkAdShortcutLink),
                ),
              ),
            if (_otherSite && (_usedAd?.photos ?? const []).isNotEmpty) ...[
              const SizedBox(height: 8),
              SharedAdPhotos(photos: _usedAd!.photos),
            ],
            const SizedBox(height: 8),
          ],
          if (widget.checkingAd && !_otherSite) ...[
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
                  ? (_otherSite && _usedAd != null
                        ? strings.checkAdModelFromTitle
                        : strings.checkAdModelFromLink)
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
          if (widget.checkingAd && _otherSite) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.askingPriceLabel,
                suffixText: '€',
                border: const OutlineInputBorder(),
              ),
              validator: (_) =>
                  _priceValue() == null ? strings.checkAdPriceInvalid : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<SellerType>(
              segments: [
                ButtonSegment(
                  value: SellerType.private,
                  label: Text(strings.private),
                ),
                ButtonSegment(
                  value: SellerType.dealer,
                  label: Text(strings.checkAdDealer),
                ),
              ],
              selected: {_seller},
              onSelectionChanged: (picked) =>
                  setState(() => _seller = picked.single),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _daysListed,
              // "5 semanas" as well as days.
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: strings.checkAdDaysListed,
                helperText: strings.checkAdDaysListedHelper,
                helperMaxLines: 3,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
              validator: (_) => typedAdDaysValue(_daysListed.text) == null
                  ? strings.checkAdDaysListedInvalid
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _initialPrice,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.checkAdInitialPrice,
                helperText: strings.checkAdInitialPriceHelper,
                helperMaxLines: 3,
                errorMaxLines: 3,
                suffixText: '€',
                border: const OutlineInputBorder(),
              ),
              validator: (_) =>
                  _history() == null &&
                      typedAdDaysValue(_daysListed.text) != null
                  ? strings.checkAdInitialPriceInvalid
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adText,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: strings.checkAdTextLabel,
                helperText: strings.checkAdTextHelper,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_comparableYearsShown) ...[
            const SizedBox(height: 16),
            Text(
              strings.comparableYearsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fromYear,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.comparableFromYear,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (_) => _comparableYears() == null
                        ? strings.comparableYearsInvalid(
                            first: BikeValuePage.firstYear,
                            last: _lastYear,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _toYear,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.comparableToYear,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.comparableYearsHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
        if (outcome.typed case final typed? when value != null) {
          return _typedResult(outcome, typed, value);
        }
        final card = _withYears(
          context,
          outcome,
          BikeValueCard(
            name: outcome.name,
            year: outcome.year,
            value: value,
            market: outcome.market,
            condition: _condition,
            exit: outcome.exit,
          ),
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

  /// The typed ad (N.105): its Deal Score and Risk Score and why (N.107),
  /// what to offer and the message to the seller, as on a stored ad, then
  /// the value it comes from.
  Widget _typedResult(_Outcome outcome, _TypedAd typed, BikeValue value) {
    final asked = _typedScore;
    final Future<TypedAdScore?> score;
    if (asked != null && asked.$1 == outcome && asked.$2 == _condition) {
      score = asked.$3;
    } else {
      // Without its score the ad still gets the offer, from the value.
      score = _repository
          .scoreTypedAd(
            typed.motorcycleId,
            year: outcome.year,
            mileage: outcome.mileage,
            price: typed.price,
            privateSeller: typed.seller == SellerType.private,
            condition: _condition,
            description: typed.description,
            fromYear: outcome.years.from,
            toYear: outcome.years.to,
          )
          .then<TypedAdScore?>((s) => s, onError: (Object _) => null);
      _typedScore = (outcome, _condition, score);
    }
    return FutureBuilder<TypedAdScore?>(
      future: score,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final listing = _typedAdListing(outcome, typed, value, snapshot.data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (outcome.waiting) ...[
              Text(
                context.strings.checkAdTypedWaiting,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (listing.dealScore != null) ...[
              ListingScoreTiles(listing: listing),
              const SizedBox(height: 16),
              ScoreExplanationCard(listing: listing),
              const SizedBox(height: 16),
            ],
            OfferCard(key: ObjectKey(listing), listing: listing),
            const SizedBox(height: 16),
            SellerMessageCard(key: ObjectKey(listing), listing: listing),
            const SizedBox(height: 16),
            if (newPriceLines(
              listing,
              language: context.language,
            ).isNotEmpty) ...[
              NewPriceCard(listing: listing),
              const SizedBox(height: 16),
            ],
            _withYears(
              context,
              outcome,
              BikeValueCard(
                name: outcome.name,
                year: outcome.year,
                value: value,
                market: outcome.market,
                condition: _condition,
                exit: outcome.exit,
              ),
            ),
          ],
        );
      },
    );
  }

  /// [card] under "Comparado só com anúncios de …" when years were chosen.
  Widget _withYears(BuildContext context, _Outcome outcome, Widget card) {
    final line = comparableYearsText(outcome.years, language: context.language);
    if (line == null) return card;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        card,
      ],
    );
  }

  /// The typed ad as a listing, kept while the outcome, the condition and
  /// the score stay, so its cards keep what they loaded.
  Listing _typedAdListing(
    _Outcome outcome,
    _TypedAd typed,
    BikeValue value,
    TypedAdScore? score,
  ) {
    final kept = _typedListing;
    if (kept != null &&
        kept.$1 == outcome &&
        kept.$2 == _condition &&
        kept.$3.dealScore == score?.dealScore &&
        kept.$3.riskScore == score?.riskScore) {
      return kept.$3;
    }
    final listing = typedAdListing(
      motorcycleId: typed.motorcycleId,
      name: outcome.name,
      year: outcome.year,
      mileage: outcome.mileage,
      price: typed.price,
      sellerType: typed.seller,
      value: value,
      condition: _condition,
      catalog: outcome.catalog,
      score: score,
      description: typed.description,
      daysListed: typed.daysListed,
      initialPrice: typed.initialPrice,
    );
    _typedListing = (outcome, _condition, listing);
    return listing;
  }
}
