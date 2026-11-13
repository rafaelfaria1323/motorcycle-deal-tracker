import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/vehicle_recall.dart';

/// One recall as the page shows it (N.86): the product's name, what it
/// can do (the Commission's words in the person's language, else in
/// English), the facts on one line and the alert to open.
class const RecallLine({
  required final String title,
  required final String? danger,
  required final String facts,
  required final Uri? link,
});

/// The recalls of [recalls] that [applying] says (those that can cover
/// the bike's year, or the model's others), newest first as given.
List<RecallLine> recallLines(
  List<VehicleRecall> recalls, {
  required bool applying,
  AppLanguage language = .portuguese,
}) => [
  for (final recall in recalls)
    if (recall.applies == applying) recallLine(recall, language: language),
];

/// "Produção: 2019-2021 · Código 23-123 · Itália, 12/03/2024".
RecallLine recallLine(
  VehicleRecall recall, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final portuguese = language == .portuguese;
  final country =
      _text(portuguese ? recall.countryPt : recall.countryEn) ??
      _text(recall.countryEn);
  final published = Formatters.date(recall.publishedOn);
  final link = Uri.tryParse(recall.alertUrl);
  return RecallLine(
    title: _text(recall.name) ?? m.recallUnnamed,
    danger:
        _text(portuguese ? recall.dangerPt : recall.dangerEn) ??
        _text(recall.dangerEn),
    facts: [
      if (_text(recall.productionDates) case final dates?)
        m.recallProduction(dates: dates),
      if (_text(recall.recallCode) case final code?) m.recallCode(code: code),
      if (country == null) published else '$country, $published',
    ].join(' · '),
    link: link != null && link.scheme == 'https' ? link : null,
  );
}

/// The checklist item's title and hint for a recall that can cover the
/// bike: "Recolha 23-123 feita?" (or the alert's date without a code).
({String title, String hint}) recallChecklistText(
  VehicleRecall recall, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final code = _text(recall.recallCode) ?? Formatters.date(recall.publishedOn);
  final danger = recallLine(recall, language: language).danger;
  return (
    title: m.checklistRecall(code: code),
    hint: danger == null
        ? m.checklistRecallHint
        : '$danger ${m.checklistRecallHint}',
  );
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
