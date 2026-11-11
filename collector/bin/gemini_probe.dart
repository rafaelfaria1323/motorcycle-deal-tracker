// TEMPORARY (N.55 diagnosis, removed before merging): times Gemini requests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final key = Platform.environment['GEMINI_API_KEY']!.trim();
  final client = http.Client();
  final headers = {'Content-Type': 'application/json', 'x-goog-api-key': key};

  try {
    final r = await client
        .get(
          Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
            'pageSize': '200',
          }),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    final names = [
      for (final m in (jsonDecode(r.body)['models'] as List? ?? const []))
        if ('${m['name']}'.contains('flash')) '${m['name']}',
    ];
    stdout.writeln('models (${r.statusCode}): ${names.join(', ')}');
  } on Object catch (e) {
    stdout.writeln('models: $e');
  }

  Future<void> probe(
    String label,
    String model,
    String prompt,
    Map<String, Object?> config,
  ) async {
    final watch = Stopwatch()..start();
    try {
      final r = await client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models/$model:generateContent',
            ),
            headers: headers,
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': config,
            }),
          )
          .timeout(const Duration(seconds: 100));
      final secs = watch.elapsed.inMilliseconds / 1000;
      final body = r.body;
      Object? usage, finish, version;
      var text = '';
      try {
        final d = jsonDecode(body) as Map<String, Object?>;
        usage = d['usageMetadata'];
        version = d['modelVersion'];
        final c = (d['candidates'] as List?)?.first as Map?;
        finish = c?['finishReason'];
        text = '${c?['content']?['parts']?[0]?['text'] ?? d['error'] ?? ''}';
      } on Object {
        text = body;
      }
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      stdout.writeln(
        '$label [$model]: HTTP ${r.statusCode} in $secs s, version $version, '
        'finish $finish, usage $usage, text ${text.length} chars: '
        '${text.length > 160 ? text.substring(0, 160) : text}',
      );
    } on TimeoutException {
      stdout.writeln('$label [$model]: no answer in 100 s');
    } on Object catch (e) {
      stdout.writeln('$label [$model]: $e');
    }
  }

  const tiny = 'Answer with the JSON object {"ok": true} and nothing else.';
  const json = {'responseMimeType': 'application/json'};
  const off = {'thinkingBudget': 0};

  await withServiceClient((db) async {
    final ads = await AuditStore(db)
        .sample(DateTime.now().toUtc().subtract(const Duration(days: 7)), 10);
    final one = descriptionPrompt(ads.take(1).toList());
    final ten = descriptionPrompt(ads);
    stdout.writeln('prompt chars: one ad ${one.length}, ten ${ten.length}');
    const m = 'gemini-flash-latest';
    await probe('tiny, defaults', m, tiny, {});
    await probe('tiny, json', m, tiny, json);
    await probe('tiny, json, thinking off', m, tiny, {
      ...json,
      'thinkingConfig': off,
    });
    await probe('one ad, json, no schema', m, one, json);
    await probe('one ad, schema', m, one, {
      ...json,
      'responseSchema': descriptionSchema,
    });
    await probe('one ad, json schema field', m, one, {
      ...json,
      'responseJsonSchema': _lower(descriptionSchema),
    });
    await probe('ten ads, json, no schema', m, ten, json);
    for (final other in ['gemini-2.5-flash', 'gemini-flash-lite-latest']) {
      await probe('tiny', other, tiny, json);
      await probe('one ad, schema', other, one, {
        ...json,
        'responseSchema': descriptionSchema,
      });
    }
  });
  client.close();
}

Object? _lower(Object? v) => switch (v) {
  final Map<String, Object?> m => {
    for (final e in m.entries)
      e.key: e.key == 'type' ? '${e.value}'.toLowerCase() : _lower(e.value),
  },
  final List<Object?> l => [for (final x in l) _lower(x)],
  _ => v,
};
