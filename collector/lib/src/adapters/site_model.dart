import 'json_values.dart';

/// One brand and model a site offers in its search filters ("Honda",
/// "Forza"), with the site's own ids, which go into search addresses.
/// Stored in `site_models` for the app's model picker.
class const SiteModel({
  required final String makeId,
  required final String makeName,
  required final String modelId,
  required final String modelName,

  /// How many ads the site has for the model, when it says (OLX doesn't).
  final int? ads,
}) {
  Map<String, Object?> toRow(String source) => {
    'source': source,
    'make_id': makeId,
    'make_name': makeName,
    'model_id': modelId,
    'model_name': modelName,
    'ads': ads,
  };
}

/// One entry per brand and model: every page of a site repeats the lists.
List<SiteModel> uniqueSiteModels(Iterable<SiteModel> models) =>
    {for (final m in models) (m.makeId, m.modelId): m}.values.toList();

/// The brands and models in a Standvirtual search page's filters (the
/// `filters` payload of `__NEXT_DATA__`): the brand list, and one model
/// list per brand. Empty when the page has none.
List<SiteModel> standvirtualSiteModels(Map<String, dynamic> filters) {
  final states = filters['states'];
  if (states is! List) return const [];

  List<Map<String, dynamic>> values(Map<String, dynamic> state) => [
    for (final group in asList(state['values']))
      for (final value in asList(asMap(group)?['values'])) ?asMap(value),
  ];
  String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  final makeNames = <String, String>{};
  final modelStates = <(String, Map<String, dynamic>)>[];
  for (final state in states.map(asMap).nonNulls) {
    switch (state['filterId']) {
      case 'filter_enum_make':
        for (final v in values(state)) {
          if ((text(v['id']), text(v['name'])) case (final id?, final name?)) {
            makeNames[id] = name;
          }
        }
      case 'filter_enum_model':
        for (final c in asList(state['conditions']).map(asMap).nonNulls) {
          if (c['filterId'] == 'filter_enum_make' && text(c['value']) != null) {
            modelStates.add((text(c['value'])!, state));
          }
        }
    }
  }

  return [
    for (final (makeId, state) in modelStates)
      if (makeNames[makeId] case final makeName?)
        for (final v in values(state))
          if ((text(v['id']), text(v['name'])) case (final id?, final name?))
            SiteModel(
              makeId: makeId,
              makeName: makeName,
              modelId: id,
              modelName: name,
              ads: asInt(v['counter']),
            ),
  ];
}

/// The models of the brand an OLX search page is for (its "Modelo"
/// filter); OLX lists only that brand's. Empty when the page is not for
/// one brand.
List<SiteModel> olxSiteModels(Map<String, dynamic> listing, String? makeId) {
  if (makeId == null) return const [];
  final filters = asList(asMap(listing['metaData'])?['filters']);
  final modelo = filters
      .map(asMap)
      .nonNulls
      .where((f) => f['name'] == 'filter_enum_modelo')
      .firstOrNull;
  if (modelo == null) return const [];
  return [
    for (final v in asList(modelo['values']).map(asMap).nonNulls)
      if ((v['value'], v['label']) case (final String id, final String label)
          when id.trim().isNotEmpty && label.trim().isNotEmpty)
        SiteModel(
          makeId: makeId,
          makeName: makeId,
          modelId: id.trim(),
          modelName: label.trim(),
        ),
  ];
}
