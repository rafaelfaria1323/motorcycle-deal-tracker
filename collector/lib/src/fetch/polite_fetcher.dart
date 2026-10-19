import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'robots.dart';

/// We decided not to fetch this (our own rules said no). Nothing was sent.
class FetchRefused implements Exception {
  const FetchRefused(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// The site pushed back. Stop, and do not try again soon.
class FetchBlocked implements Exception {
  const FetchBlocked(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// A network or HTTP problem that is not a block.
class FetchFailed implements Exception {
  const FetchFailed(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

class FetchPolicy {
  const FetchPolicy({
    this.minDelay = const Duration(seconds: 6),
    this.jitter = const Duration(seconds: 4),
    this.maxRequestsPerRun = 20,
    this.maxRequestsPerDay = 60,
    this.timeout = const Duration(seconds: 20),
    this.cooldownAfterBlock = const Duration(hours: 24),
  });

  final Duration minDelay;
  final Duration jitter;
  final int maxRequestsPerRun;
  final int maxRequestsPerDay;
  final Duration timeout;
  final Duration cooldownAfterBlock;
}

/// What survives between runs: today's request count and the last block.
class FetchState {
  FetchState({required this.day, this.requests = 0, this.blockedAt});

  factory FetchState.fromJson(Map<String, dynamic> json) => FetchState(
    day: json['day'] as String,
    requests: json['requests'] as int,
    blockedAt: json['blocked_at'] == null
        ? null
        : DateTime.parse(json['blocked_at'] as String),
  );

  String day;
  int requests;
  DateTime? blockedAt;

  Map<String, dynamic> toJson() => {
    'day': day,
    'requests': requests,
    'blocked_at': blockedAt?.toUtc().toIso8601String(),
  };

  /// The count restarts each day; a block is remembered.
  FetchState rolledTo(String today) => day == today
      ? this
      : FetchState(day: today, requests: 0, blockedAt: blockedAt);
}

/// Null when the address may be fetched, otherwise why not.
String? urlProblem(Uri url, {required String host}) {
  if (url.scheme != 'https') return 'only https addresses are allowed';
  if (url.host != host) return 'only $host is allowed (got ${url.host})';
  if (url.userInfo.isNotEmpty) return 'addresses with credentials are refused';
  if (!url.path.startsWith('/motos/')) {
    return 'only /motos/ pages are allowed (got ${url.path})';
  }
  return null;
}

/// A deliberately slow, capped, honest downloader for one website.
class PoliteFetcher {
  PoliteFetcher({
    required this.host,
    required this.statePath,
    this.userAgent = 'MotorcycleDealTracker/0.1 (personal project, low volume)',
    this.policy = const FetchPolicy(),
  });

  final String host;
  final String statePath;
  final String userAgent;
  final FetchPolicy policy;

  final _random = Random();
  late final HttpClient _client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = policy.timeout;

  late FetchState _state;
  late RobotsRules _robots;
  var _runRequests = 0;

  static String _today() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  /// Checks the pause after a block, loads robots.txt. Call before [get].
  Future<void> prepare() async {
    _state = (await _loadState()).rolledTo(_today());

    final blocked = _state.blockedAt;
    if (blocked != null) {
      final until = blocked.add(policy.cooldownAfterBlock);
      if (DateTime.now().toUtc().isBefore(until)) {
        throw FetchRefused(
          'paused until ${until.toIso8601String()} because the site pushed '
          'back on ${blocked.toIso8601String()}; not retrying sooner',
        );
      }
      _state.blockedAt = null;
    }

    final robots = await _request(Uri.https(host, '/robots.txt'));
    if (robots.status != 200) {
      throw FetchRefused(
        'could not read robots.txt (HTTP ${robots.status}); '
        'not fetching without it',
      );
    }
    _robots = RobotsRules.parse(robots.body);
  }

  /// Downloads one page and returns its HTML.
  Future<String> get(Uri url) async {
    var current = url;
    for (var hop = 0; hop <= 3; hop++) {
      final problem = urlProblem(current, host: host);
      if (problem != null) throw FetchRefused('$current: $problem');
      final target =
          current.path + (current.hasQuery ? '?${current.query}' : '');
      if (!_robots.isAllowed(target)) {
        throw FetchRefused('$current: disallowed by robots.txt');
      }

      final response = await _request(current);
      final status = response.status;

      if (status == 200) {
        if (!response.body.contains('__NEXT_DATA__')) {
          await _markBlocked();
          throw FetchBlocked(
            '$current: not a normal page (a block or verification page?)',
          );
        }
        return response.body;
      }
      if ({301, 302, 307, 308}.contains(status) && response.location != null) {
        current = current.resolve(response.location!);
        continue;
      }
      throw FetchFailed('$current: HTTP $status');
    }
    throw FetchFailed('$url: too many redirects');
  }

  Future<({int status, String body, String? location})> _request(
    Uri url,
  ) async {
    if (_runRequests >= policy.maxRequestsPerRun) {
      throw FetchRefused(
        'run limit of ${policy.maxRequestsPerRun} requests reached',
      );
    }
    if (_state.requests >= policy.maxRequestsPerDay) {
      throw FetchRefused(
        'daily limit of ${policy.maxRequestsPerDay} requests reached',
      );
    }
    if (_runRequests > 0) {
      final extra = _random.nextInt(policy.jitter.inMilliseconds + 1);
      await Future<void>.delayed(
        policy.minDelay + Duration(milliseconds: extra),
      );
    }
    _runRequests++;
    _state.requests++;
    await _saveState();

    try {
      final request = await _client.getUrl(url).timeout(policy.timeout);
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml')
        ..set(HttpHeaders.acceptLanguageHeader, 'pt-PT,pt;q=0.9');
      final response = await request.close().timeout(policy.timeout);
      final body = await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(policy.timeout);

      if ({403, 429, 503}.contains(response.statusCode)) {
        await _markBlocked();
        throw FetchBlocked('$url: HTTP ${response.statusCode}');
      }
      return (
        status: response.statusCode,
        body: body,
        location: response.headers.value(HttpHeaders.locationHeader),
      );
    } on TimeoutException {
      throw FetchFailed('$url: timed out');
    } on SocketException catch (e) {
      throw FetchFailed('$url: ${e.message}');
    } on HandshakeException catch (e) {
      throw FetchFailed('$url: ${e.message}');
    }
  }

  Future<void> _markBlocked() async {
    _state.blockedAt = DateTime.now().toUtc();
    await _saveState();
  }

  Future<FetchState> _loadState() async {
    final file = File(statePath);
    try {
      if (await file.exists()) {
        return FetchState.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } on Object {
      // A damaged state file is treated as a fresh one.
    }
    return FetchState(day: _today());
  }

  Future<void> _saveState() async =>
      File(statePath).writeAsString(jsonEncode(_state.toJson()));

  void close() => _client.close(force: true);
}
