/// "Avaliar um anúncio" (N.104): the model an ad's link names. Both sites
/// write the ad's title into its address
/// (`…/anuncio/kawasaki-z650-como-nova-IDHk3aB.html`), so its words name
/// the bike, the way the collector reads a title: the model's name in
/// one to three words, also without its closing letters ("cbr-650" is
/// the CBR650R), and only when one model fits. Read from the link alone:
/// no ad page is fetched.
library;

import '../../listings/domain/entities/site_model.dart';
import '../../listings/presentation/model_picker_text.dart';
import 'ad_link.dart';

/// The words of the ad's title in [text]'s ad link (lower case, without
/// the ad's code); empty when it holds no ad link.
List<String> adLinkWords(String text) {
  final link = adLinkOf(text);
  if (link == null) return const [];
  final path = Uri.parse(link).pathSegments;
  final slug = path.last
      .toLowerCase()
      .replaceFirst(RegExp(r'\.html$'), '')
      .replaceFirst(RegExp(r'-id[0-9a-z]+$'), '');
  return [
    for (final word in slug.split(RegExp('[^a-z0-9]+')))
      if (word.isNotEmpty) word,
  ];
}

/// Only letters and digits: "MT-07", "mt 07" and "mt07" are one.
String _key(String text) =>
    text.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Every run of one to three of [words], joined.
Set<String> _windows(List<String> words) => {
  for (var start = 0; start < words.length; start++)
    for (var end = start + 1; end <= start + 3 && end <= words.length; end++)
      words.sublist(start, end).join(),
};

/// The name without its closing letters ("cbr650r" -> "cbr650"), when it
/// ends in letters after a digit; null otherwise.
String? _stem(String key) {
  final match = RegExp(r'^(.*\d)[a-z]+$').firstMatch(key);
  return match?.group(1);
}

/// The one of [models] the link's [words] name, by its [brand] and
/// [model]; null when none or more than one fits. A brand the words name
/// keeps only its models; a model name under three characters ("R7")
/// needs its brand named too.
T? modelInWords<T>(
  List<String> words,
  List<T> models, {
  required String Function(T) brand,
  required String Function(T) model,
}) {
  final windows = _windows(words);
  bool brandNamed(T m) => windows.contains(_key(brand(m)));
  final branded = models.where(brandNamed).toList();
  final candidates = branded.isEmpty ? models : branded;

  List<T> fitting(bool Function(String key) fits) => [
    for (final m in candidates)
      if (_key(model(m)) case final key
          when key.isNotEmpty &&
              (key.length >= 3 || brandNamed(m)) &&
              fits(key))
        m,
  ];

  final exact = fitting(windows.contains);
  if (exact.isNotEmpty) return exact.length == 1 ? exact.single : null;
  final stemmed = fitting((key) {
    final stem = _stem(key);
    return stem != null && windows.contains(stem);
  });
  return stemmed.length == 1 ? stemmed.single : null;
}

/// A model of the sites' lists the link names, with the searches
/// "Outra marca ou modelo…" would make for it.
typedef SiteModelGuess = ({
  String brand,
  String model,
  String standvirtualSearch,
  String? olxSearch,
});

/// The site brand the link's [words] name (the longest, so
/// "harley-davidson" beats a brand "harley"); null when none.
SiteMake? makeInWords(List<String> words, List<SiteMake> makes) {
  final windows = _windows(words);
  SiteMake? best;
  for (final make in makes) {
    final key = _key(make.id);
    if (key.isEmpty) continue;
    if (!windows.contains(key) && !windows.contains(_key(make.name))) {
      continue;
    }
    if (best == null || key.length > _key(best.id).length) best = make;
  }
  return best;
}

/// The model of [make] the link's [words] name, among the brand's site
/// models [models] (Standvirtual's list, as the picker; OLX's for its
/// search); null when none or more than one fits.
SiteModelGuess? siteModelInWords(
  List<String> words,
  SiteMake make,
  List<SiteModel> models,
) {
  final picked = modelInWords(
    words,
    pickerModels(models),
    brand: (_) => make.name,
    model: (m) => m.name,
  );
  if (picked == null) return null;
  final olx = olxModelFor(models, picked);
  return (
    brand: make.name,
    model: pickedModelName(picked.name, null),
    standvirtualSearch: standvirtualSearchFor(make.id, picked.id, null),
    olxSearch: olx == null ? null : olxSearchFor(olx.makeId, olx.id),
  );
}
