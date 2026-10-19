import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_cubit.dart';
import '../../features/collector_status/data/collector_runs_repository.dart';
import '../../features/collector_status/presentation/collector_status_cubit.dart';
import '../../features/listings/data/repositories/supabase_alerts_repository.dart';
import '../../features/listings/data/repositories/supabase_listings_repository.dart';
import '../../features/listings/data/repositories/supabase_saved_searches_repository.dart';
import '../../features/listings/domain/repositories/alerts_repository.dart';
import '../../features/listings/domain/repositories/listings_repository.dart';
import '../../features/listings/domain/repositories/saved_searches_repository.dart';
import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/cubit/saved_searches_cubit.dart';

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
    );

  getIt.registerFactory(() => AccountCubit(Supabase.instance.client));
  getIt.registerLazySingleton<CollectorRunsRepository>(
    () => SupabaseCollectorRunsRepository(Supabase.instance.client),
  );
  getIt.registerLazySingleton(
    () => CollectorStatusCubit(getIt<CollectorRunsRepository>()),
  );
}
