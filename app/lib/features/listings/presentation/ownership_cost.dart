import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/market_behaviour.dart';
import '../domain/entities/ownership_settings.dart';
import '../../../core/localization/localizations.dart';

/// IUC, category E (motorcycles), registered after 1996, euros per year by
/// engine size (Código do IUC; the 2024 values, kept in 2025 and 2026).
/// The State Budget can change them every January: check and update
/// [iucTableYear] with them.
const iucTableYear = 2026;
const iucBands = <({int? maxCc, double euros})>[
  (maxCc: 119, euros: 0),
  (maxCc: 250, euros: 6.19),
  (maxCc: 350, euros: 8.76),
  (maxCc: 500, euros: 21.18),
  (maxCc: 750, euros: 63.62),
  (maxCc: null, euros: 138.15),
];

/// Under this the tax is not charged at all.
const iucMinimumCharged = 10.0;

/// Registrations before this year use an older column (not kept here).
const iucFirstYear = 1997;

/// The IUC to pay per year; 0 under the minimum charged; null when the
/// engine size is unknown or the bike was registered before 1997.
double? iucPerYear({int? engineCc, int? year}) {
  if (engineCc == null) return null;
  if (year != null && year < iucFirstYear) return null;
  final band = iucBands.firstWhere(
    (b) => b.maxCc == null || engineCc <= b.maxCc!,
  );
  return band.euros < iucMinimumCharged ? 0 : band.euros;
}

/// Typical workshop prices (parts and labour, 2026) by engine size.
class RunningCostTable {
  const RunningCostTable({
    required this.tyreSet,
    required this.tyreLifeKm,
    required this.service,
    required this.serviceIntervalKm,
    required this.chainKit,
    required this.chainLifeKm,
  });

  final double tyreSet;
  final int tyreLifeKm;
  final double service;
  final int serviceIntervalKm;
  final double chainKit;
  final int chainLifeKm;
}

/// Up to 400 cc (CB125R, R3, CB300R).
const smallBikeCosts = RunningCostTable(
  tyreSet: 200,
  tyreLifeKm: 12000,
  service: 130,
  serviceIntervalKm: 6000,
  chainKit: 140,
  chainLifeKm: 20000,
);

/// 401 to 800 cc (MT-07, R7, CB650R, CBR500R...); also when the engine
/// size is unknown.
const middleBikeCosts = RunningCostTable(
  tyreSet: 300,
  tyreLifeKm: 10000,
  service: 180,
  serviceIntervalKm: 10000,
  chainKit: 200,
  chainLifeKm: 20000,
);

/// Over 800 cc (R1, R9): softer, wider tyres wear faster.
const largeBikeCosts = RunningCostTable(
  tyreSet: 380,
  tyreLifeKm: 8000,
  service: 250,
  serviceIntervalKm: 10000,
  chainKit: 260,
  chainLifeKm: 20000,
);

RunningCostTable runningCostsFor(int? engineCc) => switch (engineCc) {
  null => middleBikeCosts,
  <= 400 => smallBikeCosts,
  <= 800 => middleBikeCosts,
  _ => largeBikeCosts,
};

/// Tyres age out even when little used: at least one set in this many years.
const tyreMaxYears = 5;

/// The general rates of `model_depreciation` (for a listing without a
/// matched model): 4 % a year and the buyer's minimum 0.5 % per 1000 km.
const generalDepreciation = Depreciation(
  sampleCount: 0,
  isFitted: false,
  perYear: 0.04,
  per1000Km: 0.005,
);

/// What a bike costs per year, in euros. Running costs are the same every
/// year; depreciation is the average over the years kept.
class OwnershipCost {
  const OwnershipCost({
    required this.iuc,
    required this.insurance,
    required this.tyres,
    required this.services,
    required this.chain,
    required this.depreciation,
    required this.years,
    required this.kmPerYear,
    required this.table,
  });

  /// Null when it can't be worked out (unknown engine size, old bike).
  final double? iuc;

  /// Null until the owner enters their quote.
  final double? insurance;
  final double tyres;
  final double services;
  final double chain;
  final double depreciation;
  final int years;
  final int kmPerYear;
  final RunningCostTable table;

  double get perYear =>
      (iuc ?? 0) + (insurance ?? 0) + tyres + services + chain + depreciation;

  double get total => perYear * years;
}

/// The yearly cost of keeping a bike bought at [price]; null without one.
OwnershipCost? ownershipCost({
  required double? price,
  required OwnershipSettings settings,
  int? engineCc,
  int? year,
  Depreciation? depreciation,
}) {
  if (price == null || price <= 0) return null;
  final km = settings.kmPerYear;
  final years = settings.yearsToKeep;
  final table = runningCostsFor(engineCc);
  final rates = depreciation ?? generalDepreciation;

  // Same curve as the fair price: value falls by exp(-rate) per year of age
  // and per 1000 km.
  final yearlyRate = rates.perYear + rates.per1000Km * km / 1000;
  final lost = price * (1 - exp(-yearlyRate * years));

  return OwnershipCost(
    iuc: iucPerYear(engineCc: engineCc, year: year),
    insurance: settings.insurancePerYear?.toDouble(),
    tyres: table.tyreSet * max(km / table.tyreLifeKm, 1 / tyreMaxYears),
    // At least one service a year, however little it is ridden.
    services: table.service * max(km / table.serviceIntervalKm, 1),
    chain: table.chainKit * km / table.chainLifeKm,
    depreciation: lost / years,
    years: years,
    kmPerYear: km,
    table: table,
  );
}

/// Rounded to 10 € for headlines: these are estimates.
String roughPrice(
  double value, {
  AppLanguage language = AppLanguage.portuguese,
}) => Formatters.price((value / 10).round() * 10.0, language: language);

/// "Custa cerca de 1 450 € por ano".
String ownershipHeadline(
  OwnershipCost c, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.costsAboutPerYear(
  value: roughPrice(c.perYear, language: language),
);

/// "Em 3 anos: cerca de 4 350 €".
String ownershipTotalLine(
  OwnershipCost c, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.overAbout(
  years: c.years.toString(),
  value: c.years == 1
      ? language.messages.yearOwnershipCost
      : language.messages.years,
  value3: roughPrice(c.total, language: language),
);

/// One line per part of the cost, in the order they are added up.
List<String> ownershipLines(
  OwnershipCost c, {
  int? year,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final t = c.table;
  String km(int value) => Formatters.mileage(value, language: language);
  return [
    language.messages.depreciationPerYearAverageOver(
      value: roughPrice(c.depreciation, language: language),
      years: c.years.toString(),
      value3: c.years == 1
          ? language.messages.yearOwnershipCost
          : language.messages.years,
    ),
    switch (c.iuc) {
      null when year != null && year < iucFirstYear =>
        language.messages.roadTaxIUCNotCalculatedForRegistrationsBefore(
          iucFirstYear: (iucFirstYear).toString(),
        ),
      null => language.messages.roadTaxIUCModelEngineSizeUnknown,
      0.0 => language.messages.roadTaxIUCExemptLessThanEUR10,
      final iuc => language.messages.roadTaxIUC(
        price: Formatters.price(iuc, language: language),
      ),
    },
    c.insurance == null
        ? language.messages.insuranceNotIncludedEnterYourInsurancePremium
        : language.messages.insuranceYourFigure(
            price: Formatters.price(c.insurance, language: language),
          ),
    language.messages.tyresSetEveryAtLeastEveryYears(
      price: Formatters.price(c.tyres, language: language),
      value: km(t.tyreLifeKm),
      tyreMaxYears: (tyreMaxYears).toString(),
    ),
    language.messages.servicingEveryAtLeastOnceYear(
      price: Formatters.price(c.services, language: language),
      value: km(t.serviceIntervalKm),
    ),
    language.messages.chainAndSprocketKitEvery(
      price: Formatters.price(c.chain, language: language),
      value: km(t.chainLifeKm),
    ),
  ];
}

/// What the estimate assumes, under the lines.
String ownershipFootnote(
  OwnershipCost c, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.atPerYearTypicalWorkshopPricesAndRoad(
  mileage: Formatters.mileage(c.kmPerYear, language: language),
  iucTableYear: (iucTableYear).toString(),
);

/// The settings typed in the dialog, within the database's limits; null
/// when one is not a whole number in range. An empty insurance clears it.
OwnershipSettings? parseOwnershipSettings({
  required String insurance,
  required String kmPerYear,
  required String yearsToKeep,
}) {
  int? whole(String text) =>
      int.tryParse(text.trim().replaceAll(RegExp(r'[\s.€]'), ''));
  final km = whole(kmPerYear);
  final years = whole(yearsToKeep);
  final insuranceText = insurance.trim();
  final euros = insuranceText.isEmpty ? null : whole(insuranceText);
  if (km == null || km < 0 || km > 100000) return null;
  if (years == null || years < 1 || years > 15) return null;
  if (insuranceText.isNotEmpty &&
      (euros == null || euros < 0 || euros > 20000)) {
    return null;
  }
  return OwnershipSettings(
    insurancePerYear: euros,
    kmPerYear: km,
    yearsToKeep: years,
  );
}
