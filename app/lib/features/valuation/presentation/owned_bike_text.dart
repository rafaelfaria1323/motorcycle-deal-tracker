import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/bike_value.dart';
import '../domain/entities/owned_bike.dart';
import 'ownership_cost.dart';

/// Odometer readings are estimates: rounded to this.
const mileageStep = 100;

/// The bike's mileage today (N.67): the km at purchase plus the owner's
/// km a year (Mais' cost of ownership figures) for the time since; null
/// when the km at purchase is unknown.
int? mileageNow(
  OwnedBikeDraft purchase, {
  required int kmPerYear,
  required DateTime today,
}) {
  final start = purchase.mileageAtPurchase;
  if (start == null) return null;
  final bought = DateTime.utc(
    purchase.boughtOn.year,
    purchase.boughtOn.month,
    purchase.boughtOn.day,
  );
  final now = DateTime.utc(today.year, today.month, today.day);
  final days = now.difference(bought).inDays;
  if (days <= 0) return start;
  final km = start + kmPerYear * days / 365.25;
  return (km / mileageStep).round() * mileageStep;
}

/// "Comprada em 12/11/2026 por 5 600 €, com 12 000 km": what is known.
String purchaseText(
  OwnedBikeDraft purchase, {
  AppLanguage language = .portuguese,
}) {
  final strings = language.messages;
  final date = Formatters.date(purchase.boughtOn);
  final paid = purchase.pricePaid;
  final km = purchase.mileageAtPurchase;
  final bought = paid == null
      ? strings.boughtOn(date: date)
      : strings.boughtOnFor(
          date: date,
          price: Formatters.price(paid.toDouble(), language: language),
        );
  return km == null
      ? bought
      : strings.boughtWithMileage(
          bought: bought,
          mileage: Formatters.mileage(km, language: language),
        );
}

/// The bike's value against what was paid; null when either is unknown.
typedef ValueChange = ({double value, double change, double share});

ValueChange? valueChange(BikeValue value, int? pricePaid) {
  final estimate = value.estimate;
  if (estimate == null || pricePaid == null || pricePaid <= 0) return null;
  final change = estimate - pricePaid;
  return (value: estimate, change: change, share: change / pricePaid);
}

/// "Vale hoje cerca de 5 400 €" (from the live ads, as "Quanto vale a
/// minha mota"), or why it can't be told yet.
String valueTodayText(BikeValue value, {AppLanguage language = .portuguese}) {
  final estimate = value.estimate;
  return estimate == null
      ? language.messages.myBikeNoValueYet
      : language.messages.myBikeValueToday(
          price: roughPrice(estimate, language: language),
        );
}

/// "200 € (3,6 %) abaixo do que pagou"; "Mais ou menos o que pagou"
/// within 1 %.
String valueChangeText(ValueChange c, {AppLanguage language = .portuguese}) {
  final strings = language.messages;
  if (c.share.abs() < 0.01) return strings.myBikeAboutWhatYouPaid;
  final amount = roughPrice(c.change.abs(), language: language);
  final percent = Formatters.percent(
    c.share.abs() * 100,
    decimals: 1,
    language: language,
  );
  return c.change < 0
      ? strings.myBikeBelowWhatYouPaid(amount: amount, percent: percent)
      : strings.myBikeAboveWhatYouPaid(amount: amount, percent: percent);
}

/// What the maker's schedule asks for by the odometer.
enum MaintenanceKind { service, valveCheck }

typedef MaintenanceDue = ({
  MaintenanceKind kind,
  int atKm,
  int inKm,
  double cost,
});

/// The next service and valve check after [mileage] (the model's own
/// intervals, else its engine size's: [runningCostsFor]), soonest first.
/// A reading right on an interval counts as due now (0 km left).
List<MaintenanceDue> nextMaintenance(int mileage, RunningCostTable table) {
  MaintenanceDue next(MaintenanceKind kind, int every, double cost) {
    final atKm = mileage % every == 0
        ? mileage
        : (mileage ~/ every + 1) * every;
    return (kind: kind, atKm: atKm, inKm: atKm - mileage, cost: cost);
  }

  return [
    next(.service, table.serviceIntervalKm, table.service),
    next(.valveCheck, table.valveCheckKm, table.valveCheck),
  ]..sort((a, b) => a.inKm.compareTo(b.inKm));
}

/// "Revisão aos 20 000 km (faltam 6 700 km): cerca de 180 €".
String maintenanceText(
  MaintenanceDue due, {
  AppLanguage language = .portuguese,
}) {
  final strings = language.messages;
  final name = switch (due.kind) {
    MaintenanceKind.service => strings.myBikeService,
    MaintenanceKind.valveCheck => strings.myBikeValveCheck,
  };
  final cost = roughPrice(due.cost, language: language);
  final at = Formatters.mileage(due.atKm, language: language);
  return due.inKm == 0
      ? strings.myBikeMaintenanceDueNow(name: name, at: at, cost: cost)
      : strings.myBikeMaintenanceAt(
          name: name,
          at: at,
          left: Formatters.mileage(due.inKm, language: language),
          cost: cost,
        );
}

/// A whole number as typed, thousands separators (spaces, dots) allowed;
/// null when blank; -1 when it is not a number.
int? _wholeNumber(String text) {
  final digits = text.replaceAll(RegExp(r'[\s.]'), '');
  if (digits.isEmpty) return null;
  return RegExp(r'^\d+$').hasMatch(digits) ? int.parse(digits) : -1;
}

/// The bike as typed in the purchase form, within the database's limits
/// (`owned_bikes`); null when something is out of them. The year is
/// required; the price and the km may stay blank.
OwnedBikeDraft? parseOwnedBike({
  required String motorcycleId,
  required String year,
  required String price,
  required String mileage,
  required DateTime boughtOn,
  String? listingId,
}) {
  final y = _wholeNumber(year);
  final p = _wholeNumber(price);
  final km = _wholeNumber(mileage);
  if (y == null || y < 1950 || y > boughtOn.year + 1) return null;
  if (p != null && (p < 0 || p > 200000)) return null;
  if (km != null && (km < 0 || km > 500000)) return null;
  return OwnedBikeDraft(
    motorcycleId: motorcycleId,
    listingId: listingId,
    year: y,
    pricePaid: p,
    mileageAtPurchase: km,
    boughtOn: DateTime(boughtOn.year, boughtOn.month, boughtOn.day),
  );
}
