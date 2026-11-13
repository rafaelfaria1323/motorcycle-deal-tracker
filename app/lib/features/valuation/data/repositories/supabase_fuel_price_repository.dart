import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/fuel_price.dart';
import '../../domain/repositories/fuel_price_repository.dart';

class SupabaseFuelPriceRepository implements FuelPriceRepository {
  SupabaseFuelPriceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FuelPrice?> latest() async {
    final row = await _client
        .from('fuel_prices')
        .select('price, day')
        .eq('fuel', 'petrol_95')
        .order('day', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : fuelPriceOf(row);
  }
}

/// A `fuel_prices` row; null when it can't be read.
FuelPrice? fuelPriceOf(Map<String, dynamic> row) {
  final price = (row['price'] as num?)?.toDouble();
  final day = DateTime.tryParse(row['day'] as String? ?? '');
  if (price == null || day == null) return null;
  return FuelPrice(perLitre: price, day: day);
}
