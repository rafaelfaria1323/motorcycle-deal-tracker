import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';

import 'robots.dart';

/// We decided not to fetch this (our own rules said no). Nothing was sent.
class const FetchRefused(final String reason) implements Exception {
  @override
  String toString() => reason;
}

/// The run reached a limit it was given (its time, or a request cap asked
/// for by hand). What was fetched so far is fine to use; the rest waits for
/// a later run.
class const FetchLimitReached(super.reason) extends FetchRefused;

/// The site's robots.txt does not allow this address.
class const FetchDisallowed(super.reason) extends FetchRefused;

/// The site pushed back. Stop, and do not try again soon.
class const FetchBlocked(final String reason) implements Exception {
  @override
  String toString() => reason;
}

/// A network or HTTP problem that is not a block.
class const FetchFailed(final String reason, {final int? statusCode})
    implements Exception {
  @override
  String toString() => reason;
}

class const FetchPolicy({
  final Duration minDelay = const Duration(seconds: 6),
  final Duration jitter = const Duration(seconds: 4),

  /// Request caps; none by default (Rafael, 2026-10-22: the counts are
  /// recorded and shown in the app instead). Set for tests and by hand
  /// (`fetch.dart --max`).
  final int? maxRequestsPerRun,
  final int? maxRequestsPerDay,

  /// How long one run may keep sending requests to the site, from
  /// [PoliteFetcher.prepare]: keeps a long backlog (e.g. listing pages
  /// still to read) inside the job's time; the rest waits for the next run.
  final Duration? maxRunTime = const Duration(minutes: 30),

  /// For connecting and the response's headers. OLX answers in 1-2 s, but
  /// three runs (2026-10-24 to 26) lost a search when it sent no headers
  /// within 20 s; a longer wait costs nothing when it answers.
  final Duration timeout = const Duration(seconds: 45),

  /// For reading the page once it is coming in: OLX's pages are 2 MB, and
  /// one took longer than [timeout] on a slow runner (it adds no request).
  final Duration readTimeout = const Duration(seconds: 60),

  /// The wait before a page's one retry, after a timeout, a dropped
  /// connection or HTTP 500/502/504 (Rafael, 2026-10-27: passing errors
  /// lost whole searches). Blocks (403/429/503) and pages that aren't
  /// normal are never retried; a second failure stops the run as before.
  /// Null: no retry (tests, by hand).
  final Duration? retryDelay = const Duration(seconds: 60),
  final Duration cooldownAfterBlock = const Duration(hours: 24),

  /// How long a robots.txt read is kept (in the state file, across runs)
  /// before it is read again. RFC 9309 asks crawlers not to keep one
  /// longer than 24 hours; Rafael, 2026-10-22: once a day, not every run.
  final Duration robotsMaxAge = const Duration(hours: 24),
});

/// What survives between runs: today's request count, the last block, the
/// site's robots.txt as last read and when each search was last read in
/// full.
class FetchState({
  required var String day,
  var int requests = 0,
  var DateTime? blockedAt,
  var String? robots,
  var DateTime? robotsReadAt,
  Map<String, DateTime>? fullReads,
}) {
  factory FetchState.fromJson(Map<String, dynamic> json) => FetchState(
    day: json['day'] as String,
    requests: json['requests'] as int,
    blockedAt: _time(json['blocked_at']),
    robots: json['robots'] as String?,
    robotsReadAt: _time(json['robots_read_at']),
    fullReads: {
      for (final MapEntry(:key, :value)
          in (json['full_reads'] as Map<String, dynamic>? ?? const {}).entries)
        key: DateTime.parse(value as String),
    },
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Search address -> when every page of it was last saved (R.2: a light
  /// run reads only what is newer).
  final Map<String, DateTime> fullReads = fullReads ?? {};

  Map<String, dynamic> toJson() => {
    'day': day,
    'requests': requests,
    'blocked_at': blockedAt?.toUtc().toIso8601String(),
    'robots': robots,
    'robots_read_at': robotsReadAt?.toUtc().toIso8601String(),
    'full_reads': {
      for (final MapEntry(:key, :value) in fullReads.entries)
        key: value.toUtc().toIso8601String(),
    },
  };

  /// The count restarts each day; a block and robots.txt are remembered.
  FetchState rolledTo(String today) => day == today
      ? this
      : FetchState(
          day: today,
          blockedAt: blockedAt,
          robots: robots,
          robotsReadAt: robotsReadAt,
          fullReads: fullReads,
        );

  /// The robots.txt kept from an earlier read while younger than [maxAge]
  /// at [now]; null when it must be read again (none kept, too old, or
  /// read "in the future" by a clock that moved).
  String? keptRobots(Duration maxAge, DateTime now) {
    final readAt = robotsReadAt;
    if (readAt == null) return null;
    final age = now.toUtc().difference(readAt);
    return age.isNegative || age >= maxAge ? null : robots;
  }

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
class const FetchSite({
  required final String host,

  /// Only pages under this path are fetched (motorcycles only).
  required final String pathPrefix,

  /// Text every normal page holds; without it the page is treated as a
  /// block or verification page.
  required final String pageMarker,
  required final String statePath,

  /// The Accept header of every request.
  final String accept = 'text/html,application/xhtml+xml',

  /// False: robots.txt answered with 4xx means no rules (RFC 9309); the
  /// sites' pages are never fetched without one.
  final bool robotsRequired = true,
}) {
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

  /// The listings' photos (both sites keep them there): only the addresses
  /// the listings give, read by [PoliteFetcher.getImage]. A photo server's
  /// missing robots.txt (4xx) allows everything (RFC 9309).
  static const photos = FetchSite(
    host: 'ireland.apollo.olxcdn.com',
    pathPrefix: '/v1/files/',
    pageMarker: '',
    statePath: '.fetch_state.photos.json',
    accept: 'image/jpeg,image/webp,image/png',
    robotsRequired: false,
  );

  static const byName = {'standvirtual': standvirtual, 'olx': olx};
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

typedef _Response = ({
  int status,
  List<int> body,
  String? location,
  String? contentType,
});

/// A deliberately slow, one-at-a-time, honest downloader for one website.
class PoliteFetcher({
  required final FetchSite site,
  final String userAgent =
      'MotorcycleDealTracker/0.1 (personal project, low volume)',
  final FetchPolicy policy = const FetchPolicy(),
}) {
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
      clock.now().toUtc().toIso8601String().substring(0, 10);

  /// When the robots.txt in use was read: in this run, or by an earlier one
  /// less than [FetchPolicy.robotsMaxAge] ago. Known after [prepare].
  DateTime? get robotsReadAt => _state.robotsReadAt;

  /// When every page of [search] was last saved, by this run or one before.
  DateTime? fullReadAt(Uri search) => _state.fullReads['$search'];

  /// Records that every page of [search] was saved just now. Searches not
  /// read in full for a week (no model follows them any more) are dropped.
  Future<void> markFullRead(Uri search) async {
    final now = clock.now().toUtc();
    _state.fullReads
      ..removeWhere((_, at) => now.difference(at) > const Duration(days: 7))
      ..['$search'] = now;
    await _saveState();
  }

  /// Checks the pause after a block, loads robots.txt (the one kept in the
  /// state file while it is fresh, else from the site). Call before [get].
  Future<void> prepare() async {
    _startedAt = clock.now();
    _state = (await _loadState()).rolledTo(_today());

    final blocked = _state.blockedAt;
    if (blocked != null) {
      final until = blocked.add(policy.cooldownAfterBlock);
      if (clock.now().toUtc().isBefore(until)) {
        throw FetchRefused(
          'paused until ${until.toIso8601String()} because the site pushed '
          'back on ${blocked.toIso8601String()}; not retrying sooner',
        );
      }
      _state.blockedAt = null;
    }

    final kept = _state.keptRobots(policy.robotsMaxAge, clock.now());
    if (kept != null) {
      _robots = RobotsRules.parse(kept);
      return;
    }
    final robots = await _request(Uri.https(site.host, '/robots.txt'));
    final unavailable = robots.status >= 400 && robots.status < 500;
    if (!site.robotsRequired && unavailable) {
      _robots = RobotsRules.parse('');
      _state
        ..robots = ''
        ..robotsReadAt = clock.now().toUtc();
      await _saveState();
      return;
    }
    if (robots.status != 200) {
      throw FetchRefused(
        'could not read robots.txt (HTTP ${robots.status}); '
        'not fetching without it',
      );
    }
    final rules = utf8.decode(robots.body, allowMalformed: true);
    _robots = RobotsRules.parse(rules);
    _state
      ..robots = rules
      ..robotsReadAt = clock.now().toUtc();
    await _saveState();
  }

  /// Downloads one page and returns its HTML.
  Future<String> get(Uri url) async {
    var text = '';
    await _fetch(url, (response) {
      text = utf8.decode(response.body, allowMalformed: true);
      return text.contains(site.pageMarker);
    });
    return text;
  }

  /// Downloads one photo and returns its bytes. A 200 that isn't an image
  /// is treated as a block page, like a page without its marker.
  Future<List<int>> getImage(Uri url) => _fetch(
    url,
    (response) =>
        response.contentType?.trim().toLowerCase().startsWith('image/') ??
        false,
  );

  Future<List<int>> _fetch(Uri url, bool Function(_Response) isNormal) async {
    var current = url;
    for (var hop = 0; hop <= 3; hop++) {
      final problem = urlProblem(current, site: site);
      if (problem != null) throw FetchRefused('$current: $problem');
      final target =
          current.path + (current.hasQuery ? '?${current.query}' : '');
      if (!_robots.isAllowed(target)) {
        throw FetchDisallowed(
          '$current: disallowed by robots.txt '
          '(${_robots.decidingRule(target)})',
        );
      }

      final response = await _requestOnceMore(current);
      final status = response.status;

      if (status == 200) {
        if (!isNormal(response)) {
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
      throw FetchFailed('$current: HTTP $status', statusCode: status);
    }
    throw FetchFailed('$url: too many redirects');
  }

  /// HTTP statuses of a passing server error, worth one retry.
  static const _retryStatuses = {500, 502, 504};

  /// [_request], and once more after [FetchPolicy.retryDelay] when it timed
  /// out, the connection failed or the server had a passing error. The
  /// retry is a request like any other (counted, never in parallel).
  Future<_Response> _requestOnceMore(Uri url) async {
    final delay = policy.retryDelay;
    if (delay == null) return _request(url);
    FetchFailed first;
    try {
      final response = await _request(url);
      if (!_retryStatuses.contains(response.status)) return response;
      first = FetchFailed(
        '$url: HTTP ${response.status}',
        statusCode: response.status,
      );
    } on FetchFailed catch (e) {
      first = e;
    }
    stdout.writeln('Retrying once in ${delay.inSeconds} s: $first');
    await Future<void>.delayed(delay);
    try {
      return await _request(url);
    } on FetchLimitReached {
      // The run's time ran out meanwhile: the page is still lost.
      throw first;
    }
  }

  Future<_Response> _request(Uri url) async {
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
        clock.now().difference(started) >= runTime) {
      throw FetchLimitReached('run time of ${runTime.inMinutes} min reached');
    }
    // The pause runs from the end of the previous request, so time spent in
    // between (parsing, storing) counts towards it.
    final last = _lastRequestAt;
    if (last != null) {
      final extra = _random.nextInt(policy.jitter.inMilliseconds + 1);
      final pause = policy.minDelay + Duration(milliseconds: extra);
      final rest = pause - clock.now().difference(last);
      if (rest > Duration.zero) await Future<void>.delayed(rest);
    }
    _runRequests++;
    _state.requests++;
    await _saveState();

    HttpClientRequest? request;
    HttpClientResponse? response;
    StreamSubscription<List<int>>? subscription;
    try {
      request = await _client.getUrl(url).timeout(policy.timeout);
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.acceptHeader, site.accept)
        ..set(HttpHeaders.acceptLanguageHeader, 'pt-PT,pt;q=0.9');
      response = await request.close().timeout(policy.timeout);

      final body = BytesBuilder(copy: false);
      if (response.statusCode == 200) {
        subscription = response.listen(body.add);
        await subscription.asFuture<void>().timeout(policy.readTimeout);
        subscription = null;
      } else {
        try {
          if ({403, 429, 503}.contains(response.statusCode)) {
            await _markBlocked();
            throw FetchBlocked('$url: HTTP ${response.statusCode}');
          }
        } finally {
          await response.listen(null).cancel();
        }
      }
      return (
        status: response.statusCode,
        body: body.takeBytes(),
        location: response.headers.value(HttpHeaders.locationHeader),
        contentType: response.headers.value(HttpHeaders.contentTypeHeader),
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
      if (response == null) request?.abort();
      if (subscription != null) await subscription.cancel();
      _lastRequestAt = clock.now();
    }
  }

  /// After the pause, the first run reads robots.txt again.
  Future<void> _markBlocked() async {
    _state
      ..blockedAt = clock.now().toUtc()
      ..robots = null
      ..robotsReadAt = null;
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
