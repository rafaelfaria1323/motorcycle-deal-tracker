import 'package:supabase/supabase.dart';

import '../catalog/catalog.dart';

/// The active models from the `motorcycles` table.
Future<Catalog> loadCatalog(SupabaseClient client) async {
  final rows = await client
      .from('motorcycles')
      .select('id, slug, brand, model, min_year')
      .eq('is_active', true)
      .order('slug');

  return Catalog([
    for (final row in rows)
      CatalogEntry(
        id: row['id'] as String,
        slug: row['slug'] as String,
        brand: row['brand'] as String,
        model: row['model'] as String,
        minYear: row['min_year'] as int,
      ),
  ]);
}
