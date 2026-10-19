import 'package:supabase/supabase.dart';

import '../catalog/catalog.dart';

/// The active models from the `motorcycles` table.
Future<Catalog> loadCatalog(SupabaseClient client) async {
  final rows = await client
      .from('motorcycles')
      .select(
        'id, slug, brand, model, min_year, aliases, excluded_words, '
        'engine_cc_min, engine_cc_max',
      )
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
        aliases: List<String>.from(row['aliases'] as List? ?? const []),
        excludedWords: List<String>.from(
          row['excluded_words'] as List? ?? const [],
        ),
        engineCcMin: row['engine_cc_min'] as int?,
        engineCcMax: row['engine_cc_max'] as int?,
      ),
  ]);
}
