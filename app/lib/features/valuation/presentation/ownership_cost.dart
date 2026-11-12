import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../../listings/domain/entities/bike_maintenance.dart';
import '../../market/domain/entities/market_behaviour.dart';
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

/// Typical workshop prices (parts and labour, 2026) by engine size, or
/// the model's own figures ([runningCostsFor]).
class const RunningCostTable({
  required final double tyreSet,
  required final int tyreLifeKm,
  required final double service,
  required final int serviceIntervalKm,
  required final double chainKit,
  required final int chainLifeKm,

  /// The valve clearance check (and adjustment when needed).
  required final double valveCheck,
  required final int valveCheckKm,

  /// The model's tyre sizes when [tyreSet] was priced from them.
  final String? frontTyre,
  final String? rearTyre,
});

/// Up to 400 cc (CB125R, R3, CB300R).
const smallBikeCosts = RunningCostTable(
  tyreSet: 200,
  tyreLifeKm: 12000,
  service: 130,
  serviceIntervalKm: 6000,
  chainKit: 140,
  chainLifeKm: 20000,
  valveCheck: 180,
  valveCheckKm: 24000,
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
  valveCheck: 350,
  valveCheckKm: 30000,
);

/// Over 800 cc (R1, R9): softer, wider tyres wear faster.
const largeBikeCosts = RunningCostTable(
  tyreSet: 380,
  tyreLifeKm: 8000,
  service: 250,
  serviceIntervalKm: 10000,
  chainKit: 260,
  chainLifeKm: 20000,
  valveCheck: 550,
  valveCheckKm: 30000,
);

/// Sports bikes' tyres: softer compounds cost more and wear sooner.
const sportTyrePriceFactor = 1.15;
const sportTyreLifeFactor = 0.8;

/// One road tyre of a mid-range brand (Michelin Road, Pirelli Angel, Bridgestone
/// T32; Portuguese shops, 2026) by its width in mm, the smallest band that
/// holds it; wider ones cost the last.
const tyrePriceByWidth = <({int maxWidth, double euros})>[
  (maxWidth: 110, euros: 85),
  (maxWidth: 140, euros: 120),
  (maxWidth: 150, euros: 135),
  (maxWidth: 160, euros: 155),
  (maxWidth: 180, euros: 185),
  (maxWidth: 190, euros: 210),
  (maxWidth: 999, euros: 230),
];

/// Fitting and balancing both wheels.
const tyreFitting = 30.0;

/// A service (oil, filter, checks) by the engine's cylinders: more of them,
/// more oil and work. Four or more cost the last.
const serviceByCylinders = <double>[130, 180, 200, 220];

/// A valve clearance check by cylinders: more valves, more hours.
const valveCheckByCylinders = <double>[180, 350, 450, 550];

final _tyreSize = RegExp(r'^(\d{2,3})/\d{2}-\d{2}$');

/// The price of one tyre of [size] ("180/55-17"); null when unreadable.
double? tyrePrice(String? size) {
  final width = int.tryParse(_tyreSize.firstMatch(size ?? '')?.group(1) ?? '');
  if (width == null) return null;
  return tyrePriceByWidth.firstWhere((b) => width <= b.maxWidth).euros;
}

/// The running costs of a bike of [engineCc]: the model's own tyre sizes,
/// cylinders and maker's intervals ([maintenance]) where known, else the
/// engine-size table's. A sports bike's tyres cost more and last less
/// ([isSportBike]).
RunningCostTable runningCostsFor(
  int? engineCc, {
  bool sport = false,
  BikeMaintenance? maintenance,
}) {
  final table = switch (engineCc) {
    null => middleBikeCosts,
    <= 400 => smallBikeCosts,
    <= 800 => middleBikeCosts,
    _ => largeBikeCosts,
  };
  if (!sport && maintenance == null) return table;
  final front = tyrePrice(maintenance?.frontTyre);
  final rear = tyrePrice(maintenance?.rearTyre);
  final sized = front != null && rear != null;
  final tyreSet = sized ? front + rear + tyreFitting : table.tyreSet;
  final cylinders = maintenance?.cylinders;
  double byCylinders(List<double> prices, double fallback) =>
      cylinders == null ? fallback : prices[min(cylinders, prices.length) - 1];
  return RunningCostTable(
    tyreSet: sport ? tyreSet * sportTyrePriceFactor : tyreSet,
    tyreLifeKm: sport
        ? (table.tyreLifeKm * sportTyreLifeFactor).round()
        : table.tyreLifeKm,
    service: byCylinders(serviceByCylinders, table.service),
    serviceIntervalKm:
        maintenance?.serviceIntervalKm ?? table.serviceIntervalKm,
    chainKit: table.chainKit,
    chainLifeKm: table.chainLifeKm,
    valveCheck: byCylinders(valveCheckByCylinders, table.valveCheck),
    valveCheckKm: maintenance?.valveCheckKm ?? table.valveCheckKm,
    frontTyre: sized ? maintenance!.frontTyre : null,
    rearTyre: sized ? maintenance!.rearTyre : null,
  );
}

/// Fully faired sports bikes, which insurers price higher and whose tyres
/// wear sooner: per brand, the start (or end) of the model's name with
/// spaces and dashes removed. Yamaha's R1/R7 and Honda's CBR, but not
/// BMW's R 1250 GS (a tourer).
final _sportModels = <String, RegExp>{
  'yamaha': RegExp(r'^(r\d|yzf)'),
  'honda': RegExp(r'^cbr'),
  'kawasaki': RegExp(r'^(ninja|zx\d)'),
  'suzuki': RegExp(r'^gsxr'),
  'ducati': RegExp(r'^(panigale|supersport)'),
  'aprilia': RegExp(r'^(rs\d|rsv)'),
  'ktm': RegExp(r'^rc\d'),
  'bmw': RegExp(r'rr$'),
  'triumph': RegExp(r'^daytona'),
  'mv agusta': RegExp(r'^f[34]'),
};

bool isSportBike({required String brand, required String model}) {
  final rule = _sportModels[brand.trim().toLowerCase()];
  final name = model.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
  return rule != null && rule.hasMatch(name);
}

/// Third-party insurance (the legal minimum, with travel assistance) for
/// an experienced rider without claims, euros per year by engine size
/// (2026 quotes and comparison sites: about 70-150 € up to 125 cc, 180-360 €
/// for a 700 cc). The owner's own quote replaces it.
const insuranceBands = <({int? maxCc, double euros})>[
  (maxCc: 125, euros: 90),
  (maxCc: 400, euros: 150),
  (maxCc: 800, euros: 230),
  (maxCc: null, euros: 340),
];

/// Insurers charge sports bikes about a third more.
const sportInsuranceFactor = 1.3;

/// The band of [insuranceBands] for [engineCc]; the middle one when unknown.
({int? minCc, int? maxCc, double euros}) insuranceBandFor(int? engineCc) {
  final cc = engineCc ?? 700;
  final index = insuranceBands.indexWhere(
    (b) => b.maxCc == null || cc <= b.maxCc!,
  );
  final band = insuranceBands[index];
  return (
    minCc: index == 0 ? null : insuranceBands[index - 1].maxCc! + 1,
    maxCc: band.maxCc,
    euros: band.euros,
  );
}

/// The yearly third-party insurance a bike of [engineCc] typically costs.
double insuranceEstimate(int? engineCc, {bool sport = false}) =>
    (insuranceBandFor(engineCc).euros * (sport ? sportInsuranceFactor : 1))
        .roundToDouble();

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
class const OwnershipCost({
  /// Null when it can't be worked out (unknown engine size, old bike).
  required final double? iuc,

  /// The owner's quote, or [insuranceEstimate] until they enter one.
  required final double insurance,
  required final bool insuranceEstimated,
  required final bool sport,

  /// The engine size the estimates used; null when unknown.
  required final int? engineCc,
  required final double tyres,
  required final double services,
  required final double chain,
  required final double valves,
  required final double depreciation,
  required final int years,
  required final int kmPerYear,
  required final RunningCostTable table,
}) {
  double get perYear =>
      (iuc ?? 0) + insurance + tyres + services + chain + valves + depreciation;

  double get total => perYear * years;
}

/// The yearly cost of keeping a bike bought at [price]; null without one.
OwnershipCost? ownershipCost({
  required double? price,
  required OwnershipSettings settings,
  int? engineCc,
  int? year,
  bool sport = false,
  BikeMaintenance? maintenance,
  Depreciation? depreciation,
}) {
  if (price == null || price <= 0) return null;
  final km = settings.kmPerYear;
  final years = settings.yearsToKeep;
  final table = runningCostsFor(
    engineCc,
    sport: sport,
    maintenance: maintenance,
  );
  final quote = settings.insurancePerYear?.toDouble();
  final rates = depreciation ?? generalDepreciation;

  // Same curve as the fair price: value falls by exp(-rate) per year of age
  // and per 1000 km.
  final yearlyRate = rates.perYear + rates.per1000Km * km / 1000;
  final lost = price * (1 - exp(-yearlyRate * years));

  return OwnershipCost(
    iuc: iucPerYear(engineCc: engineCc, year: year),
    insurance: quote ?? insuranceEstimate(engineCc, sport: sport),
    insuranceEstimated: quote == null,
    sport: sport,
    engineCc: engineCc,
    tyres: table.tyreSet * max(km / table.tyreLifeKm, 1 / tyreMaxYears),
    // At least one service a year, however little it is ridden.
    services: table.service * max(km / table.serviceIntervalKm, 1),
    chain: table.chainKit * km / table.chainLifeKm,
    valves: table.valveCheck * km / table.valveCheckKm,
    depreciation: lost / years,
    years: years,
    kmPerYear: km,
    table: table,
  );
}

/// Rounded to 10 € for headlines: these are estimates.
String roughPrice(double value, {AppLanguage language = .portuguese}) =>
    Formatters.price((value / 10).round() * 10.0, language: language);

/// "Custa cerca de 1 450 € por ano".
String ownershipHeadline(
  OwnershipCost c, {
  AppLanguage language = .portuguese,
}) => language.messages.costsAboutPerYear(
  price: roughPrice(c.perYear, language: language),
);

/// "Em 3 anos: cerca de 4 350 €".
String ownershipTotalLine(
  OwnershipCost c, {
  AppLanguage language = .portuguese,
}) => language.messages.ownershipTotal(
  years: c.years,
  total: roughPrice(c.total, language: language),
);

/// One line per part of the cost, in the order they are added up.
List<String> ownershipLines(
  OwnershipCost c, {
  int? year,
  AppLanguage language = .portuguese,
}) {
  final t = c.table;
  String km(int value) => Formatters.mileage(value, language: language);
  return [
    language.messages.ownershipDepreciation(
      price: roughPrice(c.depreciation, language: language),
      years: c.years,
    ),
    switch (c.iuc) {
      null when year != null && year < iucFirstYear =>
        language.messages.iucNotCalculated(
          iucFirstYear: (iucFirstYear).toString(),
        ),
      null => language.messages.roadTaxIUCModelEngineSizeUnknown,
      0.0 => language.messages.roadTaxIUCExemptLessThanEUR10,
      final iuc => language.messages.roadTaxIUC(
        price: Formatters.price(iuc, language: language),
      ),
    },
    c.insuranceEstimated
        ? _insuranceEstimateLine(c, language)
        : language.messages.insuranceYourFigure(
            price: Formatters.price(c.insurance, language: language),
          ),
    if ((t.frontTyre, t.rearTyre) case (final front?, final rear?))
      language.messages.ownershipTyresSized(
        price: Formatters.price(c.tyres, language: language),
        front: front,
        rear: rear,
        distance: km(t.tyreLifeKm),
        tyreMaxYears: (tyreMaxYears).toString(),
      )
    else
      language.messages.ownershipTyres(
        price: Formatters.price(c.tyres, language: language),
        distance: km(t.tyreLifeKm),
        tyreMaxYears: (tyreMaxYears).toString(),
      ),
    language.messages.ownershipServicing(
      price: Formatters.price(c.services, language: language),
      distance: km(t.serviceIntervalKm),
    ),
    language.messages.ownershipChain(
      price: Formatters.price(c.chain, language: language),
      distance: km(t.chainLifeKm),
    ),
    language.messages.ownershipValves(
      price: Formatters.price(c.valves, language: language),
      cost: Formatters.price(t.valveCheck, language: language),
      distance: km(t.valveCheckKm),
    ),
  ];
}

/// "Seguro: cerca de 300 € (estimativa contra terceiros, desportiva de 401
/// a 800 cc; indique o seu valor)".
String _insuranceEstimateLine(OwnershipCost c, AppLanguage language) {
  final m = language.messages;
  final price = Formatters.price(c.insurance, language: language);
  final band = insuranceBandFor(c.engineCc);
  final bandText = c.engineCc == null
      ? m.insuranceEngineUnknown
      : switch ((band.minCc, band.maxCc)) {
          (null, final max?) => m.insuranceBandUpTo(max: max.toString()),
          (final min?, null) => m.insuranceBandOver(min: (min - 1).toString()),
          (final min, final max) => m.insuranceBandRange(
            min: min.toString(),
            max: max.toString(),
          ),
        };
  return c.sport
      ? m.insuranceEstimateSport(price: price, band: bandText)
      : m.insuranceEstimate(price: price, band: bandText);
}

/// What the estimate assumes, under the lines.
String ownershipFootnote(
  OwnershipCost c, {
  AppLanguage language = .portuguese,
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
