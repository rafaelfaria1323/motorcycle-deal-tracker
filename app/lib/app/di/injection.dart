import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_cubit.dart';
import '../../core/auth/session_cubit.dart';
import '../../features/collector_status/data/collector_runs_repository.dart';
import '../../features/collector_status/data/database_usage_repository.dart';
import '../../features/collector_status/data/github_token_repository.dart';
import '../../features/collector_status/data/source_quality_repository.dart';
import '../../features/collector_status/presentation/collector_status_cubit.dart';
import '../../features/alerts/data/repositories/supabase_alerts_repository.dart';
import '../../features/listings/data/repositories/supabase_catalog_repository.dart';
import '../../features/listings/data/repositories/supabase_dealer_repository.dart';
import '../../features/listings/data/repositories/supabase_photo_exams_repository.dart';
import '../../features/listings/data/repositories/supabase_photo_marks_repository.dart';
import '../../features/favourites/data/repositories/supabase_favourites_repository.dart';
import '../../features/listings/data/repositories/supabase_listing_card_preferences_repository.dart';
import '../../features/listings/data/repositories/supabase_listings_repository.dart';
import '../../features/market/data/repositories/supabase_market_behaviour_repository.dart';
import '../../features/valuation/data/repositories/supabase_ownership_settings_repository.dart';
import '../../features/saved_searches/data/repositories/supabase_saved_searches_repository.dart';
import '../../features/alerts/data/repositories/supabase_weekly_summary_repository.dart';
import '../../features/alerts/domain/repositories/alerts_repository.dart';
import '../../features/listings/domain/repositories/catalog_repository.dart';
import '../../features/listings/domain/repositories/dealer_repository.dart';
import '../../features/listings/domain/repositories/photo_exams_repository.dart';
import '../../features/listings/domain/repositories/photo_marks_repository.dart';
import '../../features/favourites/domain/repositories/favourites_repository.dart';
import '../../features/listings/domain/repositories/listing_card_preferences_repository.dart';
import '../../features/listings/domain/repositories/listings_repository.dart';
import '../../features/market/domain/repositories/market_behaviour_repository.dart';
import '../../features/valuation/domain/repositories/ownership_settings_repository.dart';
import '../../features/saved_searches/domain/repositories/saved_searches_repository.dart';
import '../../features/alerts/domain/repositories/weekly_summary_repository.dart';
import '../../features/alerts/presentation/cubit/alerts_cubit.dart';
import '../../features/compare/presentation/cubit/compare_cubit.dart';
import '../../features/favourites/presentation/cubit/favourites_cubit.dart';
import '../../features/listings/presentation/cubit/listing_card_preferences_cubit.dart';
import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/saved_searches/presentation/cubit/saved_searches_cubit.dart';
import '../../features/settings/data/supabase_accounts_repository.dart';
import '../../features/settings/data/supabase_home_repository.dart';
import '../../features/settings/data/supabase_language_repository.dart';
import '../../features/settings/data/supabase_push_repository.dart';
import '../../features/settings/data/supabase_workflows_repository.dart';
import '../../features/settings/domain/accounts_repository.dart';
import '../../features/settings/domain/home_repository.dart';
import '../../features/settings/domain/language_repository.dart';
import '../../features/settings/domain/push_repository.dart';
import '../../features/settings/domain/workflows_repository.dart';
import '../../features/settings/presentation/home_place_cubit.dart';
import '../../features/settings/presentation/language_cubit.dart';

final getIt = GetIt.instance;

/// Call after Supabase.initialize().
void configureDependencies(SharedPreferences preferences) {
  getIt
    ..registerLazySingleton<SupabaseClient>(() => Supabase.instance.client)
    ..registerLazySingleton<ListingsRepository>(
      () => SupabaseListingsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<ListingsCubit>(
      () => ListingsCubit(getIt<ListingsRepository>(), getIt<SessionCubit>()),
      dispose: (cubit) => cubit.close(),
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
        getIt<SessionCubit>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<AlertsRepository>(
      () => SupabaseAlertsRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<AlertsCubit>(
      () => AlertsCubit(getIt<AlertsRepository>(), getIt<SessionCubit>()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<FavouritesRepository>(
      () => SupabaseFavouritesRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<FavouritesCubit>(
      () =>
          FavouritesCubit(getIt<FavouritesRepository>(), getIt<SessionCubit>()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerFactory(
      () => AccountCubit(getIt<SupabaseClient>(), getIt<PushRepository>()),
    )
    ..registerLazySingleton(
      () => SessionCubit.of(getIt<SupabaseClient>()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<LanguageRepository>(
      () => SupabaseLanguageRepository(getIt<SupabaseClient>(), preferences),
    )
    ..registerLazySingleton(
      () => LanguageCubit(getIt<LanguageRepository>(), getIt<SessionCubit>()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<ListingCardPreferencesRepository>(
      () => SupabaseListingCardPreferencesRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton(
      () => ListingCardPreferencesCubit(
        getIt<ListingCardPreferencesRepository>(),
        getIt<SessionCubit>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
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
    ..registerLazySingleton(
      () => HomePlaceCubit(getIt<HomeRepository>(), getIt<SessionCubit>()),
      dispose: (cubit) => cubit.close(),
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
    ..registerLazySingleton<PhotoMarksRepository>(
      () => SupabasePhotoMarksRepository(getIt<SupabaseClient>()),
    )
    ..registerLazySingleton<PhotoExamsRepository>(
      () => SupabasePhotoExamsRepository(getIt<SupabaseClient>()),
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
