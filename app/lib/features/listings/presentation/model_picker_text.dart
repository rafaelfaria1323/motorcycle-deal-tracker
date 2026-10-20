import '../domain/entities/site_model.dart';
import 'tracked_models_text.dart';

/// Brands with the most ads first, then by name.
List<SiteMake> sortedMakes(List<SiteMake> makes) => [...makes]
  ..sort((a, b) {
    final ads = b.ads.compareTo(a.ads);
    return ads != 0 ? ads : a.name.compareTo(b.name);
  });

/// Standvirtual's models of a brand (it lists them all), most ads first.
List<SiteModel> pickerModels(List<SiteModel> models) =>
    [
      for (final m in models)
        if (m.source == 'standvirtual') m,
    ]..sort((a, b) {
      final ads = (b.ads ?? 0).compareTo(a.ads ?? 0);
      return ads != 0 ? ads : a.name.compareTo(b.name);
    });

/// "Forza (32 anúncios)".
String adsLabel(String name, int? ads) => switch (ads) {
  null => name,
  1 => '$name (1 anúncio)',
  _ => '$name ($ads anúncios)',
};

/// Reads the optional engine size ("350", "350 cc"); empty means every
/// size.
({int? cc, String? error}) parseEngineCc(String text) {
  final cleaned = text.toLowerCase().replaceAll(RegExp(r'\s|cc'), '');
  if (cleaned.isEmpty) return (cc: null, error: null);
  final cc = int.tryParse(cleaned);
  if (cc == null || cc < 50 || cc > 2500) {
    return (cc: null, error: 'Cilindrada entre 50 e 2500 cc');
  }
  return (cc: cc, error: null);
}

/// The engine sizes that count as [cc]: sites and sellers round (the
/// Forza 350 has 330 cc), so 10 % either way.
({int min, int max}) engineRange(int cc) =>
    (min: (cc * 0.9).round(), max: (cc * 1.1).round());

/// The catalog name: the site's model, plus the engine size when one is
/// given and the name doesn't already say it ("Forza" + 350 -> "Forza 350").
String pickedModelName(String name, int? cc) {
  final trimmed = name.trim();
  if (cc == null || RegExp('(^|[^0-9])$cc(\$|[^0-9])').hasMatch(trimmed)) {
    return trimmed;
  }
  return '$trimmed $cc';
}

/// The Standvirtual search of a model; with an engine size, only ads that
/// mention it ("…/honda/forza/q-350").
String standvirtualSearchFor(String makeId, String modelId, int? cc) =>
    '$standvirtualSearchPrefix${Uri.encodeComponent(makeId)}/'
    '${Uri.encodeComponent(modelId)}${cc == null ? '' : '/q-$cc'}';

/// The same model in OLX's own list (OLX's ids differ for some models, so
/// the name counts too); null when OLX's list for the brand is unknown or
/// lacks it.
SiteModel? olxModelFor(List<SiteModel> models, SiteModel picked) {
  String key(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  final olx = [
    for (final m in models)
      if (m.source == 'olx' && m.makeId == picked.makeId) m,
  ];
  return olx.where((m) => m.id == picked.id).firstOrNull ??
      olx.where((m) => key(m.name) == key(picked.name)).firstOrNull;
}

/// The OLX search of a model (the collector adds the year).
String olxSearchFor(String makeId, String modelId) =>
    '$olxSearchPrefix${Uri.encodeComponent(makeId)}/'
    '?search%5Bfilter_enum_modelo%5D%5B0%5D=${Uri.encodeQueryComponent(modelId)}';
