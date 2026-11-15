/// "Avaliar um anúncio" (N.110): what an ad the iPhone shortcut sent says,
/// read from the lines the script kept (price, year, km, how long it has
/// been up), the page's own text (script 3, N.110c), its title and its
/// description, to fill the typed ad's form: price and the price before
/// a drop, year, km, days on sale, the description and what it says of
/// owners, service book, warranty, falls and accidents.
/// The rules live here, not in the database, so they can change with the
/// app; nothing read here is ever fetched from the site.
library;

import '../../listings/domain/entities/listing.dart' show minRealPrice;
import '../domain/entities/bike_condition.dart';
import '../domain/entities/shared_ad.dart';
import 'typed_ad_history.dart' show maxTypedAdDays;

/// What the form takes from a shared ad; each fact may be unknown.
typedef SharedAdFacts = ({
  double? price,

  /// The price before a drop: struck through on the page, or a second,
  /// higher price on the price's line.
  double? initialPrice,
  int? year,
  int? mileage,
  int? daysListed,
  String? description,

  /// What the text says of the bike; unknown where it says nothing.
  BikeCondition condition,

  /// The title's words (lower case), for the model's guess.
  List<String> words,
});

/// The highest price taken (anything above is not a used bike's).
const _maxPrice = 1000000;

/// A number with or without thousands separators ("7 500", "7.500", "7500").
const _number = r'\d{1,3}(?:[.,\s\u00a0\u202f]\d{3})+|\d+';

final _priceAfter = RegExp(
  '($_number)(?:[.,]\\d{1,2})?\\s*(?:€|eur\\b|euros?\\b)',
  caseSensitive: false,
);
final _priceBefore = RegExp(
  '(?:€|\\beur)\\s*($_number)(?:[.,]\\d{1,2})?',
  caseSensitive: false,
);
final _priceAlone = RegExp('^($_number)(?:[.,]\\d{1,2})?\$');

final _yearWord = RegExp(
  r'(?<![\d.,])(19[89]\d|20\d\d)(?![\d.,])(?!\s*(?:km|kms|€|eur|cc|cm))',
  caseSensitive: false,
);
final _yearLabel = RegExp(
  r'\b(ano|year|registo|registration|matr[ií]cula|modelo|fabrico)\b',
  caseSensitive: false,
);

final _mileageLabelled = RegExp(
  '(?:conduzid[oa]|condu[cç][aã]o|driven|quil[oó]metros|quilometragem|mileage|kms?)'
  '\\D{0,5}?($_number)(?!\\s*km/h)',
  caseSensitive: false,
);
final _mileageAlone = RegExp(
  '^\\s*($_number)\\s*(?:km|kms|quil[oó]metros)\\.?\\s*\$',
  caseSensitive: false,
);
final _mileageAnywhere = RegExp(
  '(?<![\\d.,])($_number)\\s*(?:km|kms)\\b(?!/h)'
  '(?!\\s*(?:de dist|away))',
  caseSensitive: false,
);

/// "a 5 km", "within 5 km": a distance, not a mileage.
final _distanceBefore = RegExp(r'\b(a|within|at)\s*$', caseSensitive: false);

final _agoPortuguese = RegExp(
  r'\bh[aá]\s+(?:mais\s+de\s+|cerca\s+de\s+)?(\d+|um|uma)\s+'
  r'(minutos?|horas?|dias?|semanas?|m[eê]s|meses|anos?)\b',
  caseSensitive: false,
);
final _agoEnglish = RegExp(
  r'\b(\d+|a|an|one)\s+(minutes?|hours?|days?|weeks?|months?|years?)\s+ago\b',
  caseSensitive: false,
);
final _yesterday = RegExp(r'\b(ontem|yesterday)\b', caseSensitive: false);

/// The digits of a number read by [_number].
int _digits(String text) => int.parse(text.replaceAll(RegExp(r'\D'), ''));

/// The asking price in [text] (with €, or only a number when [bare]);
/// null below [minRealPrice] or when there is none.
double? _priceIn(String text, {bool bare = false}) {
  final match = bare
      ? _priceAlone.firstMatch(text.trim())
      : (_priceAfter.firstMatch(text) ?? _priceBefore.firstMatch(text));
  if (match == null) return null;
  final value = _digits(match.group(1)!);
  return value >= minRealPrice && value <= _maxPrice ? value.toDouble() : null;
}

/// The page's own lines (script 3), empty ones and "Ver mais" left out.
List<String> _pageLines(SharedAd ad) => [
  for (final line in (ad.pageText ?? '').split('\n'))
    if (line.trim() case final text
        when text.isNotEmpty &&
            !RegExp(
              r'^(ver|mostrar|ler|see|show) (mais|more)$',
              caseSensitive: false,
            ).hasMatch(text))
      text,
];

/// The script's lines, then the page's short ones not among them (a
/// long one is the description, read apart).
List<String> _shortLines(SharedAd ad) => [
  ...ad.lines,
  for (final line in _pageLines(ad))
    if (line.length <= 80 && !ad.lines.contains(line)) line,
];

/// The price the page gave in its data, else the first line with one.
double? sharedAdPrice(SharedAd ad) {
  if (ad.price case final price?) {
    final value =
        _priceIn(price) ??
        _priceIn(
          price.replaceAll(RegExp('€|eur', caseSensitive: false), ''),
          bare: true,
        );
    if (value != null) return value;
  }
  for (final line in _shortLines(ad)) {
    if (_priceIn(line) case final value?) return value;
  }
  return null;
}

/// The price before a drop: the struck-through one, else a second price
/// on the price's line ("6 900 € 7 400 €"); only above [price].
double? sharedAdInitialPrice(SharedAd ad, double? price) {
  if (price == null) return null;
  double? above(double? value) => value != null && value > price ? value : null;
  if (ad.oldPrice case final old?) {
    if (above(_priceIn(old)) case final value?) return value;
  }
  for (final line in _shortLines(ad)) {
    final prices = [
      for (final match in _priceAfter.allMatches(line))
        if (_priceIn(match.group(0)!) case final value?) value,
    ];
    if (prices.length >= 2 && prices.first == price) {
      return above(prices[1]);
    }
  }
  return null;
}

/// The bike's year: in the title ("2019 Yamaha MT-07"), else a line
/// labelled as one ("Ano: 2019"); only from 1990 to next year.
int? sharedAdYear(SharedAd ad, {required DateTime now}) {
  int? yearIn(String text) {
    for (final match in _yearWord.allMatches(text)) {
      final year = int.parse(match.group(1)!);
      if (year >= 1990 && year <= now.year + 1) return year;
    }
    return null;
  }

  if (ad.title case final title?) {
    if (yearIn(title) case final year?) return year;
  }
  for (final line in _shortLines(ad)) {
    if (!_yearLabel.hasMatch(line)) continue;
    if (yearIn(line) case final year?) return year;
  }
  return null;
}

/// The mileage: a line that says it ("Conduzido 25 000 km", "Km: 7.500"),
/// else a line that is only that ("25 000 km"), else the first km in a
/// line or the title. A distance from the person ("a 5 km") is no mileage.
int? sharedAdMileage(SharedAd ad) {
  final lines = _shortLines(ad);
  for (final line in lines) {
    if (_mileageLabelled.firstMatch(line) case final match?) {
      return _digits(match.group(1)!);
    }
  }
  for (final line in lines) {
    if (_mileageAlone.firstMatch(line) case final match?) {
      return _digits(match.group(1)!);
    }
  }
  for (final text in [...lines, ?ad.title]) {
    for (final match in _mileageAnywhere.allMatches(text)) {
      if (_distanceBefore.hasMatch(text.substring(0, match.start))) continue;
      return _digits(match.group(1)!);
    }
  }
  return null;
}

/// Days in one [unit] of "há 5 semanas" / "5 weeks ago".
int _unitDays(String unit) => switch (unit.toLowerCase()) {
  final u when u.startsWith('min') || u.startsWith('hora') => 0,
  final u when u.startsWith('hour') => 0,
  final u when u.startsWith('di') || u.startsWith('day') => 1,
  final u when u.startsWith('sem') || u.startsWith('week') => 7,
  final u when u.startsWith('m') => 30,
  _ => 365,
};

/// How long the ad has been up, from the first line that says so ("há 5
/// semanas", "Listed 3 weeks ago", "ontem"; a month is 30 days); null
/// when none does or it is over [maxTypedAdDays].
int? sharedAdDaysListed(SharedAd ad) {
  for (final line in _shortLines(ad)) {
    final match =
        _agoPortuguese.firstMatch(line) ?? _agoEnglish.firstMatch(line);
    if (match != null) {
      final count = int.tryParse(match.group(1)!) ?? 1;
      final days = count * _unitDays(match.group(2)!);
      return days > maxTypedAdDays ? null : days;
    }
    if (_yesterday.hasMatch(line)) return 1;
  }
  return null;
}

/// The description: the page's longer copy of the share data's (which
/// sites cut short), else the share data's, else the page's long lines.
String? sharedAdDescription(SharedAd ad) {
  final shared = ad.description?.trim() ?? '';
  final long = [
    for (final line in _pageLines(ad))
      if (line.length > 80) line,
  ];
  if (shared.isNotEmpty) {
    final start = shared
        .substring(0, shared.length < 40 ? shared.length : 40)
        .replaceFirst(RegExp(r'(\.{3}|…)$'), '');
    for (final line in long) {
      if (line.length > shared.length && line.startsWith(start)) return line;
    }
    return shared;
  }
  return long.isEmpty ? null : long.join('\n');
}

/// A denial just before a match: a word up to 20 characters back in the
/// same sentence ("nunca teve acidentes"), or English "no" right before
/// it (Portuguese "no" is "in the").
final _denial = RegExp(
  r'((?<!\w)(sem|nunca|nenhum|nenhuma|não|nao|jamais|livre de|zero|never|without|not)(?!\w)[^.!?\n]{0,20}|(?<!\w)no\s+)$',
  caseSensitive: false,
);

/// Whether [pattern] is in [text] without a denial just before it ("nunca
/// caiu", "sem acidentes").
bool _says(RegExp pattern, String text) => pattern
    .allMatches(text)
    .any((match) => !_denial.hasMatch(text.substring(0, match.start)));

// `\b` knows only ASCII letters ("único", "mão"): the patterns use
// look-arounds for word edges instead.
final _accident = RegExp(
  r'(?<!\w)(acidentes?|sinistrad[oa]|sinistros?|accident|crash(ed)?)(?!\w)',
  caseSensitive: false,
);
final _dropped = RegExp(
  r'(?<!\w)(caiu|queda|quedas|tombo|tombou|deitada ao ch[aã]o|dropped|fell)(?!\w)',
  caseSensitive: false,
);
final _oneOwner = RegExp(
  r'(?<!\w)((único|unico|primeiro|1\.?º|1\.?ª|um só) (dono|propriet[aá]rio)|1 dono|(1|um|uma) s[oó] dono|1ª m[aã]o|primeira m[aã]o|(first|one|single) owner)(?!\w)',
  caseSensitive: false,
);
final _twoOwners = RegExp(
  r'(?<!\w)((2|dois) donos|segundo dono|2ª m[aã]o|segunda m[aã]o|(two|2) owners|second owner)(?!\w)',
  caseSensitive: false,
);
final _manyOwners = RegExp(
  r'(?<!\w)(([3-9]|tr[eê]s|quatro|cinco) donos|terceiro dono|(three|[3-9]) owners)(?!\w)',
  caseSensitive: false,
);
final _noServiceBook = RegExp(
  r'(?<!\w)(sem (o )?livro|no service (book|history))(?!\w)',
  caseSensitive: false,
);
final _serviceBook = RegExp(
  r'(?<!\w)(livro de revis[oõ]es|revis[oõ]es (todas |sempre |feitas )?(na marca|em dia|no concession[aá]rio|carimbad)|service (book|history))',
  caseSensitive: false,
);
final _warranty = RegExp(
  r'(?<!\w)(garantia (de f[aá]brica|da marca|oficial)|em garantia|ainda (tem|com) garantia|factory warranty|under warranty)(?!\w)',
  caseSensitive: false,
);

/// What [text] says of the bike: owners, service book, factory warranty,
/// an accident or a fall (none of them denied).
BikeCondition sharedAdCondition(String text) => BikeCondition(
  damage: _says(_accident, text)
      ? BikeDamage.accident
      : _says(_dropped, text)
      ? BikeDamage.dropped
      : BikeDamage.none,
  owners: _says(_manyOwners, text)
      ? BikeOwners.threeOrMore
      : _says(_twoOwners, text)
      ? BikeOwners.two
      : _says(_oneOwner, text)
      ? BikeOwners.one
      : BikeOwners.unknown,
  serviceBook: _noServiceBook.hasMatch(text)
      ? BikeServiceBook.no
      : _says(_serviceBook, text)
      ? BikeServiceBook.yes
      : BikeServiceBook.unknown,
  warranty: _says(_warranty, text),
);

/// The words of [title] (lower case, letters and digits), as a link's.
List<String> sharedAdWords(String? title) => [
  for (final word in (title ?? '').toLowerCase().split(RegExp('[^a-z0-9]+')))
    if (word.isNotEmpty) word,
];

/// Everything the form takes from [ad].
SharedAdFacts sharedAdFacts(SharedAd ad, {required DateTime now}) {
  final price = sharedAdPrice(ad);
  final description = sharedAdDescription(ad);
  return (
    price: price,
    initialPrice: sharedAdInitialPrice(ad, price),
    year: sharedAdYear(ad, now: now),
    mileage: sharedAdMileage(ad),
    daysListed: sharedAdDaysListed(ad),
    description: description,
    condition: sharedAdCondition([?description, ..._shortLines(ad)].join('\n')),
    words: sharedAdWords(ad.title),
  );
}

/// The site the ad is on ("facebook.com"), for the inbox's line.
String sharedAdSite(SharedAd ad) =>
    (Uri.tryParse(ad.url)?.host ?? '').replaceFirst(RegExp(r'^(www|m)\.'), '');

/// The inbox's name for [ad]: its title, else its site.
String sharedAdName(SharedAd ad) => switch (ad.title?.trim()) {
  final title? when title.isNotEmpty => title,
  _ => sharedAdSite(ad),
};
