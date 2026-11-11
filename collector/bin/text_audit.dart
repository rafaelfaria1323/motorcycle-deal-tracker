import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;

/// Ads per request: short enough for a complete answer, few enough requests
/// for the free tier.
const adsPerRequest = 10;

/// Unmatched titles per request (one line each).
const titlesPerRequest = 40;

/// The weekly description check (N.55): a sample of the week's ads goes to
/// Gemini's free tier (env `GEMINI_API_KEY`, `GEMINI_MODEL`), which reads
/// the same facts as the database's rules (accident, repair, scratches, A2,
/// single owner, legalisation, extras, km in the text) and places titles no
/// model matched; the report of the disagreements goes to stdout and to the
/// run's summary (`GITHUB_STEP_SUMMARY`). It changes nothing in the
/// database. Without a key it says so and stops (exit 0).
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addOption('ads', defaultsTo: '60', help: 'Ads to check.')
      ..addOption('titles', defaultsTo: '40', help: 'Unmatched titles to ask.')
      ..addOption(
        'days',
        defaultsTo: '7',
        help: 'Ads first seen this recently.',
      )
      ..addOption(
        'minutes',
        defaultsTo: '10',
        help: 'No new request after this long; the report covers what came.',
      ),
    args,
    atLeast: {'ads': 0, 'titles': 0, 'days': 1, 'minutes': 1},
    usage: 'Usage: dart run bin/text_audit.dart [options]',
  );
  if (options == null) return;
  final env = Platform.environment;
  final apiKey = env['GEMINI_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stdout.writeln(
      'GEMINI_API_KEY is not set; the description check is skipped.',
    );
    return;
  }
  final models = geminiModels(env['GEMINI_MODEL']);
  final since = DateTime.now().toUtc().subtract(
    Duration(days: int.parse(options.option('days')!)),
  );

  await withServiceClient((client) async {
    final store = AuditStore(client);
    final ads = await store.sample(since, int.parse(options.option('ads')!));
    final titles = await store.unmatchedTitles(
      since,
      int.parse(options.option('titles')!),
    );
    final catalog = await loadCatalog(client);
    final httpClient = http.Client();
    final gemini = GeminiClient(
      apiKey: apiKey,
      models: models,
      httpClient: httpClient,
      log: stdout.writeln,
    );
    final problems = <String>[];
    final disagreements = <Disagreement>[];
    final suggestions = <TitleSuggestion>[];
    var read = 0;
    final budget = Duration(minutes: int.parse(options.option('minutes')!));
    final clock = Stopwatch()..start();

    // One request: its answer, or null with the reason in the problems; a
    // line in the log either way, so a slow run shows where it is.
    Future<Object?> ask(
      String label,
      String prompt,
      Map<String, Object?> schema,
    ) async {
      if (clock.elapsed >= budget) {
        problems.add('$label: not asked, the ${budget.inMinutes} min are up');
        stdout.writeln('$label: not asked (time is up)');
        return null;
      }
      final started = clock.elapsed;
      try {
        final answer = await gemini.generateJson(prompt, schema);
        stdout.writeln('$label: ${_seconds(clock.elapsed - started)}');
        return answer;
      } on GeminiFailure catch (e) {
        problems.add('$label: ${e.message}');
        stdout.writeln(
          '$label: failed after ${_seconds(clock.elapsed - started)}: '
          '${e.message}',
        );
        return null;
      }
    }

    stdout.writeln(
      'Asking ${models.join(' (else ')}${')' * (models.length - 1)} about ${ads.length} ad(s) and ${titles.length} '
      'title(s).',
    );
    try {
      for (var i = 0; i < ads.length; i += adsPerRequest) {
        final batch = ads.sublist(i, (i + adsPerRequest).clamp(0, ads.length));
        final answer = await ask(
          'ads ${i + 1}-${i + batch.length}',
          descriptionPrompt(batch),
          descriptionSchema,
        );
        if (answer == null) continue;
        final readings = readDescriptionAnswer(batch, answer);
        read += readings.length;
        for (final MapEntry(key: ad, value: reading) in readings.entries) {
          disagreements.addAll(compareReadings(ad, reading));
        }
      }
      for (var i = 0; i < titles.length; i += titlesPerRequest) {
        final batch = titles.sublist(
          i,
          (i + titlesPerRequest).clamp(0, titles.length),
        );
        final answer = await ask(
          'titles ${i + 1}-${i + batch.length}',
          titlesPrompt(batch, catalog),
          titlesSchema,
        );
        if (answer != null) {
          suggestions.addAll(readTitlesAnswer(batch, catalog, answer));
        }
      }
    } finally {
      httpClient.close();
    }

    final report = auditReport(
      model: gemini.model,
      adsAsked: ads.length,
      adsRead: read,
      disagreements: disagreements,
      titlesAsked: titles.length,
      titles: suggestions,
      problems: problems,
    );
    stdout.write(report);
    if (env['GITHUB_STEP_SUMMARY'] case final path? when path.isNotEmpty) {
      File(path).writeAsStringSync(report, mode: FileMode.append);
    }
    // Every request failed: the key, the model or the quota needs a look.
    if (problems.isNotEmpty && read == 0 && suggestions.isEmpty) exitCode = 1;
  });
}

String _seconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
