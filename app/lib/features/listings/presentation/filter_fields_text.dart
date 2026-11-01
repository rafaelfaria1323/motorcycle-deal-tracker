// Parsing of the number fields of the filters sheet. A blank or
// unreadable field means "no filter" (null).

int? parseWholeNumberField(String text) => int.tryParse(text.trim());

/// Accepts a comma as the decimal separator ("7500,5").
double? parsePriceField(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
