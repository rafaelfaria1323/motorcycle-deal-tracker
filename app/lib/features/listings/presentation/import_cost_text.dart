import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import 'import_cost.dart';

enum ImportLineKind { cost, comparison, vat }

typedef ImportLine = ({ImportLineKind kind, String text});

/// What to say about a bike bought abroad: its cost on the road here, how
/// it compares with the [estimate] of the same bike here (none below the
/// value's minimum of listings) and, for a bike that may count as new,
/// that the VAT is then paid here.
List<ImportLine> importCostLines(
  ImportCost cost, {
  required double? estimate,
  required int year,
  required int? mileage,
  required DateTime now,
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
        final here when here >= cost.total => messages.importCostCheaper(
          estimate: price(here),
          saving: price(here - cost.total),
          percent: Formatters.percent(
            (here - cost.total) / here * 100,
            language: language,
          ),
        ),
        final here => messages.importCostDearer(
          estimate: price(here),
          extra: price(cost.total - here),
        ),
      },
    ),
    if (mayBeNewForVat(year: year, mileage: mileage, now: now))
      (kind: ImportLineKind.vat, text: messages.importCostVat),
  ];
}

/// The card's footnote: where the amounts come from.
String importCostNote({AppLanguage language = AppLanguage.portuguese}) =>
    language.messages.importCostNote(
      legalisation: Formatters.price(
        importInspection + importRegistration + importPlates,
        language: language,
      ),
      year: isvTableYear.toString(),
    );
