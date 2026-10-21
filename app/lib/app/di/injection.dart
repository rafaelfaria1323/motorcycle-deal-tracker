import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_cubit.dart';
import '../../core/auth/session_cubit.dart';
import '../../features/collector_status/data/collector_runs_repository.dart';
import '../../features/collector_status/data/database_usage_repository.dart';
import '../../features/collector_status/data/github_token_repository.dart';
import '../../features/collector_status/data/source_quality_repository.dart';
import '../../features/collector_status/presentation/collector_status_cubit.dart';
import '../../features/listings/data/repositories/supabase_alerts_repository.dart';
import '../../features/listings/data/repositories/supabase_catalog_repository.dart';
import '../../features/listings/data/repositories/supabase_dealer_repository.dart';
import '../../features/listings/data/repositories/supabase_favourites_repository.dart';
import '../../features/listings/data/repositories/supabase_listings_repository.dart';
import '../../features/listings/data/repositories/supabase_market_behaviour_repository.dart';
import '../../features/listings/data/repositories/supabase_ownership_settings_repository.dart';
import '../../features/listings/data/repositories/supabase_saved_searches_repository.dart';
import '../../features/listings/data/repositories/supabase_weekly_summary_repository.dart';
import '../../features/listings/domain/repositories/alerts_repository.dart';
import '../../features/listings/domain/repositories/catalog_repository.dart';
import '../../features/listings/domain/repositories/dealer_repository.dart';
import '../../features/listings/domain/repositories/favourites_repository.dart';
import '../../features/listings/domain/repositories/listings_repository.dart';
import '../../features/listings/domain/repositories/market_behaviour_repository.dart';
import '../../features/listings/domain/repositories/ownership_settings_repository.dart';
import '../../features/listings/domain/repositories/saved_searches_repository.dart';
import '../../features/listings/domain/repositories/weekly_summary_repository.dart';
import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/compare_cubit.dart';
import '../../features/listings/presentation/cubit/favourites_cubit.dart';
import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/cubit/saved_searches_cubit.dart';
import '../../features/settings/data/supabase_accounts_repository.dart';
import '../../features/settings/data/supabase_home_repository.dart';
import '../../features/settings/data/supabase_push_repository.dart';
import '../../features/settings/data/supabase_workflows_repository.dart';
import '../../features/settings/domain/accounts_repository.dart';
import '../../features/settings/domain/home_repository.dart';
import '../../features/settings/domain/push_repository.dart';
import '../../features/settings/domain/workflows_repository.dart';

final getIt = GetIt.instance;

/// Call after Supabase.initialize().
void configureDependencies() {
  getIt
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    ..registerLazySingleton<ListingsRepository>(
      () => SupabaseListingsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<ListingsCubit>(
      () => ListingsCubit(getIt<ListingsRepository>()),
    )
    ..registerFactory<ListingDetailCubit>(
      () => ListingDetailCubit(getIt<ListingsRepository>()),
    )
    ..registerLazySingleton<SavedSearchesRepository>(
      () => SupabaseSavedSearchesRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<SavedSearchesCubit>(
      () => SavedSearchesCubit(
        getIt<SavedSearchesRepository>(),
        getIt<ListingsRepository>(),
      ),
    )
    ..registerLazySingleton<AlertsRepository>(
      () => SupabaseAlertsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AlertsCubit>(
      () => AlertsCubit(getIt<AlertsRepository>()),
    )
    ..registerLazySingleton<FavouritesRepository>(
      () => SupabaseFavouritesRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<FavouritesCubit>(
      () => FavouritesCubit(getIt<FavouritesRepository>()),
    )
    ..registerFactory(
      () => AccountCubit(getIt<SupabaseClient>(), getIt<PushRepository>()),
    )
    ..registerLazySingleton(() => SessionCubit.of(getIt<SupabaseClient>()))
    ..registerLazySingleton(CompareCubit.new)
    ..registerLazySingleton<CollectorRunsRepository>(
      () => SupabaseCollectorRunsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<DatabaseUsageRepository>(
      () => SupabaseDatabaseUsageRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<GithubTokenRepository>(
      () => SupabaseGithubTokenRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton(
      () => CollectorStatusCubit(getIt<CollectorRunsRepository>()),
    )
    ..registerLazySingleton<SourceQualityRepository>(
      () => SupabaseSourceQualityRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<MarketBehaviourRepository>(
      () => SupabaseMarketBehaviourRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => SupabaseHomeRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AccountsRepository>(
      () => SupabaseAccountsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<WorkflowsRepository>(
      () => SupabaseWorkflowsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<PushRepository>(
      () => SupabasePushRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<DealerRepository>(
      () => SupabaseDealerRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<OwnershipSettingsRepository>(
      () => SupabaseOwnershipSettingsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<CatalogRepository>(
      () => SupabaseCatalogRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<WeeklySummaryRepository>(
      () => SupabaseWeeklySummaryRepository(getIt<SupabaseClient>()),
    );
}
