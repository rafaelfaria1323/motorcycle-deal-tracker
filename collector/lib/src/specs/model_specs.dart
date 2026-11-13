/// A catalog model's figures (N.75/N.76), as the database keeps them or
/// as read from API Ninjas; null unknown.
class const ModelSpecs({
  final double? powerKw,
  final double? torqueNm,
  final double? weightKg,
  final double? seatHeightMm,
  final double? tankLitres,
  final double? fuelLPer100Km,
  final String? frontTyre,
  final String? rearTyre,
  final int? cylinders,
}) {
  /// The database's row (`model_specs_to_check`).
  factory ModelSpecs.fromRow(Map<String, dynamic> row) => ModelSpecs(
    powerKw: _number(row['power_kw']),
    torqueNm: _number(row['torque_nm']),
    weightKg: _number(row['weight_kg']),
    seatHeightMm: _number(row['seat_height_mm']),
    tankLitres: _number(row['tank_l']),
    fuelLPer100Km: _number(row['fuel_l_per_100km']),
    frontTyre: row['front_tyre'] as String?,
    rearTyre: row['rear_tyre'] as String?,
    cylinders: (row['cylinders'] as num?)?.toInt(),
  );

  /// What `store_model_specs` takes: the known figures by column name.
  Map<String, Object> toJson() => {
    'power_kw': ?powerKw,
    'torque_nm': ?torqueNm,
    'weight_kg': ?weightKg,
    'seat_height_mm': ?seatHeightMm,
    'tank_l': ?tankLitres,
    'fuel_l_per_100km': ?fuelLPer100Km,
    'front_tyre': ?frontTyre,
    'rear_tyre': ?rearTyre,
    'cylinders': ?cylinders,
  };

  /// Whether nothing is known.
  bool get isEmpty => toJson().isEmpty;

  /// Each figure: this one's, else [other]'s.
  ModelSpecs orElse(ModelSpecs other) => ModelSpecs(
    powerKw: powerKw ?? other.powerKw,
    torqueNm: torqueNm ?? other.torqueNm,
    weightKg: weightKg ?? other.weightKg,
    seatHeightMm: seatHeightMm ?? other.seatHeightMm,
    tankLitres: tankLitres ?? other.tankLitres,
    fuelLPer100Km: fuelLPer100Km ?? other.fuelLPer100Km,
    frontTyre: frontTyre ?? other.frontTyre,
    rearTyre: rearTyre ?? other.rearTyre,
    cylinders: cylinders ?? other.cylinders,
  );

  static double? _number(Object? v) => v is num
      ? v.toDouble()
      : v is String
      ? double.tryParse(v)
      : null;
}

/// One model as `model_specs_to_check` gives it: its names, engine range
/// and the figures it has.
class const SpecsModel({
  required final String id,
  required final String brand,
  required final String model,
  final List<String> aliases = const [],
  final List<String> excludedWords = const [],
  final int? engineCcMin,
  final int? engineCcMax,
  final ModelSpecs specs = const ModelSpecs(),
}) {
  factory SpecsModel.fromRow(Map<String, dynamic> row) => SpecsModel(
    id: row['id'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    aliases: [for (final a in row['aliases'] as List? ?? const []) '$a'],
    excludedWords: [
      for (final w in row['excluded_words'] as List? ?? const []) '$w',
    ],
    engineCcMin: (row['engine_cc_min'] as num?)?.toInt(),
    engineCcMax: (row['engine_cc_max'] as num?)?.toInt(),
    specs: ModelSpecs.fromRow(row),
  );

  /// The model and its other names: what the API is asked for, in order.
  List<String> get names => [model, ...aliases];
}
