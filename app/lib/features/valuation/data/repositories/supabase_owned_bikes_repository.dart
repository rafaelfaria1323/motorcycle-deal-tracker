import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../listings/data/models/listing_model.dart';
import '../../domain/entities/owned_bike.dart';
import '../../domain/repositories/owned_bikes_repository.dart';

class SupabaseOwnedBikesRepository implements OwnedBikesRepository {
  SupabaseOwnedBikesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'owned_bikes';

  static const columns =
      'id, motorcycle_id, listing_id, year, price_paid, '
      'mileage_at_purchase, bought_on, motorcycles(brand, model, '
      'engine_cc_min, engine_cc_max, ${ListingModel.maintenanceColumns})';

  @override
  Future<List<OwnedBike>> list() async {
    // Row-level security returns only the account's own bikes.
    final rows = await _client
        .from(_table)
        .select(columns)
        .order('bought_on', ascending: false)
        .order('created_at', ascending: false);
    return [for (final row in rows) ownedBikeFrom(row)];
  }

  @override
  Future<void> add(OwnedBikeDraft bike) async {
    final row = ownedBikeRow(bike);
    // The user id defaults to the signed-in account.
    if (bike.listingId == null) {
      await _client.from(_table).insert(row);
    } else {
      await _client.from(_table).upsert(row, onConflict: 'user_id,listing_id');
    }
  }

  @override
  Future<void> update(String id, OwnedBikeDraft bike) async {
    await _client.from(_table).update(ownedBikeRow(bike)).eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

/// The columns an [OwnedBikeDraft] writes.
Map<String, Object?> ownedBikeRow(OwnedBikeDraft bike) => {
  'motorcycle_id': bike.motorcycleId,
  'listing_id': bike.listingId,
  'year': bike.year,
  'price_paid': bike.pricePaid,
  'mileage_at_purchase': bike.mileageAtPurchase,
  'bought_on': _day(bike.boughtOn),
};

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A row of `owned_bikes` with its model ([SupabaseOwnedBikesRepository.columns]).
OwnedBike ownedBikeFrom(Map<String, dynamic> row) {
  final model = row['motorcycles'] as Map<String, dynamic>;
  return OwnedBike(
    id: row['id'] as String,
    purchase: OwnedBikeDraft(
      motorcycleId: row['motorcycle_id'] as String,
      listingId: row['listing_id'] as String?,
      year: (row['year'] as num).toInt(),
      pricePaid: (row['price_paid'] as num?)?.toInt(),
      mileageAtPurchase: (row['mileage_at_purchase'] as num?)?.toInt(),
      boughtOn: DateTime.parse(row['bought_on'] as String),
    ),
    brand: model['brand'] as String,
    model: model['model'] as String,
    engineCc: ListingModel.engineCcOf(model),
    maintenance: ListingModel.maintenanceOf(model),
  );
}
