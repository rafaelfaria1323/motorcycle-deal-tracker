import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:motorcycle_deal_tracker/app/di/injection.dart';
import 'package:motorcycle_deal_tracker/app/router/app_routes.dart';
import 'package:motorcycle_deal_tracker/app/shell/app_shell.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';
import 'package:motorcycle_deal_tracker/core/auth/session_cubit.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/collector_runs_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/data/source_quality_repository.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/collector_run.dart';
import 'package:motorcycle_deal_tracker/features/collector_status/domain/source_quality.dart';
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
import 'package:motorcycle_deal_tracker/features/settings/domain/place.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/push_repository.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/more_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.userChanges = const Stream.empty(),
  }) : repository = InterfaceListings(total),
       searchesRepository = InterfaceSearches(empty: emptySearches);

  final InterfaceListings repository;
  final InterfaceSearches searchesRepository;
  final bool signedIn;
  final Stream<User?> userChanges;
  final cardPreferencesRepository = InterfaceCardPreferences();
  final alertsRepository = InterfaceAlerts();
  late final listings = ListingsCubit(repository);
  late final searches = SavedSearchesCubit(searchesRepository, repository);
  late final alerts = AlertsCubit(alertsRepository);
  final favouritesRepository = InterfaceFavourites();
  late final favourites = FavouritesCubit(favouritesRepository);
  final compare = CompareCubit();

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
    final session = SessionCubit(
      signedIn
          ? const SessionState(
              userId: 'interface-user',
              email: 'owner@example.pt',
              signedIn: true,
            )
          : const SessionState(),
      userChanges,
    );
    getIt.registerSingleton<SessionCubit>(session, dispose: (c) => c.close());
    getIt.registerSingleton<ListingCardPreferencesCubit>(
      ListingCardPreferencesCubit(cardPreferencesRepository, session),
      dispose: (c) => c.close(),
    );
    final runs = _Runs();
    getIt.registerSingleton<CollectorRunsRepository>(runs);
    getIt.registerSingleton<CollectorStatusCubit>(
      CollectorStatusCubit(runs),
      dispose: (c) => c.close(),
    );
    getIt.registerSingleton<SourceQualityRepository>(_Quality());
    getIt.registerSingleton<HomeRepository>(_Home());
    getIt.registerSingleton<PushRepository>(_Push());
    getIt.registerSingleton<AccountsRepository>(_Accounts());
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
        path: '/deals/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (_) => ListingDetailCubit(repository)..load(id),
            child: ListingDetailPage(listingId: id),
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
}) => MaterialApp.router(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
);

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

  @override
  Future<List<SavedSearch>> getAll() async => List.of(values);

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
  Future<SavedSearch> update(SavedSearch search) async => search;

  @override
  Future<void> delete(String id) async => values.removeWhere((s) => s.id == id);
}

class InterfaceAlerts implements AlertsRepository {
  final values = [
    for (var i = 0; i < 3; i++)
      ListingAlert(
        id: 'alert-$i',
        type: AlertType.values[i],
        listing: interfaceListing(i),
        createdAt: DateTime(2026, 10, 23, 10, i * 10),
        oldPrice: 6800,
        newPrice: 6400,
        searchName: 'Até 7 000 euros',
      ),
  ];
  final markedRead = <String>[];
  bool allRead = false;

  @override
  Future<List<ListingAlert>> getAll() async => values;

  @override
  Future<void> markRead(String id) async => markedRead.add(id);

  @override
  Future<void> markAllRead() async => allRead = true;
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

class _Runs implements CollectorRunsRepository {
  @override
  Future<CollectorRun?> getLatest() async => null;

  @override
  Future<List<CollectorRun>> getSince(DateTime since) async => [];

  @override
  Future<List<CollectorRun>> getRecent(int limit) async => [];
}

class _Quality implements SourceQualityRepository {
  @override
  Future<List<SourceQuality>> getAll() async => [];
}

class _Home implements HomeRepository {
  @override
  Future<Place?> getHome() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push implements PushRepository {
  @override
  Future<String?> publicKey() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements AccountsRepository {
  @override
  Future<bool> isAdmin() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
