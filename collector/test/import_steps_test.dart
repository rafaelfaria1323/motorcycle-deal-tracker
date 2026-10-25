import 'package:collector/collector.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Records the store calls an import makes, in order.
class _Store implements ListingStore {
  final calls = <String>[];
  List<String>? removedSeen;
  bool? removedForced;
  List<String>? removedSearches;
  bool? removedIncludeUnkeyed;

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
    removedSearches = searches;
    removedIncludeUnkeyed = includeUnkeyed;
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
    final cleanInput = await importBatch(
      _batch(),
      catalog,
      store: null,
      out: out,
    );

    expect(cleanInput, isTrue);
    expect(out.toString(), contains('Mapped 2, rejected 1.'));
    expect(out.toString(), contains('Dry run: nothing was written.'));
  });

  test('the log says what each planned search cost and gave', () async {
    const a = 'https://www.olx.pt/a', b = 'https://www.olx.pt/b';
    final out = StringBuffer();
    await importBatch(
      SourceBatch(
        'olx',
        const [],
        [MappedRecord('a', Mapped(testListing('a')), search: a)],
        manifest: const SearchManifest(
          planned: [a, b],
          files: {'a.html': a},
          pages: {a: 1},
        ),
      ),
      catalog,
      store: null,
      labels: {a: 'yamaha-mt-07, yamaha-r7'},
      out: out,
    );

    expect(
      out.toString(),
      allOf(
        contains(
          'Search (olx): yamaha-mt-07, yamaha-r7 · read 1 of 1 page(s) · '
          '1 ad(s), 0 followed · in full\n',
        ),
        contains(
          'Search (olx): $b · read 0 of ? page(s) · 0 ad(s), 0 followed · '
          'not in full\n',
        ),
      ),
    );
  });

  test('an unmatched ad shows its brand and model, phone numbers masked', () {
    NormalizedListing ad(String model) => NormalizedListing(
      source: 'olx',
      sourceListingId: '1',
      url: 'https://example.com/1',
      brand: 'Honda',
      model: model,
      price: 5000,
      sellerType: SellerType.private,
      images: const [],
    );

    expect(
      unmatchedLabel(ad('NSS 350  Forza')),
      'unmatched "Honda NSS 350 Forza"',
    );
    expect(
      unmatchedLabel(ad('SH 350 ligue 912 345 678')),
      'unmatched "Honda SH 350 ligue …"',
    );
    expect(unmatchedLabel(ad('x' * 80)).length, lessThan(75));
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
    final cleanInput = await importBatch(
      _batch(issues: [const ParseIssue(3, 'bad JSON')]),
      catalog,
      store: store,
      full: true,
      out: out,
    );

    expect(cleanInput, isFalse);
    expect(store.calls.first, 'save 2');
    expect(store.calls, contains('markSeen a,b'));
    expect(store.calls, isNot(contains('markRemoved')));
    expect(out.toString(), contains('Removal skipped'));
    expect(out.toString(), contains('Read issue: '));
  });

  test(
    'read issues fail the input without blocking a trusted search',
    () async {
      const a = 'https://www.olx.pt/a', b = 'https://www.olx.pt/b';
      final store = _Store();
      final cleanInput = await importBatch(
        SourceBatch(
          'olx',
          const [ParseIssue(3, 'bad JSON', search: b)],
          [MappedRecord('a', Mapped(testListing('a')), search: a)],
          manifest: const SearchManifest(
            planned: [a, b],
            files: {'a.html': a, 'b.html': b},
            pages: {a: 1, b: 1},
          ),
        ),
        catalog,
        store: store,
        full: true,
        out: StringBuffer(),
      );

      expect(cleanInput, isFalse);
      expect(store.calls.first, 'save 1');
      expect(store.calls.last, 'markRemoved');
      expect(store.removedSeen, ['a']);
      expect(store.removedSearches, [a]);
      expect(store.removedIncludeUnkeyed, isFalse);
    },
  );

  test('--force removes even then', () async {
    final store = _Store();
    final cleanInput = await importBatch(
      _batch(issues: [const ParseIssue(3, 'bad JSON')]),
      catalog,
      store: store,
      full: true,
      force: true,
      out: StringBuffer(),
    );

    expect(cleanInput, isFalse);
    expect(store.calls.last, 'markRemoved');
    expect(store.removedForced, isTrue);
    expect(store.removedSeen, unorderedEquals(['a', 'b', 'c']));
  });
}
