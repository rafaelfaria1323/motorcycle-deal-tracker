import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/bike_maintenance.dart';
import '../domain/entities/bike_specs.dart';
import 'listing_detail_text.dart';

/// Metric horsepower (PS, "cv") in one kW.
const psPerKw = 1.35962;

/// The inside leg as a share of a person's height: an average adult's,
/// used to estimate the reach to the ground from the height alone.
const insideLegShare = 0.47;

/// How far the feet reach the ground at a standstill, from the seat height
/// against the rider's estimated inside leg ([seatReach]).
enum SeatReach { flatFeet, ballsOfFeet, tiptoes, tooHigh }

/// The reach to the ground of a rider [heightCm] tall on a seat
/// [seatHeightMm] high: both feet flat when the seat is no higher than
/// the inside leg, the balls of the feet up to 50 mm above it, tiptoes up
/// to 90 mm, else too high. Null when either is unknown.
SeatReach? seatReach(int? seatHeightMm, int? heightCm) {
  if (seatHeightMm == null || heightCm == null) return null;
  final gap = seatHeightMm - heightCm * 10 * insideLegShare;
  if (gap <= 0) return SeatReach.flatFeet;
  if (gap <= 50) return SeatReach.ballsOfFeet;
  if (gap <= 90) return SeatReach.tiptoes;
  return SeatReach.tooHigh;
}

/// "Com 1,78 m, deve apoiar os dois pés por inteiro no chão."
String seatReachText(
  SeatReach reach,
  int heightCm, {
  AppLanguage language = .portuguese,
}) {
  final height =
      '${Formatters.decimal(heightCm / 100, decimals: 2, language: language)} m';
  final m = language.messages;
  return switch (reach) {
    .flatFeet => m.seatFitFlat(height: height),
    .ballsOfFeet => m.seatFitBalls(height: height),
    .tiptoes => m.seatFitToes(height: height),
    .tooHigh => m.seatFitTooHigh(height: height),
  };
}

/// A full tank's km at the maker's consumption, rounded down to 10 km;
/// null when either is unknown.
int? rangeKm(double? tankLitres, double? litresPer100Km) {
  if (tankLitres == null || litresPer100Km == null || litresPer100Km <= 0) {
    return null;
  }
  return (tankLitres / litresPer100Km * 100) ~/ 10 * 10;
}

/// "54 kW (73 cv)".
String powerText(double kw, {AppLanguage language = .portuguese}) =>
    language.messages.specPowerValue(
      kw: Formatters.decimal(
        kw,
        decimals: kw % 1 == 0 ? 0 : 1,
        language: language,
      ),
      hp: (kw * psPerKw).round(),
    );

String _litres(double litres, AppLanguage language) =>
    '${Formatters.decimal(litres, decimals: litres % 1 == 0 ? 0 : 1, language: language)} l';

/// "Ficha técnica": what the model's figures hold, in reading order; empty
/// when the catalog has none of them.
List<Fact> specFacts(
  BikeSpecs? specs,
  BikeMaintenance? maintenance, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final consumption = maintenance?.fuelPer100Km;
  final range = rangeKm(specs?.tankLitres, consumption);
  return [
    if (specs?.powerKw case final kw?)
      (m.specPower, powerText(kw, language: language)),
    if (specs?.torqueNm case final nm?)
      (
        m.specTorque,
        '${Formatters.decimal(nm, decimals: nm % 1 == 0 ? 0 : 1, language: language)} Nm',
      ),
    if (specs?.weightKg case final kg?)
      (m.specWeight, m.specWeightValue(kg: kg)),
    if (specs?.seatHeightMm case final mm?) (m.specSeatHeight, '$mm mm'),
    if (specs?.tankLitres case final tank?)
      (m.specTank, _litres(tank, language)),
    if (consumption != null)
      (
        m.specConsumption,
        '${Formatters.decimal(consumption, language: language)} l/100 km',
      ),
    if (range != null)
      (
        m.specRange,
        m.specRangeValue(km: Formatters.mileage(range, language: language)),
      ),
  ];
}

/// The height typed in the dialog ("178", "1,78", "1.78 m") in whole cm;
/// null unless it is 120-220 cm (the database's limits).
int? parseRiderHeight(String text) {
  final cleaned = text.trim().toLowerCase().replaceAll(RegExp(r'\s|cm|m$'), '');
  final value = double.tryParse(cleaned.replaceAll(',', '.'));
  if (value == null) return null;
  final cm = (value < 3 ? value * 100 : value).round();
  return cm >= 120 && cm <= 220 ? cm : null;
}
