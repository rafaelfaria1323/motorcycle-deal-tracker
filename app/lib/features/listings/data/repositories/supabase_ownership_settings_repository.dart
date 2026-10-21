import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/ownership_settings.dart';
import '../../domain/repositories/ownership_settings_repository.dart';

class SupabaseOwnershipSettingsRepository
    implements OwnershipSettingsRepository {
  SupabaseOwnershipSettingsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'ownership_settings';

  @override
  Future<OwnershipSettings> get() async {
    // Row-level security returns only the current user's row.
    final row = await _client
        .from(_table)
        .select('insurance_per_year, km_per_year, years_to_keep')
        .maybeSingle();
    if (row == null) return const OwnershipSettings();
    return OwnershipSettings(
      insurancePerYear: (row['insurance_per_year'] as num?)?.toInt(),
      kmPerYear: (row['km_per_year'] as num).toInt(),
      yearsToKeep: (row['years_to_keep'] as num).toInt(),
    );
  }

  @override
  Future<void> save(OwnershipSettings settings) async {
    // The user id defaults to the signed-in user.
    await _client.from(_table).upsert({
      'insurance_per_year': settings.insurancePerYear,
      'km_per_year': settings.kmPerYear,
      'years_to_keep': settings.yearsToKeep,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
