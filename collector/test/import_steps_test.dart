import 'package:collector/collector.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Records the store calls an import makes, in order.
class _Store implements ListingStore {
  final calls = <String>[];
  List<String>? removedSeen;
  bool? removedForced;

  @override
  Future<StoreResult> save(List<NormalizedListing> l, Catalog c) async {
    calls.add('save ${l.length}');
    return StoreResult(
      inserted: l.length,
      alreadyStored: 0,
      duplicatesInInput: 0,
    );
  }

  @override
  Future<int> markSeen(String source, List<String> ids) async {
    calls.add('markSeen ${ids.join(',')}');
    return ids.length;
  }

  @override
  Future<int> rematch(String s, List<NormalizedListing> l, Catalog c) async {
    calls.add('rematch');
    return 0;
  }

  @override
  Future<int> applyPriceChanges(String s, List<NormalizedListing> l) async {
    calls.add('applyPriceChanges');
    return 0;
  }

  @override
  Future<int> setSearchKeys(String s, Map<String, String> keys) async {
    calls.add('setSearchKeys');
    return keys.length;
  }

  @override
  Future<int> applyPricesBeforeDrop(String s, List<NormalizedListing> l) async {
    calls.add('applyPricesBeforeDrop');
    return 0;
  }

  @override
  Future<int> applyListingDates(String s, List<NormalizedListing> l) async {
    calls.add('applyListingDates');
    return 0;
  }

  @override
  Future<int> saveSiteModels(String s, List<SiteModel> models) async {
    calls.add('saveSiteModels ${models.length}');
    return models.length;
  }

  @override
  Future<int> markRemoved(
    String source,
    List<String> seenIds, {
    bool force = false,
    List<String>? searches,
    bool includeUnkeyed = true,
  }) async {
    calls.add('markRemoved');
    removedSeen = seenIds;
    removedForced = force;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MappedRecord _mapped(String id) => MappedRecord(id, Mapped(testListing(id)));

/// Two bikes we keep and an old one we reject that is still on the site.
SourceBatch _batch({
  List<ParseIssue> issues = const [],
  List<SiteModel> siteModels = const [],
}) => SourceBatch('olx', issues, [
  _mapped('a'),
  _mapped('b'),
  const MappedRecord('old', Rejected('year 2015 too old'), liveId: 'c'),
], siteModels: siteModels);

void main() {
  final catalog = Catalog(const []);

  test('a dry run only describes the batch', () async {
    final out = StringBuffer();
    await importBatch(_batch(), catalog, store: null, out: out);

    expect(out.toString(), contains('Mapped 2, rejected 1.'));
    expect(out.toString(), contains('Dry run: nothing was written.'));
  });

  test('the steps run in order; without --full nothing is removed', () async {
    final store = _Store();
    await importBatch(_batch(), catalog, store: store, out: StringBuffer());

    expect(store.calls, [
      'save 2',
      'markSeen a,b',
      'rematch',
      'applyPriceChanges',
      'setSearchKeys',
      'applyPricesBeforeDrop',
      'applyListingDates',
    ]);
  });

  test('the site\'s brand and model lists are stored', () async {
    final store = _Store();
    final out = StringBuffer();
    await importBatch(
      _batch(
        siteModels: const [
          SiteModel(
            makeId: 'yamaha',
            makeName: 'yamaha',
            modelId: 'mt-07',
            modelName: 'MT-07',
          ),
        ],
      ),
      catalog,
      store: store,
      out: out,
    );

    expect(store.calls.last, 'saveSiteModels 1');
    expect(out.toString(), contains('Brands and models on offer: 1'));
  });

  test(
    'a clean full import removes, counting rejected bikes as seen',
    () async {
      final store = _Store();
      await importBatch(
        _batch(),
        catalog,
        store: store,
        full: true,
        out: StringBuffer(),
      );

      expect(store.calls.last, 'markRemoved');
      expect(store.removedSeen, unorderedEquals(['a', 'b', 'c']));
      expect(store.removedForced, isFalse);
    },
  );

  test('an input with unreadable records removes nothing', () async {
    final store = _Store();
    final out = StringBuffer();
    await importBatch(
      _batch(issues: [const ParseIssue(3, 'bad JSON')]),
      catalog,
      store: store,
      full: true,
      out: out,
    );

    expect(store.calls, isNot(contains('markRemoved')));
    expect(out.toString(), contains('Removal skipped'));
  });

  test('--force removes even then', () async {
    final store = _Store();
    await importBatch(
      _batch(issues: [const ParseIssue(3, 'bad JSON')]),
      catalog,
      store: store,
      full: true,
      force: true,
      out: StringBuffer(),
    );

    expect(store.calls.last, 'markRemoved');
    expect(store.removedForced, isTrue);
    expect(store.removedSeen, unorderedEquals(['a', 'b', 'c']));
  });
}
