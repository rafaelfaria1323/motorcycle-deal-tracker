import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/app/di/injection.dart';
import 'package:motorcycle_deal_tracker/app/router/app_routes.dart';
import 'package:motorcycle_deal_tracker/app/shell/app_shell.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/collector_runs_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/database_usage_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/github_token_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/source_quality_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/database_usage.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/github_token.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/source_quality.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/collection_status_page.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/presentation/collector_status_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_card_preferences.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/motorcycle_option.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/price_point.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/alerts_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/favourites_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listing_card_preferences_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/saved_searches_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/alerts_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/compare_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/favourites_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_card_preferences_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_detail_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listings_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/saved_searches_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/alerts_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/dashboard_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/favourites_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/listing_detail_page.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/pages/saved_searches_page.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/accounts_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/home_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/language_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/place.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/push_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/quiet_hours.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/home_place_cubit.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/more_page.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/language_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'language_fixture.dart';

Future<void> loadInterfaceFonts() async {
  final body = FontLoader(AppTheme.bodyFont);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    body.addFont(rootBundle.load('assets/fonts/Barlow-$weight.ttf'));
  }
  final display = FontLoader(AppTheme.displayFont)
    ..addFont(rootBundle.load('assets/fonts/BarlowSemiCondensed-Bold.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([body.load(), display.load(), icons.load()]);
}

Listing interfaceListing(int index) => Listing(
  id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  source: index.isEven ? 'standvirtual' : 'olx',
  url: 'https://www.olx.pt/d/anuncio/test-$index.html',
  brand: index.isEven ? 'Yamaha' : 'Honda',
  model: index.isEven ? 'MT-07' : 'CB650R',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  year: 2023,
  mileage: 12000 + index * 1000,
  price: 6400 + index * 100.0,
  initialPrice: 6800 + index * 100.0,
  dealScore: 92 - index,
  riskScore: 10,
  firstSeenAt: DateTime.utc(2026, 10, 23),
  publishedAt: DateTime.utc(2026, 10, 9),
  siteRefreshedAt: DateTime.utc(2026, 10, 24),
  registrations: 1,
  serviceBook: true,
  origin: 'national',
  colour: 'blue',
  warrantyUntil: DateTime.utc(2027, 3, 1),
  location: 'Matosinhos',
  distanceKm: 8,
  myColour: index == 0,
  description: List.filled(
    20,
    'Mota de garagem, com as revisões em dia e as peças de origem.',
  ).join(' '),
);

class InterfaceFixture {
  InterfaceFixture({
    int total = 6,
    bool emptySearches = false,
    this.signedIn = false,
    this.admin = false,
    this.latestRun,
    this.language = AppLanguage.portuguese,
    this.userChanges = const Stream.empty(),
  }) : repository = InterfaceListings(total),
       searchesRepository = InterfaceSearches(empty: emptySearches);

  final InterfaceListings repository;
  final InterfaceSearches searchesRepository;
  final bool signedIn;
  final bool admin;

  /// The last collection run, as the session may read it (none for an
  /// anonymous one).
  final CollectorRun? latestRun;
  final AppLanguage language;
  final Stream<User?> userChanges;
  late final session = SessionCubit(
    signedIn
        ? const SessionState(
            userId: 'interface-user',
            email: 'owner@example.pt',
            signedIn: true,
          )
        : const SessionState(),
    userChanges,
  );
  final cardPreferencesRepository = InterfaceCardPreferences();
  late final alertsRepository = InterfaceAlerts(searchesRepository);
  late final listings = ListingsCubit(repository, session);
  late final searches = SavedSearchesCubit(
    searchesRepository,
    repository,
    session,
  );
  late final alerts = AlertsCubit(alertsRepository, session);
  final favouritesRepository = InterfaceFavourites();
  late final favourites = FavouritesCubit(favouritesRepository, session);
  final compare = CompareCubit();
  late final languageRepository = LanguageFixture(device: language)
    ..accounts['interface-user'] = language
    ..cache['interface-user'] = language;
  late final languages = LanguageCubit(languageRepository, session);
  final home = InterfaceHome();

  Future<void> initialize() async {
    await getIt.reset();
    getIt.registerSingleton<ListingsRepository>(repository);
    getIt.registerSingleton<ListingsCubit>(listings, dispose: (c) => c.close());
    getIt.registerSingleton<SavedSearchesCubit>(
      searches,
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<AlertsCubit>(alerts, dispose: (c) => c.close());
    getIt.registerSingleton<FavouritesCubit>(
      favourites,
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<CompareCubit>(compare, dispose: (c) => c.close());
    getIt.registerSingleton<SessionCubit>(session, dispose: (c) => c.close());
    getIt.registerSingleton<LanguageRepository>(languageRepository);
    getIt.registerSingleton<LanguageCubit>(
      languages,
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<ListingCardPreferencesCubit>(
      ListingCardPreferencesCubit(cardPreferencesRepository, session),
      dispose: (c) => c.close(),
    );
    final runs = _Runs(latestRun);
    getIt.registerSingleton<CollectorRunsRepository>(runs);
    getIt.registerSingleton<CollectorStatusCubit>(
      CollectorStatusCubit(runs),
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<SourceQualityRepository>(_Quality());
    getIt.registerSingleton<GithubTokenRepository>(_Token());
    getIt.registerSingleton<DatabaseUsageRepository>(_Usage());
    getIt.registerSingleton<HomeRepository>(home);
    getIt.registerSingleton<HomePlaceCubit>(
      HomePlaceCubit(home, session),
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<PushRepository>(_Push());
    getIt.registerSingleton<AccountsRepository>(_Accounts(admin));
    await Future.wait([
      listings.load(),
      searches.load(),
      alerts.load(),
      favourites.load(),
    ]);
  }

  GoRouter router({String initialLocation = AppRoutes.deals}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.deals,
                builder: (_, _) => BlocProvider.value(
                  value: listings,
                  child: const DashboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.searches,
                builder: (_, _) => BlocProvider.value(
                  value: searches,
                  child: const SavedSearchesPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.alerts,
                builder: (_, _) => BlocProvider.value(
                  value: alerts,
                  child: const AlertsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (_, _) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.favourites,
        builder: (_, _) => const FavouritesPage(),
      ),
      GoRoute(
        path: AppRoutes.collectionStatus,
        builder: (_, _) => const CollectionStatusPage(),
      ),
      GoRoute(
        path: '/deals/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (_) => ListingDetailCubit(repository)..load(id),
            child: ListingDetailPage(
              listingId: id,
              keepSection: state.extra == AppRoutes.fromList,
            ),
          );
        },
      ),
    ],
  );
}

Widget interfaceApp(
  GoRouter router, {
  bool dark = false,
  double textScale = 1,
  LanguageCubit? languageCubit,
}) {
  Widget app(AppLanguage language) => MaterialApp.router(
    locale: language.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: appLocales,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
  return languageCubit == null
      ? app(AppLanguage.portuguese)
      : BlocBuilder<LanguageCubit, LanguageState>(
          bloc: languageCubit,
          builder: (context, state) => app(state.language),
        );
}

class InterfaceListings implements ListingsRepository {
  InterfaceListings(this.total);

  final int total;
  bool fail = false;
  final offsets = <int>[];
  ListingSort? lastSort;

  @override
  Future<List<Listing>> getListings({
    ListingFilters filters = ListingFilters.empty,
    ListingSort sort = ListingSort.newest,
    int offset = 0,
    int limit = 40,
  }) async {
    if (fail) throw StateError('Offline');
    offsets.add(offset);
    lastSort = sort;
    return [
      for (var i = offset; i < (offset + limit).clamp(0, total); i++)
        interfaceListing(i),
    ];
  }

  @override
  Future<Listing?> getListingById(String id) async =>
      interfaceListing(int.parse(id.split('-').last));

  @override
  Future<List<MotorcycleOption>> getMotorcycleOptions() async => const [
    MotorcycleOption(id: 'mt07', brand: 'Yamaha', model: 'MT-07'),
    MotorcycleOption(id: 'cb650r', brand: 'Honda', model: 'CB650R'),
  ];

  @override
  Future<List<Listing>> getAlsoListed(Listing listing) async => [];

  @override
  Future<List<Listing>> getCheaperSimilar(Listing listing) async => [];

  @override
  Future<List<PricePoint>> getPriceHistory(String listingId) async => [];
}

class InterfaceSearches implements SavedSearchesRepository {
  InterfaceSearches({required bool empty})
    : values = empty
          ? []
          : [
              SavedSearch(
                id: 'search-1',
                name: 'A próxima mota para as voltas de fim de semana',
                filters: const ListingFilters(maxPrice: 7000, minYear: 2022),
                createdAt: DateTime(2026, 10, 20),
              ),
            ];

  final List<SavedSearch> values;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<List<SavedSearch>> getAll() async {
    if (failReads) throw StateError('Offline');
    return List.of(values);
  }

  @override
  Future<Map<String, int>> getMatchCounts() async => {
    for (final search in values) search.id: 3,
  };

  @override
  Future<SavedSearch> create({
    required String name,
    required ListingFilters filters,
  }) async {
    final search = SavedSearch(
      id: 'search-${values.length + 1}',
      name: name,
      filters: filters,
      createdAt: DateTime(2026, 10, 23),
    );
    values.add(search);
    return search;
  }

  @override
  Future<SavedSearch> update(SavedSearch search) async {
    if (failWrites) throw StateError('Offline');
    final index = values.indexWhere((value) => value.id == search.id);
    if (index == -1) throw StateError('Search not found');
    values[index] = search;
    return search;
  }

  @override
  Future<void> delete(String id) async {
    if (failWrites) throw StateError('Offline');
    values.removeWhere((s) => s.id == id);
  }
}

class InterfaceAlerts implements AlertsRepository {
  InterfaceAlerts(this.searches);

  final InterfaceSearches searches;
  final values = [
    for (var i = 0; i < 3; i++)
      ListingAlert(
        id: 'alert-$i',
        type: AlertType.values[i],
        listing: interfaceListing(i),
        createdAt: DateTime(2026, 10, 23, 10, i * 10),
        oldPrice: 6800,
        newPrice: 6400,
        searchId: i == 0 ? 'search-1' : null,
      ),
  ];
  final markedRead = <String>[];
  final dismissed = <String>{};
  bool allRead = false;
  bool failDismiss = false;
  Future<void>? dismissDelay;

  @override
  Future<List<ListingAlert>> getAll() async => [
    for (final alert in values)
      if (!dismissed.contains(alert.id)) _withSearch(alert),
  ];

  ListingAlert _withSearch(ListingAlert alert) {
    final search = searches.values
        .where((search) => search.id == alert.searchId)
        .firstOrNull;
    return ListingAlert(
      id: alert.id,
      type: alert.type,
      listing: alert.listing,
      createdAt: alert.createdAt,
      searchId: search?.id,
      searchName: search?.name,
      oldPrice: alert.oldPrice,
      newPrice: alert.newPrice,
      readAt: alert.readAt,
    );
  }

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
    for (var i = 0; i < values.length; i++) {
      if (values[i].id == id) {
        values[i] = values[i].copyWith(readAt: DateTime.now());
      }
    }
  }

  @override
  Future<void> markAllRead() async {
    allRead = true;
    final now = DateTime.now();
    for (var i = 0; i < values.length; i++) {
      if (!values[i].isRead) values[i] = values[i].copyWith(readAt: now);
    }
  }

  @override
  Future<void> dismiss(String id) async {
    if (dismissDelay case final delay?) await delay;
    if (failDismiss) throw StateError('Offline');
    dismissed.add(id);
  }
}

class InterfaceCardPreferences implements ListingCardPreferencesRepository {
  ListingCardPreferences value = const ListingCardPreferences.defaults();
  bool failReads = false;
  bool failWrites = false;
  Future<void>? saveDelay;
  int saves = 0;

  @override
  Future<ListingCardPreferences> get(String userId) async {
    if (failReads) throw StateError('Offline');
    return value;
  }

  @override
  Future<void> save(String userId, ListingCardPreferences preferences) async {
    if (failWrites) throw StateError('Offline');
    if (saveDelay case final delay?) await delay;
    value = preferences;
    ++saves;
  }
}

class InterfaceFavourites implements FavouritesRepository {
  final values = <Favourite>[];

  @override
  Future<List<Favourite>> getAll() async => values;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runs(final CollectorRun? latest) implements CollectorRunsRepository {
  @override
  Future<CollectorRun?> getLatest() async => latest;

  @override
  Future<List<CollectorRun>> getSince(DateTime since) async => [?latest];

  @override
  Future<List<CollectorRun>> getRecent(int limit) async => [?latest];
}

class _Quality implements SourceQualityRepository {
  @override
  Future<List<SourceQuality>> getAll() async => [];
}

class _Token implements GithubTokenRepository {
  @override
  Future<GithubToken> check() async =>
      const GithubToken(state: GithubTokenState.ok);
}

class _Usage implements DatabaseUsageRepository {
  @override
  Future<DatabaseUsage> get() async =>
      const DatabaseUsage(bytes: 120 * 1024 * 1024, tables: []);
}

/// No home until one is saved.
class InterfaceHome implements HomeRepository {
  Place? place;

  @override
  Future<Place?> getHome() async => place;

  @override
  Future<void> saveHome(Place place) async => this.place = place;

  @override
  Future<List<Place>> search(String text) async => [
    if ('porto'.startsWith(text.trim().toLowerCase()))
      const Place(key: 'porto', name: 'Porto'),
  ];
}

class _Push implements PushRepository {
  @override
  Future<String?> publicKey() async => null;

  @override
  Future<QuietHours> quietHours() async => QuietHours.standard;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements AccountsRepository {
  _Accounts(this.admin);

  final bool admin;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
