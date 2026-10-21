import 'package:supabase/supabase.dart';

import '../catalog/catalog.dart';

/// The active models from the `motorcycles` table, oldest first: when the
/// request budget runs out, the searches of the newest models wait.
Future<Catalog> loadCatalog(SupabaseClient client) async {
  final rows = await client
      .from('motorcycles')
      .select(
        'id, slug, brand, model, min_year, aliases, excluded_words, '
        'engine_cc_min, engine_cc_max, olx_search, standvirtual_search',
      )
      .eq('is_active', true)
      .order('created_at')
      .order('slug');

  return catalogFromRows(rows);
}

/// Maps `motorcycles` rows, in the order given, to a [Catalog]; null list
/// columns become empty lists.
Catalog catalogFromRows(Iterable<Map<String, dynamic>> rows) {
  return Catalog([
    for (final row in rows)
      CatalogEntry(
        id: row['id'] as String,
        slug: row['slug'] as String,
        brand: row['brand'] as String,
        model: row['model'] as String,
        minYear: row['min_year'] as int,
        aliases: List<String>.from(row['aliases'] as List? ?? const []),
        excludedWords: List<String>.from(
          row['excluded_words'] as List? ?? const [],
        ),
        engineCcMin: row['engine_cc_min'] as int?,
        engineCcMax: row['engine_cc_max'] as int?,
        olxSearch: row['olx_search'] as String?,
        standvirtualSearch: row['standvirtual_search'] as String?,
      ),
  ]);
}
