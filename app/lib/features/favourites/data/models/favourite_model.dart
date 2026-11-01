import '../../domain/entities/favourite.dart';
import '../../../listings/data/models/listing_model.dart';

class FavouriteModel {
  const FavouriteModel._();

  /// The columns `fromJson` reads, with the listing embedded.
  static const columns =
      'listing_id, note, checklist, target_price, created_at, '
      'listings(${ListingModel.summaryColumns})';

  /// Expects the row with its listing embedded (`select(columns)`).
  static Favourite fromJson(Map<String, dynamic> json) {
    final listing = json['listings'] as Map<String, dynamic>?;
    return Favourite(
      listingId: json['listing_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      note: json['note'] as String?,
      checklist: checklistFromJson(json['checklist']),
      targetPrice: (json['target_price'] as num?)?.toDouble(),
      listing: listing == null ? null : ListingModel.fromJson(listing),
    );
  }

  /// `{"tyres": {"mark": "issue", "note": "DOT 2017"}}`. Anything it cannot
  /// read (an unknown mark, a value that is not an object) is left out.
  static Map<String, ChecklistEntry> checklistFromJson(Object? json) {
    if (json is! Map) return const {};
    final entries = <String, ChecklistEntry>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key is! String || value is! Map) continue;
      final note = value['note'];
      final entry = ChecklistEntry(
        mark: ChecklistMark.values
            .where((m) => m.name == value['mark'])
            .firstOrNull,
        note: note is String && note.isNotEmpty ? note : null,
      );
      if (!entry.isEmpty) entries[key] = entry;
    }
    return entries;
  }

  static Map<String, Object> checklistToJson(
    Map<String, ChecklistEntry> checklist,
  ) => {
    for (final MapEntry(:key, :value) in checklist.entries)
      if (!value.isEmpty)
        key: {
          if (value.mark case final mark?) 'mark': mark.name,
          'note': ?value.note,
        },
  };
}
