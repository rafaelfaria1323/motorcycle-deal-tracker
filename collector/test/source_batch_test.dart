import 'package:collector/collector.dart';
import 'package:test/test.dart';

import 'helpers.dart';

MappedRecord mapped(String id, {String? search}) => MappedRecord(
  id,
  search: search,
  Mapped(
    testListing(id, source: 'standvirtual', sellerType: SellerType.dealer),
  ),
);

SourceBatch batch(
  List<MappedRecord> records, {
  List<ParseIssue> issues = const [],
  SearchManifest? manifest,
}) => SourceBatch('standvirtual', issues, records, manifest: manifest);

const a = 'https://www.standvirtual.com/motos/yamaha/mt-07';
const b = 'https://www.standvirtual.com/motos/yamaha/r/q-7';
const both = SearchManifest(planned: [a, b], files: {'a.html': a, 'b.html': b});

void main() {
  test('a rejected bike still on the site counts as seen', () {
    final ids = liveIds(
      batch([
        mapped('a'),
        const MappedRecord(
          'old',
          Rejected('year 2016 is below the tracked range'),
          liveId: 'b',
        ),
      ]),
    );

    expect(ids, unorderedEquals(['a', 'b']));
  });

  test('a rejected record without an id makes the input untrustworthy', () {
    final ids = liveIds(
      batch([
        mapped('a'),
        const MappedRecord('gone', Rejected('listing is not active')),
      ]),
    );

    expect(ids, isNull);
  });

  group('removal plan', () {
    test('without a manifest the whole input must be clean', () {
      final clean = removalPlan(batch([mapped('1')]));
      expect(clean.skipReason, isNull);
      expect(clean.searches, isNull);

      final unclean = removalPlan(
        batch([mapped('1')], issues: [const ParseIssue(0, 'bad page')]),
      );
      expect(unclean.skipReason, isNotNull);
    });

    test('every planned search read in full covers unclaimed listings', () {
      final plan = removalPlan(
        batch([mapped('1', search: a), mapped('2', search: b)], manifest: both),
      );

      expect(plan.skipReason, isNull);
      expect(plan.searches, [a, b]);
      expect(plan.seenIds, unorderedEquals(['1', '2']));
      expect(plan.includeUnkeyed, isTrue);
    });

    test('a search with a problem keeps its listings; the others go on', () {
      final plan = removalPlan(
        batch(
          [mapped('1', search: a), mapped('2', search: b)],
          issues: [const ParseIssue(1, 'more pages exist', search: b)],
          manifest: both,
        ),
      );

      expect(plan.searches, [a]);
      expect(plan.includeUnkeyed, isFalse);
    });

    test('a search the run never reached keeps its listings', () {
      final plan = removalPlan(
        batch(
          [mapped('1', search: a)],
          manifest: const SearchManifest(planned: [a, b], files: {'a.html': a}),
        ),
      );

      expect(plan.searches, [a]);
      expect(plan.includeUnkeyed, isFalse);
    });

    test('a rejected record without an id only spoils its own search', () {
      final plan = removalPlan(
        batch([
          mapped('1', search: a),
          const MappedRecord('gone', Rejected('not active'), search: b),
        ], manifest: both),
      );

      expect(plan.searches, [a]);
    });

    test('a search read in full that returned no listing removes nothing', () {
      final plan = removalPlan(
        batch(
          [],
          manifest: const SearchManifest(planned: [a], files: {'a.html': a}),
        ),
      );

      expect(plan.skipReason, 'no search was read in full');
    });

    test('a problem in a search outside the plan still keeps unkeyed ones', () {
      final plan = removalPlan(
        batch(
          [mapped('1', search: a)],
          issues: [const ParseIssue(0, 'missing page', search: b)],
          manifest: const SearchManifest(
            planned: [a],
            files: {'a.html': a, 'b.html': b},
          ),
        ),
      );

      expect(plan.searches, [a]);
      expect(plan.includeUnkeyed, isFalse);
    });

    test('a problem no search owns stops all removal', () {
      final plan = removalPlan(
        batch(
          [mapped('1', search: a)],
          issues: [const ParseIssue(0, 'unreadable page')],
          manifest: both,
        ),
      );

      expect(plan.skipReason, isNotNull);
    });
  });
}
