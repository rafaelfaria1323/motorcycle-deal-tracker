import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Google's Gemini API, free tier (N.55): only the weekly description check
/// uses it, never a score. Key from env `GEMINI_API_KEY`; models from
/// `GEMINI_MODEL` (comma-separated, tried in order), by default the aliases
/// of the current Flash-Lite and Flash models, so a retired model name
/// doesn't stop the check. Flash-Lite first: on 2026-11-11 the free Flash
/// model hung or answered 503 ("high demand") to every request, even a
/// one-line one, while Flash-Lite answered an ad in 5 s.
const defaultGeminiModels = ['gemini-flash-lite-latest', 'gemini-flash-latest'];

/// The models a `GEMINI_MODEL` setting names, or [defaultGeminiModels].
List<String> geminiModels(String? setting) {
  final named = [
    for (final m in (setting ?? '').split(','))
      if (m.trim().isNotEmpty) m.trim(),
  ];
  return named.isEmpty ? defaultGeminiModels : named;
}

/// Why a request got no answer.
class const GeminiFailure(final String message) implements Exception {
  @override
  String toString() => 'Gemini: $message';
}

/// A model that can't answer now: busy, gone or silent.
class const _Unavailable(final GeminiFailure failure) implements Exception;

/// Asks Gemini for JSON in a given shape. One request at a time, [spacing]
/// apart (the free tier allows a few a minute); a refusal for too many
/// requests (429) or a busy server (500/503) is tried once more after
/// [retryDelay]. A model still busy, gone (404) or silent for [timeout]
/// gives way to the next of [models] for the rest of the run ([log] says
/// so). The model's own temperature is kept (Gemini 3 loops below 1.0) and
/// an answer is capped at [maxOutputTokens], so a loop ends as a cut
/// answer. Thinking is switched off (`thinkingBudget: 0`); a model that
/// refuses that setting (HTTP 400 naming it) is asked again without it, for
/// the rest of the run.
class GeminiClient({
  required final String apiKey,
  final List<String> models = defaultGeminiModels,
  required final http.Client httpClient,
  final Duration spacing = const Duration(seconds: 15),
  final Duration retryDelay = const Duration(seconds: 60),
  final Duration timeout = const Duration(seconds: 120),
  final int maxOutputTokens = 8192,
  final Future<void> Function(Duration) wait = Future<void>.delayed,
  final void Function(String) log = _ignore,
}) {
  bool _first = true;
  bool _thinkingOff = true;
  int _current = 0;

  /// The model asked now.
  String get model => models[_current];

  Uri get _endpoint => Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/$model:generateContent',
  );

  /// The JSON Gemini answers [prompt] with, following [schema] (the API's
  /// `responseSchema`); throws [GeminiFailure].
  Future<Object?> generateJson(
    String prompt,
    Map<String, Object?> schema,
  ) async {
    if (!_first) await wait(spacing);
    _first = false;
    while (true) {
      final GeminiFailure failure;
      try {
        return await _ask(prompt, schema);
      } on _Unavailable catch (e) {
        failure = e.failure;
      }
      if (_current + 1 >= models.length) throw failure;
      final previous = model;
      _current++;
      log('$previous: ${failure.message}; asking $model from now on');
    }
  }

  Future<Object?> _ask(String prompt, Map<String, Object?> schema) async {
    var response = await _post(_body(prompt, schema));
    if (_thinkingOff &&
        response.statusCode == 400 &&
        response.body.toLowerCase().contains('thinking')) {
      _thinkingOff = false;
      response = await _post(_body(prompt, schema));
    }
    if (_busy.contains(response.statusCode)) {
      await wait(retryDelay);
      response = await _post(_body(prompt, schema));
    }
    if (response.statusCode != 200) {
      final failure = GeminiFailure(
        'HTTP ${response.statusCode}: ${_shortError(response.body)}',
      );
      throw _busy.contains(response.statusCode) || response.statusCode == 404
          ? _Unavailable(failure)
          : failure;
    }
    return answerJson(response.body);
  }

  String _body(String prompt, Map<String, Object?> schema) => jsonEncode({
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ],
    'generationConfig': {
      'maxOutputTokens': maxOutputTokens,
      'responseMimeType': 'application/json',
      'responseSchema': schema,
      if (_thinkingOff) 'thinkingConfig': {'thinkingBudget': 0},
    },
  });

  Future<http.Response> _post(String body) async {
    try {
      return await httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const _Unavailable(GeminiFailure('no answer in time'));
    } on http.ClientException catch (e) {
      throw GeminiFailure('request failed: ${e.message}');
    }
  }
}

const _busy = {429, 500, 503};

void _ignore(String _) {}

/// The JSON inside a `generateContent` answer: the first candidate's text
/// (a code fence around it is tolerated); throws [GeminiFailure].
Object? answerJson(String responseBody) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseBody);
  } on FormatException {
    throw const GeminiFailure('the answer is not JSON');
  }
  final (text, finish) = switch (decoded) {
    {
      'candidates': [
        {'content': {'parts': [{'text': final String text}, ...]}} &&
            final Map<String, Object?> candidate,
        ...,
      ],
    } =>
      (text, candidate['finishReason']),
    {'candidates': [{'finishReason': final String reason}, ...]} =>
      throw GeminiFailure('no text (finish reason $reason)'),
    _ => throw const GeminiFailure('no text in the answer'),
  };
  final unfenced = text
      .trim()
      .replaceFirst(RegExp(r'^```(json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  try {
    return jsonDecode(unfenced);
  } on FormatException {
    throw GeminiFailure(
      finish == 'MAX_TOKENS'
          ? 'the answer was cut at the token limit'
          : 'the text is not JSON',
    );
  }
}

String _shortError(String body) {
  final message = switch (_tryDecode(body)) {
    {'error': {'message': final String m}} => m,
    _ => body,
  };
  final oneLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= 200 ? oneLine : '${oneLine.substring(0, 200)}…';
}

Object? _tryDecode(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}
