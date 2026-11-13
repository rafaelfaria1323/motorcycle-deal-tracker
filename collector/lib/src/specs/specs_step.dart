import 'api_ninjas.dart';
import 'model_specs.dart';
import 'specs_reader.dart';

/// What the step did for one model.
class const SpecsOutcome({
  required final SpecsModel model,
  final SpecsMatch? match,
  final List<String> filled = const [],
  final List<String> differences = const [],
  final String? error,
});

/// Looks each of [models] up (its names in order, until one matches),
/// stores what was found through [store] (also nothing: the model counts
/// as asked) and compares it with the figures already typed. A failed
/// request leaves that model unasked; a refusal of the key or of the
/// month's calls stops the step, the rest unasked.
Future<List<SpecsOutcome>> lookUpSpecs(
  List<SpecsModel> models, {
  required Future<List<Map<String, Object?>>> Function(
    String make,
    String model,
  )
  ask,
  required Future<List<String>> Function(String id, ModelSpecs specs) store,
}) async {
  final out = <SpecsOutcome>[];
  for (final model in models) {
    SpecsMatch? match;
    try {
      for (final name in model.names) {
        match = matchSpecs(model, await ask(model.brand, name));
        if (match != null) break;
      }
    } on ApiNinjasFailure catch (e) {
      out.add(SpecsOutcome(model: model, error: e.message));
      if (e.stopsRun) break;
      continue;
    }
    final specs = match?.specs ?? const ModelSpecs();
    out.add(
      SpecsOutcome(
        model: model,
        match: match,
        filled: await store(model.id, specs),
        differences: specDifferences(model.specs, specs),
      ),
    );
  }
  return out;
}

/// The step's report (Markdown, for the run's summary).
String specsReport(List<SpecsOutcome> outcomes) {
  final b = StringBuffer('## Model specifications (API Ninjas, N.76)\n\n');
  if (outcomes.isEmpty) {
    b.writeln(
      'No model to look up: every figure is filled or was asked '
      'within 30 days.',
    );
    return b.toString();
  }
  b
    ..writeln('| Model | Found | Filled | Differs from the catalog |')
    ..writeln('| --- | --- | --- | --- |');
  for (final o in outcomes) {
    final m = o.match;
    final found = o.error != null
        ? 'failed: ${o.error}'
        : m == null
        ? 'not found'
        : '${m.name} ${m.year}';
    b.writeln(
      '| ${o.model.brand} ${o.model.model} | $found '
      '| ${o.filled.isEmpty ? '-' : o.filled.join(', ')} '
      '| ${o.differences.isEmpty ? '-' : o.differences.join('; ')} |',
    );
  }
  final differ = outcomes.where((o) => o.differences.isNotEmpty).length;
  if (differ > 0) {
    b.writeln(
      '\n$differ model(s) differ: check the maker\'s spec sheet and fix '
      'the catalog with a migration if it is wrong (the API may also be '
      'another generation).',
    );
  }
  return b.toString();
}
