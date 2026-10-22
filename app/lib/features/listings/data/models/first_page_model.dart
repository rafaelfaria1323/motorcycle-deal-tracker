import 'dart:convert';

import '../../domain/entities/first_page.dart';
import '../../domain/entities/motorcycle_option.dart';
import 'listing_model.dart';

/// A row of `motorcycles` with `id, brand, model`.
MotorcycleOption motorcycleOptionFromJson(Map<String, dynamic> row) =>
    MotorcycleOption(
      id: row['id'] as String,
      brand: row['brand'] as String,
      model: row['model'] as String,
    );

/// Reads `index.html`'s answer (`{"listings": [...], "motorcycles": [...]}`,
/// the rows the app's own queries return); null when there is none or it
/// can't be read, so the app asks the database itself.
FirstPage? firstPageFromJson(String? text) {
  if (text == null) return null;
  try {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return FirstPage(
      listings: [
        for (final row in json['listings'] as List)
          ListingModel.fromJson(row as Map<String, dynamic>),
      ],
      motorcycles: [
        for (final row in json['motorcycles'] as List)
          motorcycleOptionFromJson(row as Map<String, dynamic>),
      ],
    );
  } on Object {
    return null;
  }
}
