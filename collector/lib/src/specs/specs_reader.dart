import 'model_specs.dart';

/// Reads API Ninjas' motorcycle entries (N.76): every figure is text with
/// its units ("73.4 HP (53.6  kW)) @ 9000 RPM", "14.00 Litres (3.70 US
/// gallons)"), so each is read by its unit; what can't be read is unknown.
ModelSpecs specsFromEntry(Map<String, Object?> entry) {
  String? text(String key) {
    final v = entry[key];
    return v == null ? null : '$v';
  }

  final power = text('power');
  return ModelSpecs(
    powerKw:
        _unit(power, r'kW') ??
        _round1(_unit(power, r'(?:HP|hp|PS)', first: true), 0.7457),
    torqueNm: _unit(text('torque'), r'Nm'),
    weightKg: _unit(text('total_weight'), r'kg'),
    seatHeightMm: _unit(text('seat_height'), r'mm', first: true),
    tankLitres: _unit(text('fuel_capacity'), r'(?:Litres|litres|L)\b'),
    fuelLPer100Km: _unit(
      text('fuel_consumption'),
      r'(?:litres|Litres|l|L)\s*/\s*100\s*km',
    ),
    frontTyre: tyreSize(text('front_tire')),
    rearTyre: tyreSize(text('rear_tire')),
    cylinders: cylindersOf(text('engine')),
  );
}

/// The engine size in cc ("689.0 ccm (42.04 cubic inches)").
double? displacementOf(Map<String, Object?> entry) {
  final v = entry['displacement'];
  return v == null ? null : _unit('$v', r'(?:ccm|cc)');
}

/// "120/70-ZR17", "180/55 ZR 17" -> "120/70-17", "180/55-17"; null when
/// there is no size of that shape.
String? tyreSize(String? text) {
  if (text == null) return null;
  final m = RegExp(
    r'(\d{2,3})\s*/\s*(\d{2})\s*[-–]?\s*[A-Za-z]{0,3}\s*-?\s*(\d{2})(?!\d)',
  ).firstMatch(text);
  return m == null ? null : '${m[1]}/${m[2]}-${m[3]}';
}

/// The cylinders an engine description names ("In-line four, four-stroke"
/// -> 4, "Twin" -> 2, "Single cylinder" -> 1); null when it names none.
int? cylindersOf(String? engine) {
  if (engine == null) return null;
  final words = engine
      .toLowerCase()
      .replaceAll(RegExp(r'(two|four)[\s-]*stroke'), ' ')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ');
  const names = <String, int>{
    'single': 1,
    'one': 1,
    'twin': 2,
    'two': 2,
    'v2': 2,
    'three': 3,
    'triple': 3,
    'four': 4,
    'v4': 4,
    'six': 6,
    'v6': 6,
  };
  for (final word in words.split(' ')) {
    final n = names[word];
    if (n != null) return n;
  }
  return null;
}

/// The figures of [model] among the API's [entries]: the entries whose
/// name holds one of the model's names as whole words (its spelling's
/// letters and digits; "YZF-R7" holds "R7", "MT-07 ABS" holds "MT-07",
/// "YZF-R1M" doesn't hold "R1"), none of its excluded words, and an engine
/// size within its range (+-10 %) when both are known, and the number of
/// cylinders when both are known ("CBR 500 R Four" isn't the twin
/// CBR500R). Entries named just the model ("CB650R", not "CB 650 R
/// E-Clutch") are used alone when there are any. Each figure comes from
/// the newest year that has it, within 6 years of the newest found.
SpecsMatch? matchSpecs(SpecsModel model, List<Map<String, Object?>> entries) {
  final names = {for (final n in model.names) _compact(n)}..remove('');
  final excluded = {for (final w in model.excludedWords) _compact(w)}
    ..remove('');
  final low = model.engineCcMin == null ? null : model.engineCcMin! * 0.9;
  final high = model.engineCcMax == null ? null : model.engineCcMax! * 1.1;
  final found = <({int year, String name, bool exact, ModelSpecs specs})>[];
  for (final entry in entries) {
    final name = '${entry['model'] ?? ''}';
    final words = _words(name);
    if (!names.any((n) => _holds(words, n))) continue;
    if (words.any(excluded.contains)) continue;
    final cc = displacementOf(entry);
    if (cc != null &&
        ((low != null && cc < low) || (high != null && cc > high))) {
      continue;
    }
    final specs = specsFromEntry(entry);
    final cylinders = model.specs.cylinders;
    if (cylinders != null &&
        specs.cylinders != null &&
        specs.cylinders != cylinders) {
      continue;
    }
    final year = int.tryParse('${entry['year'] ?? ''}') ?? 0;
    found.add((
      year: year,
      name: name,
      exact: names.contains(_compact(name)),
      specs: specs,
    ));
  }
  if (found.any((f) => f.exact)) found.retainWhere((f) => f.exact);
  if (found.isEmpty) return null;
  found.sort((a, b) => b.year.compareTo(a.year));
  final newest = found.first.year;
  var specs = const ModelSpecs();
  for (final f in found) {
    if (newest - f.year > 6) break;
    specs = specs.orElse(f.specs);
  }
  return SpecsMatch(
    name: found.first.name,
    year: newest,
    entries: found.length,
    specs: specs,
  );
}

/// What [matchSpecs] found: the newest entry's name and year, how many
/// entries matched, and the figures.
class const SpecsMatch({
  required final String name,
  required final int year,
  required final int entries,
  required final ModelSpecs specs,
});

/// The figures typed in the catalog that the API puts more than 10 % away
/// (tyres and cylinders: any difference), as "seat height 805 vs 835".
List<String> specDifferences(ModelSpecs typed, ModelSpecs api) {
  final out = <String>[];
  void number(String label, double? a, double? b) {
    if (a == null || b == null || a == 0) return;
    if ((a - b).abs() / a > 0.10) out.add('$label ${_show(a)} vs ${_show(b)}');
  }

  void exact(String label, Object? a, Object? b) {
    if (a != null && b != null && a != b) out.add('$label $a vs $b');
  }

  number('power kW', typed.powerKw, api.powerKw);
  number('torque Nm', typed.torqueNm, api.torqueNm);
  number('weight kg', typed.weightKg, api.weightKg);
  number('seat height mm', typed.seatHeightMm, api.seatHeightMm);
  number('tank l', typed.tankLitres, api.tankLitres);
  number('consumption l/100 km', typed.fuelLPer100Km, api.fuelLPer100Km);
  exact('front tyre', typed.frontTyre, api.frontTyre);
  exact('rear tyre', typed.rearTyre, api.rearTyre);
  exact('cylinders', typed.cylinders, api.cylinders);
  return out;
}

String _show(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// The number just before [unit] in [text] (the last such, or the first
/// with [first]); "1,2" reads as 1.2.
double? _unit(String? text, String unit, {bool first = false}) {
  if (text == null) return null;
  final matches = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:\)\s*)?' + unit)
      .allMatches(text)
      .toList();
  if (matches.isEmpty) return null;
  final m = first ? matches.first : matches.last;
  return double.tryParse(m[1]!.replaceAll(',', '.'));
}

double? _round1(double? v, double factor) =>
    v == null ? null : (v * factor * 10).roundToDouble() / 10;

List<String> _words(String name) => [
  for (final w in name.toLowerCase().split(RegExp('[^a-z0-9]+')))
    if (w.isNotEmpty) w,
];

String _compact(String name) => _words(name).join();

/// Whether some run of consecutive [words] spells [compact].
bool _holds(List<String> words, String compact) {
  for (var i = 0; i < words.length; i++) {
    var joined = '';
    for (var j = i; j < words.length && joined.length < compact.length; j++) {
      joined += words[j];
      if (joined == compact) return true;
    }
  }
  return false;
}
