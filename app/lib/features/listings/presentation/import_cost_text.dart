import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import 'import_cost.dart';

enum ImportLineKind { cost, comparison, vat }

/// What the cost here is weighed against: the value of the same bike here
/// ("Comprar no estrangeiro") or a listing's asking price (its page).
enum ImportComparison { value, listing }

typedef ImportLine = ({ImportLineKind kind, String text});

/// What to say about a bike bought abroad: its cost on the road here, how
/// it compares with [estimate] (the value of the same bike here, none below
/// the value's minimum of listings, or with [against] a listing's asking
/// price) and, for a bike that may count as new, that the VAT is then paid
/// here (an unknown [year] says nothing of it).
List<ImportLine> importCostLines(
  ImportCost cost, {
  required double? estimate,
  required int? year,
  required int? mileage,
  required DateTime now,
  ImportComparison against = ImportComparison.value,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final messages = language.messages;
  String price(double amount) => Formatters.price(amount, language: language);
  return [
    (
      kind: ImportLineKind.cost,
      text: messages.importCostTotal(
        total: price(cost.total),
        price: price(cost.price),
        isv: price(cost.isv),
        legalisation: price(cost.legalisation),
        transport: price(cost.transport),
      ),
    ),
    (
      kind: ImportLineKind.comparison,
      text: switch (estimate) {
        null => messages.importCostNoEstimate,
        final here when here >= cost.total => _cheaper(
          messages,
          against,
          here: price(here),
          saving: price(here - cost.total),
          percent: Formatters.percent(
            (here - cost.total) / here * 100,
            language: language,
          ),
        ),
        final here => _dearer(
          messages,
          against,
          here: price(here),
          extra: price(cost.total - here),
        ),
      },
    ),
    if (year != null && mayBeNewForVat(year: year, mileage: mileage, now: now))
      (kind: ImportLineKind.vat, text: messages.importCostVat),
  ];
}

String _cheaper(
  AppLocalizations messages,
  ImportComparison against, {
  required String here,
  required String saving,
  required String percent,
}) => switch (against) {
  ImportComparison.value => messages.importCostCheaper(
    estimate: here,
    saving: saving,
    percent: percent,
  ),
  ImportComparison.listing => messages.importCostCheaperThanAd(
    asking: here,
    saving: saving,
    percent: percent,
  ),
};

String _dearer(
  AppLocalizations messages,
  ImportComparison against, {
  required String here,
  required String extra,
}) => switch (against) {
  ImportComparison.value => messages.importCostDearer(
    estimate: here,
    extra: extra,
  ),
  ImportComparison.listing => messages.importCostDearerThanAd(
    asking: here,
    extra: extra,
  ),
};

/// The card's footnote: where the amounts come from.
String importCostNote({AppLanguage language = AppLanguage.portuguese}) =>
    language.messages.importCostNote(
      legalisation: Formatters.price(
        importInspection + importRegistration + importPlates,
        language: language,
      ),
      year: isvTableYear.toString(),
    );
