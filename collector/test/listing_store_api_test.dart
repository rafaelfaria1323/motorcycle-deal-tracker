import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A request the store made to the stand-in API.
typedef _Call = ({
  String method,
  String name,
  Map<String, String> query,
  Object? body,
});

/// The arguments of the SQL function [name] as the latest migration that
/// defines it declares them: name to whether it has a default.
typedef _Args = Map<String, bool>;

/// Every `public.` function the migrations define, by name, with the
/// arguments of its latest definition (files sort in the order applied).
Map<String, _Args> _functionsInMigrations() {
  final files =
      Directory('../supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final header = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(',
    caseSensitive: false,
  );
  final functions = <String, _Args>{};
  for (final file in files) {
    // Comments could hold a stray parenthesis or comma.
    final sql = file.readAsStringSync().replaceAll(RegExp('--[^\n]*'), '');
    for (final match in header.allMatches(sql)) {
      var depth = 1;
      var i = match.end;
      final args = <String>[];
      var start = i;
      for (; depth > 0; i++) {
        final c = sql[i];
        if (c == '(') depth++;
        if (c == ')') depth--;
        if ((c == ',' && depth == 1) || depth == 0) {
          args.add(sql.substring(start, i).trim());
          start = i + 1;
        }
      }
      functions[match.group(1)!] = {
        for (final arg in args)
          if (arg.isNotEmpty)
            arg.split(RegExp(r'\s+')).first: RegExp(
              r'\sdefault\s|=',
              caseSensitive: false,
            ).hasMatch(arg),
      };
    }
  }
  return functions;
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late ListingStore store;
  late List<_Call> calls;
  // What each RPC answers; the others answer a count.
  late Map<String, Object?> replies;

  setUp(() async {
    calls = [];
    replies = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      final text = await utf8.decodeStream(request);
      final rpc = path.startsWith('/rest/v1/rpc/');
      final name = path.split('/').last;
      calls.add((
        method: request.method,
        name: rpc ? 'rpc:$name' : name,
        query: request.uri.queryParameters,
        body: text.isEmpty ? null : jsonDecode(text),
      ));
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(rpc ? replies[name] ?? 1 : const []));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    store = ListingStore(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  /// Calls every RPC of the store once, with small inputs.
  Future<void> callEveryRpc() async {
    final listing = testListing('a', motorcycleSlug: 'yamaha-mt-07');
    final catalog = Catalog([
      for (final e in [mt07Entry])
        CatalogEntry(
          slug: e.slug,
          brand: e.brand,
          model: e.model,
          minYear: e.minYear,
          id: 'mt07',
        ),
    ]);
    for (final name in [
      'listings_missing_details',
      'listings_missing_photo_checks',
      'listings_awaiting_photo_exam',
      'photo_training_set',
      'pending_notifications',
      'push_keys',
      'answer_bike_value_requests',
    ]) {
      replies[name] = const [];
    }
    await store.listingsMissingDetails('standvirtual', 5);
    await store.applyDetails('standvirtual', [
      const ListingDetails(sourceListingId: 'a', description: 'x'),
    ]);
    await store.markDetailsFailed('standvirtual', ['a']);
    await store.listingsMissingPhotoChecks(5, examine: true);
    await store.listingsAwaitingPhotoExam(3);
    await store.finishPhotoExams(['id']);
    await store.storePhotoHashes([
      (id: 'id', hashes: [1]),
    ]);
    await store.storePhotoFeatures('clip', [
      (
        id: 'id',
        photos: [
          (photo: 0, examination: (scores: {'ok': 1.0}, features: 'AA==')),
        ],
      ),
    ]);
    await store.photoTrainingSet('clip');
    await store.storePhotoClassifier(
      'clip',
      const PhotoClassifier(
        weights: [0.5],
        bias: 0,
        samples: 20,
        problems: 10,
        accuracy: null,
      ),
      marksKey: 'k',
    );
    await store.recalculateScores();
    await store.markDuplicates();
    await store.markSeen('olx', ['a']);
    await store.applyPriceChanges('olx', [listing]);
    await store.rematch('olx', [listing], catalog);
    await store.markRemoved('olx', ['a'], searches: ['s']);
    await store.applyListingDates('olx', [
      NormalizedListing(
        source: 'olx',
        sourceListingId: 'a',
        url: 'https://example.com/a',
        brand: 'Yamaha',
        model: 'MT-07',
        price: 7000,
        sellerType: SellerType.private,
        images: const [],
        publishedAt: DateTime.utc(2026, 10),
      ),
    ]);
    await store.setSearchKeys('olx', {'a': 's'});
    await store.generateAlerts();
    await store.pendingNotifications(limit: 5, at: DateTime.utc(2026, 10, 29));
    await store.storeServiceAccess('https://x.supabase.co', 'key');
    await store.pushKeys();
    await store.answerBikeValues(DateTime.utc(2026, 10, 28));
    await store.markNotified(['alert']);
  }

  test('every RPC the store calls exists with those arguments', () async {
    await callEveryRpc();
    final functions = _functionsInMigrations();
    final rpcs = calls.where((c) => c.name.startsWith('rpc:')).toList();
    expect(rpcs, hasLength(greaterThanOrEqualTo(25)));
    for (final call in rpcs) {
      final name = call.name.substring(4);
      final declared = functions[name];
      expect(declared, isNotNull, reason: 'no migration defines $name');
      final sent = (call.body as Map<String, dynamic>? ?? const {}).keys
          .toSet();
      expect(
        sent.difference(declared!.keys.toSet()),
        isEmpty,
        reason: '$name has no such argument',
      );
      final required = {
        for (final e in declared.entries)
          if (!e.value) e.key,
      };
      expect(
        required.difference(sent),
        isEmpty,
        reason: '$name needs these arguments',
      );
    }
  });

  test('the store sends what the functions read', () async {
    await callEveryRpc();
    Object? bodyOf(String rpc) =>
        calls.firstWhere((c) => c.name == 'rpc:$rpc').body;

    expect(bodyOf('mark_removed_listings'), {
      'p_source': 'olx',
      'p_seen_ids': ['a'],
      'p_max_fraction': 0.5,
      'p_search_keys': ['s'],
      'p_include_unkeyed': true,
    });
    expect(bodyOf('rematch_listings'), {
      'p_source': 'olx',
      'p_matches': {
        'a': {'motorcycle_id': 'mt07', 'brand': 'Yamaha', 'model': 'MT-07'},
      },
    });
    // Hashes as decimal text: JSON numbers would lose the low bits.
    expect(bodyOf('store_photo_hashes'), {
      'p_listings': [
        {
          'id': 'id',
          'hashes': ['1'],
        },
      ],
    });
    expect(bodyOf('apply_listing_dates'), {
      'p_source': 'olx',
      'p_dates': {
        'a': {
          'published_at': '2026-10-01T00:00:00.000Z',
          'site_refreshed_at': null,
        },
      },
    });
    expect(bodyOf('apply_price_updates'), {
      'p_source': 'olx',
      'p_prices': {'a': 7000.0},
    });
    // No stored keys: a pair is made, stored, and read back.
    expect(calls.map((c) => c.name).where((n) => n.contains('push_keys')), [
      'rpc:push_keys',
      'rpc:store_push_keys',
      'rpc:push_keys',
    ]);
  });

  test('empty inputs send nothing', () async {
    expect(await store.applyDetails('olx', const []), 0);
    expect(await store.markDetailsFailed('olx', const []), 0);
    expect(await store.finishPhotoExams(const []), 0);
    expect(await store.storePhotoHashes(const []), 0);
    expect(await store.storePhotoFeatures('clip', const []), 0);
    expect(await store.markSeen('olx', const []), 0);
    expect(await store.applyPriceChanges('olx', const []), 0);
    expect(await store.applyPricesBeforeDrop('olx', [testListing('a')]), 0);
    expect(await store.rematch('olx', const [], const Catalog([])), 0);
    expect(await store.applyListingDates('olx', [testListing('a')]), 0);
    expect(await store.setSearchKeys('olx', const {}), 0);
    expect(await store.markNotified(const []), 0);
    await store.forgetPushTargets(const []);
    await store.markPushTargetsUsed(const []);
    expect(await store.summaryListings(const {}, DateTime.utc(2026)), isEmpty);
    expect(calls, isEmpty);
  });

  test('table reads ask for the rows they parse', () async {
    await store.followedModels();
    await store.pushTargets();
    await store.adminIds();
    await store.lastWorkflowStarter('collect.yml', DateTime.utc(2026));
    await store.accountLanguages(['u1', 'u1', 'u2']);
    await store.sampleListing(null);
    await store.summaryListings({'mt07': 'Yamaha MT-07'}, DateTime.utc(2026));
    await store.forgetPushTargets(['e']);
    await store.markPushTargetsUsed(['e']);

    final byTable = {for (final c in calls) c.name: c};
    expect(byTable['user_models']!.query['tracked'], 'eq.true');
    expect(byTable['app_admins']!.query['select'], 'user_id');
    expect(byTable['account_languages']!.query['user_id'], 'in.("u1","u2")');
    expect(byTable['listings']!.query['duplicate_of'], 'is.null');
    expect(
      calls.where((c) => c.name == 'push_subscriptions').map((c) => c.method),
      ['GET', 'DELETE', 'PATCH'],
    );
    expect(calls.last.query['endpoint'], 'in.("e")');
    final functions = _functionsInMigrations();
    // Every table read is a real table (or view) of the migrations.
    final migrations = Directory(
      '../supabase/migrations',
    ).listSync().whereType<File>().map((f) => f.readAsStringSync()).join('\n');
    for (final table in byTable.keys) {
      expect(
        RegExp(
          '(table|view)\\s+(if not exists\\s+)?public\\.$table\\b',
        ).hasMatch(migrations),
        isTrue,
        reason: 'no table $table',
      );
    }
    expect(functions, isNotEmpty);
  });

  test('every RPC named in the collector is a function of the migrations', () {
    final functions = _functionsInMigrations();
    final named = RegExp(r"\.rpc(?:<[\w<>?, ]*>)?\(\s*'(\w+)'");
    final names = {
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final m in named.allMatches(file.readAsStringSync()))
            m.group(1)!,
    };
    expect(names, hasLength(greaterThanOrEqualTo(25)));
    expect(names.difference(functions.keys.toSet()), isEmpty);
  });
}
