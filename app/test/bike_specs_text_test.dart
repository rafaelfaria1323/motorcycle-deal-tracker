import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_maintenance.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_specs.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/bike_specs_text.dart';

void main() {
  test('the seat height against the rider\'s inside leg', () {
    // 178 cm: an inside leg of about 837 mm.
    expect(seatReach(805, 178), SeatReach.flatFeet);
    expect(seatReach(836, 178), SeatReach.flatFeet);
    expect(seatReach(880, 178), SeatReach.ballsOfFeet);
    expect(seatReach(920, 178), SeatReach.tiptoes);
    expect(seatReach(930, 178), SeatReach.tooHigh);
    expect(seatReach(null, 178), isNull);
    expect(seatReach(805, null), isNull);
  });

  test('says the reach with the height in metres', () {
    expect(seatReachText(SeatReach.flatFeet, 178), contains('1,78 m'));
    expect(
      seatReachText(SeatReach.tooHigh, 165, language: AppLanguage.english),
      contains('1.65 m'),
    );
  });

  test('a full tank\'s range, rounded down to 10 km', () {
    expect(rangeKm(14, 4.2), 330);
    expect(rangeKm(15.4, 4.4), 350);
    expect(rangeKm(null, 4.2), isNull);
    expect(rangeKm(14, null), isNull);
    expect(rangeKm(14, 0), isNull);
  });

  test('power in kW and metric horsepower', () {
    expect(powerText(54), contains('54 kW'));
    expect(powerText(54), contains('73'));
    expect(powerText(35.5, language: AppLanguage.english), contains('35.5 kW'));
  });

  test('the facts in reading order, only those known', () {
    final facts = specFacts(
      const BikeSpecs(
        powerKw: 54,
        torqueNm: 67.5,
        weightKg: 184,
        seatHeightMm: 805,
        tankLitres: 14,
      ),
      const BikeMaintenance(fuelPer100Km: 4.2),
    );
    expect(facts.map((f) => f.$2).toList(), [
      contains('54 kW'),
      '67,5 Nm',
      contains('184 kg'),
      '805 mm',
      '14 l',
      '4,2 l/100 km',
      contains('330 km'),
    ]);
    expect(specFacts(null, null), isEmpty);
    expect(
      specFacts(const BikeSpecs(seatHeightMm: 780), null).map((f) => f.$2),
      ['780 mm'],
    );
    final english = specFacts(
      const BikeSpecs(tankLitres: 15.4),
      null,
      language: AppLanguage.english,
    );
    expect(english.single.$2, '15.4 l');
  });

  test('reads the height in cm or metres, within 120-220 cm', () {
    expect(parseRiderHeight('178'), 178);
    expect(parseRiderHeight(' 1,78 '), 178);
    expect(parseRiderHeight('1.78 m'), 178);
    expect(parseRiderHeight('178 cm'), 178);
    expect(parseRiderHeight('100'), isNull);
    expect(parseRiderHeight('2,5'), isNull);
    expect(parseRiderHeight('alto'), isNull);
    expect(parseRiderHeight(''), isNull);
  });
}
