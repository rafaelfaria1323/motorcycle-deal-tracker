import '../domain/place.dart';

const _accents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _plain = 'aaaaaeeeeiiiiooooouuuucn';
final _accentRunes = _accents.runes.toList();

/// The database's `place_key`: lower case, no accents, no "(parish)",
/// nothing after a comma, hyphens and dots as spaces. Keep the two equal.
String placeKey(String name) {
  var s = name.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ');
  s = s.split(',').first;
  s = String.fromCharCodes(
    s.runes.map((r) {
      final i = _accentRunes.indexOf(r);
      return i < 0 ? r : _plain.codeUnitAt(i);
    }),
  );
  return s
      .replaceAll(RegExp(r"[-'.]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Search results without repeats: district names and spellings point to
/// the same town ("Madeira" and "Funchal" are both Funchal), so one entry
/// per name, the name's own key first. Shortest names first (the exact
/// town before longer ones that start the same), then alphabetical.
List<Place> uniquePlaces(List<Place> places) {
  final byName = <String, Place>{};
  for (final p in places) {
    final current = byName[p.name];
    if (current == null || placeKey(p.name) == p.key) byName[p.name] = p;
  }
  return byName.values.toList()..sort(
    (a, b) => a.name.length != b.name.length
        ? a.name.length.compareTo(b.name.length)
        : a.name.compareTo(b.name),
  );
}
