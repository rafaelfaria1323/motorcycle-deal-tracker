import 'package:collector/collector.dart';
import 'package:test/test.dart';

/// A stand-in for the database's rules: a few of their patterns.
final _rules = {
  'e_clutch': RegExp(r'\be\s*-?\s*cl[uú](tc|ct|c|t)h\b'),
  'quickshifter': RegExp('quickshifter'),
  'possible_accident': RegExp(r'(?<!nunca teve )\bacidente'),
};

/// Each call's texts, to check the batches.
final List<List<String>> _calls = [];

Future<List<Set<String>>> _read(List<String> texts) async {
  _calls.add(texts);
  return [
    for (final t in texts)
      {
        for (final e in _rules.entries)
          if (e.value.hasMatch(t)) e.key,
      },
  ];
}

SpellingAd _ad(int n, String description, {String? variant}) => SpellingAd(
  id: 'id$n',
  url: 'https://x/$n',
  variant: variant,
  description: description,
);

/// [n] ads that write [text], numbered from [from].
List<SpellingAd> _many(int from, int n, String text) => [
  for (var i = from; i < from + n; i++) _ad(i, text),
];

void main() {
  setUp(_calls.clear);

  test('reads the database rows, title and description in lower case', () {
    final ad = SpellingAd.fromRow({
      'id': 'a',
      'url': 'https://x/a',
      'variant': 'CB650R E-Clutch',
      'description': 'Como NOVA',
    });
    expect(ad.text, 'cb650r e-clutch. como nova');
    expect(const SpellingAd(id: 'b', url: 'u', description: 'Só').text, 'só');
    expect(const SpellingAd(id: 'c', url: 'u', variant: '').text, '');
  });

  test('edit distance: inserts, deletes, changes and swaps count one', () {
    expect(editDistance('clutch', 'clutch'), 0);
    expect(editDistance('cluch', 'clutch'), 1);
    expect(editDistance('clotch', 'clutch'), 1);
    expect(editDistance('cltuch', 'clutch'), 1);
    expect(editDistance('quickshiter', 'quickshifter'), 1);
    expect(editDistance('quikshiter', 'quickshifter'), 2);
    expect(editDistance('abcdef', 'uvwxyz'), 3, reason: 'capped');
    expect(editDistance('ab', 'abcdef'), 3, reason: 'lengths too far apart');
    expect(maxDistanceFor(7), 1);
    expect(maxDistanceFor(8), 2);
  });

  test('finds a misspelt rule word the rules miss', () async {
    final found = await findMisspellings([
      ..._many(0, 6, 'honda com e clutch e escape'),
      _ad(10, 'honda com e clotch e escape'),
      _ad(11, 'honda com e clotch, pneus novos'),
    ], _read);
    expect(found, hasLength(1));
    final m = found.single;
    expect(m.word, 'clotch');
    expect(m.correction, 'clutch');
    expect(m.ads, 2);
    expect(m.correctionAds, 6);
    expect(m.missed, ['e_clutch']);
    expect(m.wrong, isEmpty);
    expect(m.exampleUrl, 'https://x/10');
  });

  test('finds a misspelling that makes the rules read too much', () async {
    // "nunka" for "nunca": the denial no longer counts.
    final found = await findMisspellings([
      ..._many(0, 6, 'nunca teve acidente'),
      _ad(10, 'nunka teve acidente'),
    ], _read);
    expect(found.single.word, 'nunka');
    expect(found.single.correction, 'nunca');
    expect(found.single.missed, isEmpty);
    expect(found.single.wrong, ['possible_accident']);
  });

  test('two letters off a long word', () async {
    final found = await findMisspellings([
      ..._many(0, 4, 'tem quickshifter'),
      _ad(10, 'tem quikshiter'),
    ], _read);
    expect(found.single.word, 'quikshiter');
    expect(found.single.missed, ['quickshifter']);
  });

  test('ignores near words the rules read the same', () async {
    // "novas" / "novos": no rule depends on them.
    final found = await findMisspellings([
      ..._many(0, 6, 'pneus novos e e clutch'),
      _ad(10, 'jantes novas'),
      // Both spellings already in the rule.
      _ad(11, 'com e cluth'),
    ], _read);
    expect(found, isEmpty);
  });

  test('a near word needs the rule word in three times as many ads', () async {
    final found = await findMisspellings([
      ..._many(0, 5, 'com e clutch'),
      ..._many(10, 2, 'com e clotch'),
    ], _read);
    expect(found, isEmpty, reason: '5 < 3 x 2');
  });

  test('a rule word needs enough ads', () async {
    expect(
      await findMisspellings([
        ..._many(0, 2, 'com e clutch'),
        _ad(10, 'com e clotch'),
      ], _read),
      isEmpty,
    );
    expect(
      await findMisspellings(
        [..._many(0, 2, 'com e clutch'), _ad(10, 'com e clotch')],
        _read,
        minAds: 2,
      ),
      isEmpty,
      reason: 'still 3 x 1 > 2',
    );
  });

  test('short words and allowed words are never checked', () async {
    expect(
      await findMisspellings(
        [..._many(0, 6, 'com e clutch'), _ad(10, 'com e clotch')],
        _read,
        allowed: {'clotch'},
      ),
      isEmpty,
    );
    // "clut" is four letters.
    final rules = {'x': RegExp(r'\bclut\b')};
    Future<List<Set<String>>> read(List<String> texts) async => [
      for (final t in texts)
        {
          for (final e in rules.entries)
            if (e.value.hasMatch(t)) e.key,
        },
    ];
    expect(
      await findMisspellings([
        ..._many(0, 6, 'tem clut'),
        _ad(10, 'tem clot'),
      ], read),
      isEmpty,
    );
  });

  test('nothing near: the rules are not asked', () async {
    expect(await findMisspellings(_many(0, 6, 'pneus novos'), _read), isEmpty);
    expect(_calls, isEmpty);
  });

  test('asks each text once, in batches', () async {
    final found = await findMisspellings(
      [
        ..._many(0, 6, 'honda com e clutch'),
        ..._many(10, 2, 'honda com e clotch'),
      ],
      _read,
      batchSize: 2,
    );
    expect(found.single.word, 'clotch');
    final asked = [for (final c in _calls) ...c];
    expect(asked.toSet(), hasLength(asked.length));
    expect(_calls.every((c) => c.length <= 2), isTrue);
  });

  test('the text around the word, the rest of the ad left out', () async {
    final far = 'a' * 300;
    await findMisspellings(
      [
        ..._many(0, 6, '$far com e clutch $far'),
        _ad(10, '$far com e clotch $far'),
      ],
      _read,
      window: 10,
    );
    for (final t in [for (final c in _calls) ...c]) {
      expect(t.length, lessThan(40));
    }
  });

  test('a short reading from the rules is an error', () async {
    Future<List<Set<String>>> short(List<String> texts) async => const [];
    expect(
      findMisspellings([
        ..._many(0, 6, 'com e clutch'),
        _ad(10, 'com e clotch'),
      ], short),
      throwsStateError,
    );
  });

  test('the most written first, then by word', () async {
    final found = await findMisspellings([
      ..._many(0, 9, 'tem e clutch e quickshifter'),
      _ad(20, 'tem e clotch'),
      _ad(21, 'tem quickshiter'),
      _ad(22, 'tem quickshiter'),
      _ad(23, 'tem e clutsh'),
    ], _read);
    expect(
      [for (final m in found) m.word],
      ['quickshiter', 'clotch', 'clutsh'],
    );
  });

  group('report', () {
    const finding = Misspelling(
      word: 'clotch',
      correction: 'clutch',
      ads: 2,
      correctionAds: 6,
      missed: ['e_clutch'],
      wrong: [],
      exampleUrl: 'https://x/10',
    );

    test('a table of the findings', () {
      final report = spellingCheckReport(found: [finding], ads: 120, days: 30);
      expect(report, contains('The 120 matched ads seen in the last 30 days'));
      expect(
        report,
        contains(
          '| clotch | clutch (6) | 2 | `e_clutch` | - | [ad](https://x/10) |',
        ),
      );
      expect(report, isNot(contains('more.')));
    });

    test('at most top, with how many more', () {
      final report = spellingCheckReport(
        found: [finding, finding, finding],
        ads: 1,
        days: 7,
        top: 2,
      );
      expect('| clotch |'.allMatches(report), hasLength(2));
      expect(report, contains('And 1 more.'));
    });

    test('none found', () {
      expect(
        spellingCheckReport(found: const [], ads: 0, days: 30),
        contains('No misspelt rule words found.'),
      );
    });
  });
}
