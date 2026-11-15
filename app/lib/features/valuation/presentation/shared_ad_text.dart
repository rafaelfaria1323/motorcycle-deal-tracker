/// "Avaliar um anúncio" (N.110): what an ad the iPhone shortcut sent says,
/// read from the lines the script kept (price, year, km, how long it has
/// been up), its title and its description, to fill the typed ad's form.
/// The rules live here, not in the database, so they can change with the
/// app; nothing read here is ever fetched from the site.
library;

import '../../listings/domain/entities/listing.dart' show minRealPrice;
import '../domain/entities/shared_ad.dart';
import 'typed_ad_history.dart' show maxTypedAdDays;

/// What the form takes from a shared ad; each fact may be unknown.
typedef SharedAdFacts = ({
  double? price,
  int? year,
  int? mileage,
  int? daysListed,
  String? description,

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
  r'\b(ano|year|registo|matr[ií]cula|modelo)\b',
  caseSensitive: false,
);

final _mileageLabelled = RegExp(
  '(?:conduzid[oa]|driven|quil[oó]metros|quilometragem|mileage|kms?)'
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
  for (final line in ad.lines) {
    if (_priceIn(line) case final value?) return value;
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
  for (final line in ad.lines) {
    if (!_yearLabel.hasMatch(line)) continue;
    if (yearIn(line) case final year?) return year;
  }
  return null;
}

/// The mileage: a line that says it ("Conduzido 25 000 km", "Km: 7.500"),
/// else a line that is only that ("25 000 km"), else the first km in a
/// line or the title. A distance from the person ("a 5 km") is no mileage.
int? sharedAdMileage(SharedAd ad) {
  for (final line in ad.lines) {
    if (_mileageLabelled.firstMatch(line) case final match?) {
      return _digits(match.group(1)!);
    }
  }
  for (final line in ad.lines) {
    if (_mileageAlone.firstMatch(line) case final match?) {
      return _digits(match.group(1)!);
    }
  }
  for (final text in [...ad.lines, ?ad.title]) {
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
  for (final line in ad.lines) {
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

/// The words of [title] (lower case, letters and digits), as a link's.
List<String> sharedAdWords(String? title) => [
  for (final word in (title ?? '').toLowerCase().split(RegExp('[^a-z0-9]+')))
    if (word.isNotEmpty) word,
];

/// Everything the form takes from [ad].
SharedAdFacts sharedAdFacts(SharedAd ad, {required DateTime now}) => (
  price: sharedAdPrice(ad),
  year: sharedAdYear(ad, now: now),
  mileage: sharedAdMileage(ad),
  daysListed: sharedAdDaysListed(ad),
  description: switch (ad.description?.trim()) {
    final text? when text.isNotEmpty => text,
    _ => null,
  },
  words: sharedAdWords(ad.title),
);

/// The site the ad is on ("facebook.com"), for the inbox's line.
String sharedAdSite(SharedAd ad) =>
    (Uri.tryParse(ad.url)?.host ?? '').replaceFirst(RegExp(r'^(www|m)\.'), '');

/// The inbox's name for [ad]: its title, else its site.
String sharedAdName(SharedAd ad) => switch (ad.title?.trim()) {
  final title? when title.isNotEmpty => title,
  _ => sharedAdSite(ad),
};
