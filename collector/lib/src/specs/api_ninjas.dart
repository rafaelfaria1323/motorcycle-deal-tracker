import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Why API Ninjas gave no answer.
class const ApiNinjasFailure(final String message, {final int? status})
    implements Exception {
  /// A refusal no other request will get past this run: a bad or missing
  /// key (401/403) or the month's calls used up (429).
  bool get stopsRun => status == 401 || status == 403 || status == 429;

  @override
  String toString() => 'API Ninjas: $message';
}

/// API Ninjas' motorcycles API (N.76; env `API_NINJAS_KEY`, free tier):
/// the makers' figures of a model, one entry per model year. Only the
/// weekly specification step asks it, a few calls a week, one at a time
/// and [spacing] apart; the key goes in the `X-Api-Key` header, never in
/// the address.
class ApiNinjasClient({
  required final String apiKey,
  required final http.Client httpClient,
  final Duration spacing = const Duration(seconds: 1),
  final Duration timeout = const Duration(seconds: 30),
  final Future<void> Function(Duration) wait = Future<void>.delayed,
}) {
  bool _first = true;

  /// The requests sent so far (N.101: stored as the run's usage).
  int requests = 0;

  /// The entries whose make is [make] and whose model name contains
  /// [model] (the API's own partial match); throws [ApiNinjasFailure].
  Future<List<Map<String, Object?>>> motorcycles(
    String make,
    String model,
  ) async {
    if (!_first) await wait(spacing);
    _first = false;
    final uri = Uri.https('api.api-ninjas.com', '/v1/motorcycles', {
      'make': make,
      'model': model,
    });
    final http.Response response;
    requests++;
    try {
      response = await httpClient
          .get(uri, headers: {'X-Api-Key': apiKey})
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiNinjasFailure('no answer in time');
    } on http.ClientException catch (e) {
      throw ApiNinjasFailure('connection failed: ${e.message}');
    }
    if (response.statusCode != 200) {
      throw ApiNinjasFailure(
        'HTTP ${response.statusCode} for $make $model',
        status: response.statusCode,
      );
    }
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw ApiNinjasFailure('not JSON for $make $model');
    }
    if (body is! List) throw ApiNinjasFailure('not a list for $make $model');
    return [
      for (final e in body)
        if (e is Map<String, Object?>) e,
    ];
  }
}
