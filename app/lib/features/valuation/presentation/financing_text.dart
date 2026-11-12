import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import 'financing.dart';

/// A difference this small between the price and the offer isn't worth a
/// line (the offer's rounding step).
const financingMinSaving = 50.0;

/// What paying [cost] in instalments means: the instalment, the total and
/// what the loan costs; then, when [offer] (the most to pay in "Quanto
/// oferecer") is at least [financingMinSaving] below the price, the same
/// loan at the offer and what it saves.
List<String> financingLines(
  FinancingCost cost, {
  double? offer,
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  String price(double amount) => Formatters.price(amount, language: language);
  if (cost.nothingFinanced) return [messages.financingNothingFinanced];
  return [
    messages.financingMonthly(
      monthly: price(cost.monthly),
      months: cost.months,
    ),
    messages.financingTotal(
      total: price(cost.totalPaid),
      interest: price(cost.interest),
    ),
    if (offer != null && cost.price - offer >= financingMinSaving)
      _atOffer(cost, offer, messages, price),
  ];
}

String _atOffer(
  FinancingCost cost,
  double offer,
  AppLocalizations messages,
  String Function(double) price,
) {
  final atOffer = financingCost(
    price: offer,
    deposit: cost.deposit,
    months: cost.months,
    apr: cost.apr,
  );
  return messages.financingAtOffer(
    offer: price(offer),
    monthly: price(atOffer.monthly),
    total: price(atOffer.totalPaid),
    saving: price(cost.totalPaid - atOffer.totalPaid),
  );
}
