// Parsing of the free-text fields of the filters sheet. A blank or
// unreadable field means "no filter" (null).

int? parseWholeNumberField(String text) => int.tryParse(text.trim());

/// Accepts a comma as the decimal separator ("7500,5").
double? parsePriceField(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

String? parseTextField(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}
