import '../adapters/manual/manual_adapter.dart';
import '../adapters/manual/manual_mapper.dart';
import '../adapters/olx/olx_mapper.dart';
import '../adapters/olx/olx_search_adapter.dart';
import '../adapters/source_adapter.dart';
import '../adapters/standvirtual/standvirtual_mapper.dart';
import '../adapters/standvirtual/standvirtual_page_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import '../catalog/catalog.dart';
import '../normalized/normalized_listing.dart';
import '../normalized/normalizers.dart';

/// One record after mapping, with something to name it by in the output.
class MappedRecord {
  const MappedRecord(this.ref, this.outcome, {this.liveId});

  final String ref;
  final MapOutcome outcome;

  /// The listing's source id when the source shows it as live, whatever we
  /// made of it: a bike we reject (too old, say) is still on the site, so it
  /// was seen. Null when the record says the listing is gone.
  final String? liveId;
}

/// Source ids of every listing the input shows as live, rejected or not.
/// Null when a rejected record can't be placed, so the input can't be
/// trusted to say what was removed.
List<String>? liveIds(SourceBatch batch) {
  final ids = <String>{};
  for (final record in batch.records) {
    switch (record.outcome) {
      case Mapped(:final listing):
        ids.add(listing.sourceListingId);
      case Rejected():
        final id = record.liveId;
        if (id == null) return null;
        ids.add(id);
    }
  }
  return ids.toList();
}

/// Everything one run read from one source, already mapped.
class SourceBatch {
  const SourceBatch(this.source, this.issues, this.records);

  final String source;
  final List<ParseIssue> issues;
  final List<MappedRecord> records;
}

const sourceKinds = [
  'manual',
  'standvirtual',
  'standvirtual-search',
  'olx-search',
];

Future<SourceBatch> loadBatch(String kind, String path, Catalog catalog) async {
  switch (kind) {
    case 'manual':
      final adapter = ManualAdapter(path);
      final mapper = ManualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: canonicalListingId(raw.url),
          ),
      ]);
    case 'standvirtual':
      final adapter = StandvirtualPageAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: raw.status == 'ACTIVE'
                ? StandvirtualMapper.listingId(raw.id)
                : null,
          ),
      ]);
    case 'standvirtual-search':
      final adapter = StandvirtualSearchAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: raw.status == 'ACTIVE'
                ? StandvirtualMapper.listingId(raw.id)
                : null,
          ),
      ]);
    case 'olx-search':
      final adapter = OlxSearchAdapter(path);
      final mapper = OlxMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(
            raw.url,
            mapper.map(raw),
            liveId: raw.status == 'active' ? OlxMapper.listingId(raw.id) : null,
          ),
      ]);
    default:
      throw ArgumentError('Unknown source "$kind"');
  }
}
