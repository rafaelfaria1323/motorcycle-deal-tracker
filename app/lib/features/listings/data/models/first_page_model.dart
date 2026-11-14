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

/// Reads `index.html`'s answer (`{"user": ..., "listings": [...],
/// "motorcycles": [...]}`, the rows the app's own queries return, asked as
/// `user`: an account's id, or null without one); null when there is
/// none, it can't be read or it was asked for another than [account] (the
/// account the app starts with; null for none or an anonymous session),
/// so the app asks the database itself.
FirstPage? firstPageFromJson(String? text, {String? account}) {
  if (text == null) return null;
  try {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if ((json['user'] as String?) != account) return null;
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
