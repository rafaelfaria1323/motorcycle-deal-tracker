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

/// The run reached a limit it was given (its time, or a request cap asked
/// for by hand). What was fetched so far is fine to use; the rest waits for
/// a later run.
class FetchLimitReached extends FetchRefused {
  const FetchLimitReached(super.reason);
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
    this.maxRequestsPerRun,
    this.maxRequestsPerDay,
    this.maxRunTime = const Duration(minutes: 30),
    this.timeout = const Duration(seconds: 20),
    this.readTimeout = const Duration(seconds: 60),
    this.cooldownAfterBlock = const Duration(hours: 24),
  });

  final Duration minDelay;
  final Duration jitter;

  /// Request caps; none by default (Rafael, 2026-10-22: the counts are
  /// recorded and shown in the app instead). Set for tests and by hand
  /// (`fetch.dart --max`).
  final int? maxRequestsPerRun;
  final int? maxRequestsPerDay;

  /// How long one run may keep sending requests to the site, from
  /// [PoliteFetcher.prepare]: keeps a long backlog (e.g. listing pages
  /// still to read) inside the job's time; the rest waits for the next run.
  final Duration? maxRunTime;

  /// For connecting and the response's headers.
  final Duration timeout;

  /// For reading the page once it is coming in: OLX's pages are 2 MB, and
  /// one took longer than [timeout] on a slow runner (it adds no request).
  final Duration readTimeout;
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
  FetchState rolledTo(String today) =>
      day == today ? this : FetchState(day: today, blockedAt: blockedAt);

  /// What the app shows for the site at [now]: requests used today (UTC)
  /// and until when it is paused after a block.
  Map<String, Object?> report(FetchPolicy policy, DateTime now) {
    final utc = now.toUtc();
    final until = blockedAt?.add(policy.cooldownAfterBlock);
    return {
      'requests_today': day == utc.toIso8601String().substring(0, 10)
          ? requests
          : 0,
      'paused_until': until != null && until.isAfter(utc)
          ? until.toUtc().toIso8601String()
          : null,
    };
  }
}

/// The state a site's fetcher saved at [path]; null when there is none or
/// it is damaged (the fetcher then starts a fresh one).
Future<FetchState?> readFetchState(String path) async {
  final file = File(path);
  try {
    if (await file.exists()) {
      return FetchState.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    }
  } on Object {
    // A damaged state file is treated as a fresh one.
  }
  return null;
}

/// One website we fetch from: where we may go, how a normal page looks, and
/// where its request count is kept. Each site has its own budget.
class FetchSite {
  const FetchSite({
    required this.host,
    required this.pathPrefix,
    required this.pageMarker,
    required this.statePath,
  });

  static const standvirtual = FetchSite(
    host: 'www.standvirtual.com',
    pathPrefix: '/motos/',
    pageMarker: '__NEXT_DATA__',
    statePath: '.fetch_state.json',
  );

  static const olx = FetchSite(
    host: 'www.olx.pt',
    pathPrefix: '/carros-motos-e-barcos/motociclos-scooters/',
    pageMarker: '__PRERENDERED_STATE__',
    statePath: '.fetch_state.olx.json',
  );

  static const byName = {'standvirtual': standvirtual, 'olx': olx};

  final String host;

  /// Only pages under this path are fetched (motorcycles only).
  final String pathPrefix;

  /// Text every normal page holds; without it the page is treated as a
  /// block or verification page.
  final String pageMarker;
  final String statePath;
}

/// Null when the address may be fetched, otherwise why not.
String? urlProblem(Uri url, {required FetchSite site}) {
  if (url.scheme != 'https') return 'only https addresses are allowed';
  if (url.host != site.host) {
    return 'only ${site.host} is allowed (got ${url.host})';
  }
  if (url.userInfo.isNotEmpty) return 'addresses with credentials are refused';
  if (!url.path.startsWith(site.pathPrefix)) {
    return 'only ${site.pathPrefix} pages are allowed (got ${url.path})';
  }
  return null;
}

/// A deliberately slow, one-at-a-time, honest downloader for one website.
class PoliteFetcher {
  PoliteFetcher({
    required this.site,
    this.userAgent = 'MotorcycleDealTracker/0.1 (personal project, low volume)',
    this.policy = const FetchPolicy(),
  });

  final FetchSite site;
  final String userAgent;
  final FetchPolicy policy;

  final _random = Random();
  late final HttpClient _client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = policy.timeout;

  late FetchState _state;
  late RobotsRules _robots;
  var _runRequests = 0;
  DateTime? _startedAt;

  /// Requests sent in this run, robots.txt included.
  int get requestsThisRun => _runRequests;

  /// When the previous request of this run finished.
  DateTime? _lastRequestAt;

  static String _today() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  /// Checks the pause after a block, loads robots.txt. Call before [get].
  Future<void> prepare() async {
    _startedAt = DateTime.now();
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

    final robots = await _request(Uri.https(site.host, '/robots.txt'));
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
      final problem = urlProblem(current, site: site);
      if (problem != null) throw FetchRefused('$current: $problem');
      final target =
          current.path + (current.hasQuery ? '?${current.query}' : '');
      if (!_robots.isAllowed(target)) {
        throw FetchRefused('$current: disallowed by robots.txt');
      }

      final response = await _request(current);
      final status = response.status;

      if (status == 200) {
        if (!response.body.contains(site.pageMarker)) {
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
    final perRun = policy.maxRequestsPerRun;
    if (perRun != null && _runRequests >= perRun) {
      throw FetchLimitReached('run limit of $perRun requests reached');
    }
    final perDay = policy.maxRequestsPerDay;
    if (perDay != null && _state.requests >= perDay) {
      throw FetchLimitReached('daily limit of $perDay requests reached');
    }
    final runTime = policy.maxRunTime;
    final started = _startedAt;
    if (runTime != null &&
        started != null &&
        DateTime.now().difference(started) >= runTime) {
      throw FetchLimitReached('run time of ${runTime.inMinutes} min reached');
    }
    // The pause runs from the end of the previous request, so time spent in
    // between (parsing, storing) counts towards it.
    final last = _lastRequestAt;
    if (last != null) {
      final extra = _random.nextInt(policy.jitter.inMilliseconds + 1);
      final pause = policy.minDelay + Duration(milliseconds: extra);
      final rest = pause - DateTime.now().difference(last);
      if (rest > Duration.zero) await Future<void>.delayed(rest);
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
          .timeout(policy.readTimeout);

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
    } on TlsException catch (e) {
      throw FetchFailed('$url: ${e.message}');
    } on HttpException catch (e) {
      // e.g. the connection closed while the page was coming in.
      throw FetchFailed('$url: ${e.message}');
    } finally {
      _lastRequestAt = DateTime.now();
    }
  }

  Future<void> _markBlocked() async {
    _state.blockedAt = DateTime.now().toUtc();
    await _saveState();
  }

  Future<FetchState> _loadState() async {
    final saved = await readFetchState(site.statePath);
    if (saved != null) return saved;
    if (await File(site.statePath).exists()) {
      // Damaged (it is written whole, so this is rare): today's count starts
      // again. A block it held is not lost for long: a site still pushing
      // back refuses robots.txt, the first request, and the pause restarts.
      stderr.writeln('${site.statePath} was damaged; starting a fresh one.');
    }
    return FetchState(day: _today());
  }

  /// Written to a temporary file and renamed over the old one, so a run
  /// stopped halfway never leaves a damaged file.
  Future<void> _saveState() async {
    final temp = File('${site.statePath}.tmp');
    await temp.writeAsString(jsonEncode(_state.toJson()), flush: true);
    await temp.rename(site.statePath);
  }

  void close() => _client.close(force: true);
}

/// `/motos/yamaha/mt-07?x=1` -> `motos-yamaha-mt-07-x-1.html`. A long
/// address is cut and gets a hash of the whole address, so two pages of one
/// search never share a name.
String fileNameFor(Uri url) {
  final raw = '${url.path}${url.hasQuery ? '?${url.query}' : ''}'.toLowerCase();
  final slug = raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length <= 150) return '$slug.html';
  return '${slug.substring(0, 140)}-${_fnv1a(raw)}.html';
}

/// FNV-1a, 32 bits: stable across runs, unlike [String.hashCode].
String _fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
