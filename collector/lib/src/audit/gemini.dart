import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Google's Gemini API, free tier (N.55): only the weekly description check
/// uses it, never a score. Key from env `GEMINI_API_KEY`; model from
/// `GEMINI_MODEL`, by default the alias of the current Flash model, so a
/// retired model name doesn't stop the check.
const defaultGeminiModel = 'gemini-flash-latest';

/// Why a request got no answer.
class const GeminiFailure(final String message) implements Exception {
  @override
  String toString() => 'Gemini: $message';
}

/// Asks Gemini for JSON in a given shape. One request at a time, [spacing]
/// apart (the free tier allows a few a minute); a refusal for too many
/// requests (429) or a busy server (500/503) is tried once more after
/// [retryDelay]. Thinking is switched off (`thinkingBudget: 0`; with it a
/// batch of descriptions took minutes); a model that refuses that setting
/// (HTTP 400 naming it) is asked again without it, for the rest of the run.
class GeminiClient({
  required final String apiKey,
  final String model = defaultGeminiModel,
  required final http.Client httpClient,
  final Duration spacing = const Duration(seconds: 15),
  final Duration retryDelay = const Duration(seconds: 60),
  final Duration timeout = const Duration(seconds: 120),
  final Future<void> Function(Duration) wait = Future<void>.delayed,
}) {
  bool _first = true;
  bool _thinkingOff = true;

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
    var response = await _post(_body(prompt, schema));
    if (_thinkingOff &&
        response.statusCode == 400 &&
        response.body.toLowerCase().contains('thinking')) {
      _thinkingOff = false;
      response = await _post(_body(prompt, schema));
    }
    if (const {429, 500, 503}.contains(response.statusCode)) {
      await wait(retryDelay);
      response = await _post(_body(prompt, schema));
    }
    if (response.statusCode != 200) {
      throw GeminiFailure(
        'HTTP ${response.statusCode}: ${_shortError(response.body)}',
      );
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
      'temperature': 0,
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
      throw const GeminiFailure('no answer in time');
    } on http.ClientException catch (e) {
      throw GeminiFailure('request failed: ${e.message}');
    }
  }
}

/// The JSON inside a `generateContent` answer: the first candidate's text
/// (a code fence around it is tolerated); throws [GeminiFailure].
Object? answerJson(String responseBody) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseBody);
  } on FormatException {
    throw const GeminiFailure('the answer is not JSON');
  }
  final text = switch (decoded) {
    {
      'candidates': [
        {'content': {'parts': [{'text': final String text}, ...]}},
        ...,
      ],
    } =>
      text,
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
    throw const GeminiFailure('the text is not JSON');
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
