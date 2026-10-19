import '../adapters/manual/manual_adapter.dart';
import '../adapters/manual/manual_mapper.dart';
import '../adapters/source_adapter.dart';
import '../adapters/standvirtual/standvirtual_mapper.dart';
import '../adapters/standvirtual/standvirtual_page_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import '../catalog/catalog.dart';
import '../normalized/normalized_listing.dart';

/// One record after mapping, with something to name it by in the output.
class MappedRecord {
  const MappedRecord(this.ref, this.outcome);

  final String ref;
  final MapOutcome outcome;
}

/// Everything one run read from one source, already mapped.
class SourceBatch {
  const SourceBatch(this.source, this.issues, this.records);

  final String source;
  final List<ParseIssue> issues;
  final List<MappedRecord> records;
}

const sourceKinds = ['manual', 'standvirtual', 'standvirtual-search'];

Future<SourceBatch> loadBatch(String kind, String path, Catalog catalog) async {
  switch (kind) {
    case 'manual':
      final adapter = ManualAdapter(path);
      final mapper = ManualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(raw.url, mapper.map(raw)),
      ]);
    case 'standvirtual':
      final adapter = StandvirtualPageAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(raw.url, mapper.map(raw)),
      ]);
    case 'standvirtual-search':
      final adapter = StandvirtualSearchAdapter(path);
      final mapper = StandvirtualMapper(catalog);
      final result = await adapter.read();
      return SourceBatch(adapter.source, result.issues, [
        for (final raw in result.records)
          MappedRecord(raw.url, mapper.map(raw)),
      ]);
    default:
      throw ArgumentError('Unknown source "$kind"');
  }
}
