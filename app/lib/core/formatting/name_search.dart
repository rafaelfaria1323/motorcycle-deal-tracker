/// Ordering and searching names typed or picked by people (brands,
/// models), as they would read them.
library;

/// Names in alphabetical order, case and accents aside; the ids break ties.
int compareNames(String a, String aId, String b, String bId) {
  final name = _folded(a).compareTo(_folded(b));
  return name != 0 ? name : aId.compareTo(bId);
}

/// Lower case without the accents a brand or model may carry.
String _folded(String text) {
  const accented = 'áàâãäåéèêëíìîïóòôõöøúùûüçñýÿ';
  const plain = 'aaaaaaeeeeiiiioooooouuuucnyy';
  final out = StringBuffer();
  for (final c in text.toLowerCase().split('')) {
    final i = accented.indexOf(c);
    out.write(i < 0 ? c : plain[i]);
  }
  return out.toString();
}

/// Only letters and digits, folded: "MT-07", "mt 07" and "mt07" are one.
String _searchKey(String text) =>
    _folded(text).replaceAll(RegExp('[^a-z0-9]'), '');

/// The items whose name holds what is typed (case, accents,
/// spaces and hyphens aside), in their order; every one for an empty
/// search. Names that start with it come first.
List<T> searchByName<T>(List<T> items, String Function(T) name, String query) {
  final key = _searchKey(query);
  if (key.isEmpty) return items;
  final starts = <T>[];
  final contains = <T>[];
  for (final item in items) {
    final itemKey = _searchKey(name(item));
    if (itemKey.startsWith(key)) {
      starts.add(item);
    } else if (itemKey.contains(key)) {
      contains.add(item);
    }
  }
  return [...starts, ...contains];
}
