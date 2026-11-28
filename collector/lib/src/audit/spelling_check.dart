/// The weekly spelling check (N.137): words in real ads one or two letters
/// off a word the description rules depend on ("e cluch" for "e clutch"),
/// found before someone notices a missed bike. No AI: a vocabulary of the
/// recent ads, an edit distance, and the database's own rules
/// (`text_rule_codes`) asked what a short stretch of text reads as, with
/// the word as written and as corrected. A difference is a finding: a
/// report for adding the spelling to a rule, with a test. Nothing is
/// written.
library;

/// Words judged fine although near a rule's word: real words of their own.
/// Add one here, with what it is, when the report keeps naming it.
const notMisspellings = <String>{};

/// Words shorter than this are never checked: too many real words sit one
/// letter from each other ("caiu", "cair").
const minWordLength = 5;

/// A recent ad's text (`spelling_check_texts`).
class const SpellingAd({
  required final String id,
  required final String url,
  final String? variant,
  final String? description,
}) {
  factory SpellingAd.fromRow(Map<String, dynamic> row) => SpellingAd(
    id: row['id'] as String,
    url: row['url'] as String,
    variant: row['variant'] as String?,
    description: row['description'] as String?,
  );

  /// The title (or version) and description as the rules read them, in
  /// lower case.
  String get text => [
    variant,
    description,
  ].whereType<String>().where((t) => t.isNotEmpty).join('. ').toLowerCase();
}

/// A word that reads differently from its near rule word.
class const Misspelling({
  /// The word as the ads write it.
  required final String word,

  /// The rule word it is near.
  required final String correction,

  /// How many ads write [word].
  required final int ads,

  /// How many ads write [correction].
  required final int correctionAds,

  /// Codes the rules read only once corrected: what the ads miss.
  required final List<String> missed,

  /// Codes the rules read only as written: what the ads wrongly get.
  required final List<String> wrong,

  /// An ad that writes [word].
  required final String exampleUrl,
});

/// What the rules read in each text, in order (`text_rule_codes`).
typedef RuleReader = Future<List<Set<String>>> Function(List<String> texts);

/// The words of [text] (letters only) with where each starts.
Iterable<RegExpMatch> _words(String text) => _word.allMatches(text);
final _word = RegExp(r'\p{L}+', unicode: true);

/// Optimal string alignment distance (a swap of two neighbours counts
/// one), or [limit] + 1 once it is known to be more than [limit].
int editDistance(String a, String b, {int limit = 2}) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var before = List<int>.filled(b.length + 1, 0);
  var row = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final next = List<int>.filled(b.length + 1, 0)..[0] = i;
    var best = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var d = [
        row[j] + 1,
        next[j - 1] + 1,
        row[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1] &&
          before[j - 2] + 1 < d) {
        d = before[j - 2] + 1;
      }
      next[j] = d;
      if (d < best) best = d;
    }
    if (best > limit) return limit + 1;
    before = row;
    row = next;
  }
  return row[b.length] > limit ? limit + 1 : row[b.length];
}

/// How far a word may be from a rule word of [length] letters: one letter
/// up to 7, two from 8.
int maxDistanceFor(int length) => length >= 8 ? 2 : 1;

/// The words left by deleting up to [depth] letters of [word].
Set<String> _deletions(String word, int depth) {
  var level = {word};
  final all = {word};
  for (var d = 0; d < depth; d++) {
    final next = <String>{};
    for (final w in level) {
      for (var i = 0; i < w.length; i++) {
        next.add(w.substring(0, i) + w.substring(i + 1));
      }
    }
    all.addAll(next);
    level = next;
  }
  return all;
}

/// Finds the misspellings of rule words in [ads].
///
/// A word written in [minAds] ads or more is a rule word when the rules
/// read something different in a stretch of text around it once it is
/// replaced by a word of nothing (tried on up to two ads). A word written
/// in at most a third as many ads, [maxDistanceFor] letters or fewer off a
/// rule word, is tried on up to three of its ads, as written and
/// corrected; it is a finding when the rules read something different.
/// [read] is called with at most [batchSize] texts at a time, each text
/// once.
Future<List<Misspelling>> findMisspellings(
  List<SpellingAd> ads,
  RuleReader read, {
  int minAds = 3,
  int window = 100,
  int batchSize = 400,
  Set<String> allowed = notMisspellings,
}) async {
  final texts = [for (final ad in ads) ad.text];
  // Each word's ads, once each, in the ads' order.
  final adsOf = <String, List<int>>{};
  for (var i = 0; i < texts.length; i++) {
    for (final w in {for (final m in _words(texts[i])) m[0]!}) {
      if (w.length >= minWordLength) (adsOf[w] ??= []).add(i);
    }
  }

  // Near pairs: a rare word and a frequent one within reach.
  final frequent = [
    for (final e in adsOf.entries)
      if (e.value.length >= minAds) e.key,
  ];
  final index = <String, List<String>>{};
  for (final c in frequent) {
    for (final d in _deletions(c, maxDistanceFor(c.length))) {
      (index[d] ??= []).add(c);
    }
  }
  final pairs = <(String, String)>[];
  for (final e in adsOf.entries) {
    final w = e.key;
    if (allowed.contains(w)) continue;
    final near = <String>{};
    for (final d in _deletions(w, 2)) {
      for (final c in index[d] ?? const <String>[]) {
        if (c == w || adsOf[c]!.length < 3 * e.value.length) continue;
        if (editDistance(w, c) <= maxDistanceFor(c.length)) near.add(c);
      }
    }
    for (final c in near) {
      pairs.add((w, c));
    }
  }
  if (pairs.isEmpty) return const [];

  final rules = _CachedRules(read, batchSize);
  // The stretch of text around the first time ad [i] writes [word], with
  // the word as written and replaced by [by].
  (String, String)? around(int i, String word, String by) {
    final text = texts[i];
    for (final m in _words(text)) {
      if (m[0] != word) continue;
      final start = m.start - window < 0 ? 0 : m.start - window;
      final end = m.end + window > text.length ? text.length : m.end + window;
      return (
        text.substring(start, end),
        text.substring(start, m.start) + by + text.substring(m.end, end),
      );
    }
    return null;
  }

  // The rule words among the frequent words that have a near word.
  final candidates = {for (final (_, c) in pairs) c}.toList()..sort();
  final relevanceTests = <String, List<(String, String)>>{
    for (final c in candidates)
      c: [for (final i in adsOf[c]!.take(2)) ?around(i, c, 'qqq')],
  };
  await rules.prepare([
    for (final tests in relevanceTests.values)
      for (final (a, b) in tests) ...[a, b],
  ]);
  final ruleWords = {
    for (final e in relevanceTests.entries)
      if (e.value.any((t) => !_same(rules[t.$1], rules[t.$2]))) e.key,
  };

  final tried = [
    for (final (w, c) in pairs)
      if (ruleWords.contains(c))
        (
          w,
          c,
          [
            for (final i in adsOf[w]!.take(3))
              if (around(i, w, c) case final t?) (i, t),
          ],
        ),
  ];
  await rules.prepare([
    for (final (_, _, tests) in tried)
      for (final (_, (a, b)) in tests) ...[a, b],
  ]);

  final found = <Misspelling>[];
  for (final (w, c, tests) in tried) {
    final missed = <String>{};
    final wrong = <String>{};
    int? example;
    for (final (i, (asWritten, corrected)) in tests) {
      final before = rules[asWritten];
      final after = rules[corrected];
      if (_same(before, after)) continue;
      example ??= i;
      missed.addAll(after.difference(before));
      wrong.addAll(before.difference(after));
    }
    if (example == null) continue;
    found.add(
      Misspelling(
        word: w,
        correction: c,
        ads: adsOf[w]!.length,
        correctionAds: adsOf[c]!.length,
        missed: missed.toList()..sort(),
        wrong: wrong.toList()..sort(),
        exampleUrl: ads[example].url,
      ),
    );
  }
  found.sort((a, b) {
    final byAds = b.ads.compareTo(a.ads);
    return byAds != 0 ? byAds : a.word.compareTo(b.word);
  });
  return found;
}

bool _same(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// The rules' readings, each text asked once, in batches.
class _CachedRules(final RuleReader _read, final int _batchSize) {
  final _codes = <String, Set<String>>{};

  Future<void> prepare(Iterable<String> texts) async {
    final missing = {
      for (final t in texts)
        if (!_codes.containsKey(t)) t,
    }.toList();
    for (var s = 0; s < missing.length; s += _batchSize) {
      final batch = missing.sublist(
        s,
        s + _batchSize > missing.length ? missing.length : s + _batchSize,
      );
      final read = await _read(batch);
      if (read.length != batch.length) {
        throw StateError(
          'The rules read ${read.length} of ${batch.length} texts.',
        );
      }
      for (var i = 0; i < batch.length; i++) {
        _codes[batch[i]] = read[i];
      }
    }
  }

  Set<String> operator [](String text) => _codes[text]!;
}

/// The report: the findings, most ads first, at most [top].
String spellingCheckReport({
  required List<Misspelling> found,
  required int ads,
  required int days,
  int top = 30,
}) {
  final out = StringBuffer()
    ..writeln('## Misspelt rule words')
    ..writeln()
    ..writeln(
      'The $ads matched ads seen in the last $days days (not duplicates). '
      'Each word below is written in a few ads, one or two letters off a '
      'word the description rules depend on, and the rules read a stretch '
      'of text around it differently once corrected. Missed: what the rules '
      'read only once corrected. Wrong: what they read only as written. '
      'Add the spelling to the rule (with a test), or the word to '
      '`notMisspellings` (spelling_check.dart) when it is a word of its own.',
    )
    ..writeln();
  if (found.isEmpty) {
    out
      ..writeln('No misspelt rule words found.')
      ..writeln();
    return out.toString();
  }
  out
    ..writeln('| Word | Rule word | Ads | Missed | Wrong | Example |')
    ..writeln('|---|---|---:|---|---|---|');
  for (final m in found.take(top)) {
    out.writeln(
      '| ${m.word} | ${m.correction} (${m.correctionAds}) | ${m.ads} | '
      '${_codes(m.missed)} | ${_codes(m.wrong)} | [ad](${m.exampleUrl}) |',
    );
  }
  if (found.length > top) {
    out.writeln();
    out.writeln('And ${found.length - top} more.');
  }
  out.writeln();
  return out.toString();
}

String _codes(List<String> codes) =>
    codes.isEmpty ? '-' : codes.map((c) => '`$c`').join(', ');
