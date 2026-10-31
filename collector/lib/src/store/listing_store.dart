import 'package:supabase/supabase.dart';

import '../../collector.dart';

class const StoreResult({
  required final int inserted,
  required final int alreadyStored,
  required final int duplicatesInInput,
});

/// Keeps the first listing for each (source, source id).
List<NormalizedListing> uniqueBySourceId(List<NormalizedListing> listings) {
  final seen = <String>{};
  return [
    for (final l in listings)
      if (seen.add('${l.source}|${l.sourceListingId}')) l,
  ];
}

/// Every row of a query, read [pageSize] rows at a time: the server returns
/// at most that many per request (PostgREST `max_rows`), without saying it
/// cut the rest. [page] reads rows [from] to [to] (inclusive) of a query
/// with a stable order.
Future<List<Map<String, dynamic>>> readAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page, {
  int pageSize = 1000,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var from = 0; ; from += pageSize) {
    final batch = await page(from, from + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) return rows;
  }
}

/// One `listings` row. Columns with database defaults (status, timestamps)
/// and the scores are left out on purpose.
Map<String, Object?> listingRow(NormalizedListing l, String? motorcycleId) {
  return {
    'source': l.source,
    'source_listing_id': l.sourceListingId,
    'url': l.url,
    'motorcycle_id': motorcycleId,
    'brand': l.brand,
    'model': l.model,
    'variant': l.variant,
    'year': l.year,
    'mileage': l.mileage,
    'price': l.price,
    'price_before_drop': l.priceBeforeDrop,
    'seller_type': l.sellerType.name,
    'seller_name': l.sellerName,
    'location': l.location,
    'description': l.description,
    'images': l.images,
  };
}

/// The database id of each catalog entry that has one, by slug.
Map<String, String> _idBySlug(Catalog catalog) => {
  for (final e in catalog.entries)
    if (e.id != null) e.slug: e.id!,
};

/// The database id of [l]'s catalog model; null when it has no model or the
/// catalog entry has no id.
String? motorcycleIdFor(NormalizedListing l, Map<String, String> idBySlug) {
  final slug = l.motorcycleSlug;
  return slug == null ? null : idBySlug[slug];
}

/// The row count a counting RPC returns.
int _count(Object? rpcResult) => (rpcResult as num).toInt();

class ListingStore(final SupabaseClient _client) {
  /// Live listings of [source] whose listing page has not been read yet,
  /// then those read before the page's photos were kept (`photos_read_at`),
  /// pages that failed before last. Within each, what matters first:
  /// favourites, alerted listings, then by Deal Score (unscored first),
  /// newest first (`listings_missing_details`, R.5), so what waits for the
  /// next run when time runs out is what matters least. Only catalog models
  /// that are not duplicates: details feed the scores, and other listings
  /// are never scored. All of them without a [limit] (the API still
  /// returns at most 1000).
  Future<List<({String sourceListingId, String url})>> listingsMissingDetails(
    String source,
    int? limit,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'listings_missing_details',
      params: {'p_source': source, 'p_limit': limit},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          sourceListingId: r['source_listing_id'] as String,
          url: r['url'] as String,
        ),
    ];
  }

  /// Saves what listing pages added; returns how many listings were updated.
  Future<int> applyDetails(String source, List<ListingDetails> details) async {
    if (details.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'apply_listing_details',
      params: {
        'p_source': source,
        'p_details': [for (final d in details) d.toJson()],
      },
    );
    return _count(result);
  }

  /// Marks listings whose page could not be read, so the next runs try the
  /// others first; returns how many were marked.
  Future<int> markDetailsFailed(String source, List<String> ids) async {
    if (ids.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_details_failed',
      params: {'p_source': source, 'p_ids': ids},
    );
    return _count(result);
  }

  /// Live listings whose first photos have not been fingerprinted yet, or,
  /// with [examine], not shown to the image model yet either
  /// (`listings_missing_photo_checks`): followed models, not duplicates
  /// first, Standvirtual only once its listing page gave the photos; never
  /// fingerprinted first, then newest first. Each with its first
  /// [photosPerListing] addresses.
  Future<List<({String id, List<String> images})>> listingsMissingPhotoChecks(
    int? limit, {
    required bool examine,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'listings_missing_photo_checks',
      params: {
        'p_limit': limit,
        'p_photos': photosPerListing,
        'p_examine': examine,
      },
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          id: r['id'] as String,
          images: (r['images'] as List<dynamic>).cast<String>(),
        ),
    ];
  }

  /// Live listings someone asked to have every photo examined (P.4,
  /// `listings_awaiting_photo_exam`), oldest request first, each with up
  /// to [photosPerExam] addresses.
  Future<List<({String id, List<String> images})>> listingsAwaitingPhotoExam(
    int limit,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'listings_awaiting_photo_exam',
      params: {'p_limit': limit, 'p_photos': photosPerExam},
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          id: r['id'] as String,
          images: (r['images'] as List<dynamic>).cast<String>(),
        ),
    ];
  }

  /// Marks the examination of every photo of [ids] done (P.4); returns how
  /// many were waiting for it.
  Future<int> finishPhotoExams(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'finish_photo_exams',
      params: {'p_listings': ids},
    );
    return _count(result);
  }

  /// Who asked for every photo of [ids] examined, for those now done
  /// (`photo_exam_answers`).
  Future<List<PhotoExamAnswer>> photoExamAnswers(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.rpc<List<dynamic>>(
      'photo_exam_answers',
      params: {'p_listings': ids},
    );
    return [
      for (final row in rows)
        PhotoExamAnswer.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// Stores each listing's photo hashes (64-bit dHash, sent as decimal text:
  /// JSON numbers lose the low bits) and finds the listings sharing them;
  /// returns how many listings were stored.
  Future<int> storePhotoHashes(
    List<({String id, List<int> hashes})> listings,
  ) async {
    if (listings.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'store_photo_hashes',
      params: {
        'p_listings': [
          for (final l in listings)
            {
              'id': l.id,
              'hashes': [for (final h in l.hashes) h.toString()],
            },
        ],
      },
    );
    return _count(result);
  }

  /// Stores what [model] saw in each listing's photos (P.2) and the hints
  /// the database draws from it (`store_photo_features`); a listing with no
  /// photo examined still counts as done. Returns how many were stored.
  Future<int> storePhotoFeatures(
    String model,
    List<({String id, List<PhotoFeatures> photos})> listings,
  ) async {
    if (listings.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'store_photo_features',
      params: {
        'p_model': model,
        'p_listings': [
          for (final l in listings)
            {
              'id': l.id,
              'photos': [
                for (final p in l.photos)
                  {
                    'photo': p.photo,
                    'scores': p.examination.scores,
                    'features': p.examination.features,
                  },
              ],
            },
        ],
      },
    );
    return _count(result);
  }

  /// The admins' photo marks for [model] to learn from (P.3), with the
  /// marks' state now and the state the stored classifier learned from.
  Future<PhotoTrainingSet> photoTrainingSet(String model) async {
    final rows = (await _client.rpc<List<dynamic>>(
      'photo_training_set',
      params: {'p_model': model},
    )).cast<Map<String, dynamic>>();
    return (
      samples: [
        for (final r in rows)
          if (r['features'] case final String features)
            (
              features: featuresFromBase64(features),
              problem: r['problem'] as bool,
            ),
      ],
      marksKey: rows.isEmpty ? '' : rows.first['marks_key'] as String,
      trainedKey: rows.isEmpty ? null : rows.first['trained_key'] as String?,
    );
  }

  /// Stores [model]'s [classifier], trained on the marks' state
  /// [marksKey]; the database refreshes the hints of every listing examined
  /// with that model and returns how many.
  Future<int> storePhotoClassifier(
    String model,
    PhotoClassifier classifier, {
    required String marksKey,
  }) async {
    final result = await _client.rpc<Object?>(
      'store_photo_classifier',
      params: {
        'p_model': model,
        'p_weights': classifier.weights,
        'p_bias': classifier.bias,
        'p_samples': classifier.samples,
        'p_problems': classifier.problems,
        'p_accuracy': classifier.accuracy,
        'p_marks_key': marksKey,
      },
    );
    return _count(result);
  }

  /// Inserts listings that are not stored yet. Existing ones (same source and
  /// source id) are left untouched, so running the same file twice is safe.
  Future<StoreResult> save(
    List<NormalizedListing> listings,
    Catalog catalog,
  ) async {
    final unique = uniqueBySourceId(listings);
    final duplicates = listings.length - unique.length;
    if (unique.isEmpty) {
      return StoreResult(
        inserted: 0,
        alreadyStored: 0,
        duplicatesInInput: duplicates,
      );
    }

    final idBySlug = _idBySlug(catalog);

    final rows = <Map<String, Object?>>[];
    for (final l in unique) {
      final slug = l.motorcycleSlug;
      if (slug != null && !idBySlug.containsKey(slug)) {
        throw StateError(
          'Catalog entry "$slug" has no id; load the catalog from Supabase.',
        );
      }
      rows.add(listingRow(l, motorcycleIdFor(l, idBySlug)));
    }

    // Only the rows that were really inserted come back.
    final inserted = await _client
        .from('listings')
        .upsert(
          rows,
          onConflict: 'source,source_listing_id',
          ignoreDuplicates: true,
        )
        .select('id');

    return StoreResult(
      inserted: inserted.length,
      alreadyStored: unique.length - inserted.length,
      duplicatesInInput: duplicates,
    );
  }

  /// Stores the brands and models a site offers (for the app's model
  /// picker), updating the ones already stored. Returns how many.
  Future<int> saveSiteModels(String source, List<SiteModel> models) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = [
      for (final m in uniqueSiteModels(models))
        {...m.toRow(source), 'seen_at': now},
    ];
    for (var i = 0; i < rows.length; i += 500) {
      await _client
          .from('site_models')
          .upsert(
            rows.sublist(i, i + 500 > rows.length ? rows.length : i + 500),
            onConflict: 'source,make_id,model_id',
          );
    }
    return rows.length;
  }

  /// Recomputes the stored deal and risk scores (see `recalculate_deal_scores`).
  Future<int> recalculateScores() async {
    final result = await _client.rpc<Object?>('recalculate_deal_scores');
    return _count(result);
  }

  /// Flags likely duplicates (see `mark_duplicates`); returns how many.
  Future<int> markDuplicates() async {
    final result = await _client.rpc<Object?>('mark_duplicates');
    return _count(result);
  }

  /// Marks listings as seen now (updates last_seen_at); returns how many.
  Future<int> markSeen(String source, List<String> sourceListingIds) async {
    if (sourceListingIds.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_listings_seen',
      params: {'p_source': source, 'p_ids': sourceListingIds},
    );
    return _count(result);
  }

  /// Applies new prices to listings already stored; returns how many changed.
  Future<int> applyPriceChanges(
    String source,
    List<NormalizedListing> listings,
  ) async {
    if (listings.isEmpty) return 0;
    final prices = <String, num>{
      for (final l in listings) l.sourceListingId: l.price,
    };
    final result = await _client.rpc<Object?>(
      'apply_price_updates',
      params: {'p_source': source, 'p_prices': prices},
    );
    return _count(result);
  }

  /// Records what the source says the price was before its last cut (the
  /// database keeps the highest seen); returns how many changed.
  Future<int> applyPricesBeforeDrop(
    String source,
    List<NormalizedListing> listings,
  ) async {
    final prices = <String, num>{
      for (final l in listings) l.sourceListingId: ?l.priceBeforeDrop,
    };
    if (prices.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'apply_prices_before_drop',
      params: {'p_source': source, 'p_prices': prices},
    );
    return _count(result);
  }

  /// Re-checks the model of listings already stored: `save` never updates
  /// a stored row, so without this a wrong match made by an older rule
  /// would stay. Only listings whose model changes are touched; returns how
  /// many.
  Future<int> rematch(
    String source,
    List<NormalizedListing> listings,
    Catalog catalog,
  ) async {
    if (listings.isEmpty) return 0;
    final idBySlug = _idBySlug(catalog);
    final result = await _client.rpc<Object?>(
      'rematch_listings',
      params: {
        'p_source': source,
        'p_matches': {
          for (final l in listings)
            l.sourceListingId: {
              'motorcycle_id': motorcycleIdFor(l, idBySlug),
              'brand': l.brand,
              'model': l.model,
            },
        },
      },
    );
    return _count(result);
  }

  /// For a complete import: marks live listings missing from [seenIds] as
  /// removed. The database refuses empty or suspiciously large removals unless
  /// [force] is set. Returns how many were marked.
  Future<int> markRemoved(
    String source,
    List<String> seenIds, {
    bool force = false,
    List<String>? searches,
    bool includeUnkeyed = true,
  }) async {
    final result = await _client.rpc<Object?>(
      'mark_removed_listings',
      params: {
        'p_source': source,
        'p_seen_ids': seenIds,
        'p_max_fraction': force ? 1.0 : 0.5,
        'p_search_keys': searches,
        'p_include_unkeyed': includeUnkeyed,
      },
    );
    return _count(result);
  }

  /// Stores the publication and renewal dates the source shows; returns how
  /// many listings changed.
  Future<int> applyListingDates(
    String source,
    List<NormalizedListing> listings,
  ) async {
    final dates = <String, Map<String, String?>>{
      for (final l in listings)
        if (l.publishedAt != null || l.siteRefreshedAt != null)
          l.sourceListingId: {
            'published_at': l.publishedAt?.toIso8601String(),
            'site_refreshed_at': l.siteRefreshedAt?.toIso8601String(),
          },
    };
    if (dates.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'apply_listing_dates',
      params: {'p_source': source, 'p_dates': dates},
    );
    return _count(result);
  }

  /// Records the search each stored listing was found by; returns how many
  /// changed.
  Future<int> setSearchKeys(String source, Map<String, String> keys) async {
    if (keys.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'set_search_keys',
      params: {'p_source': source, 'p_keys': keys},
    );
    return _count(result);
  }

  /// Creates the alerts that are due (see `generate_alerts`); returns how many.
  Future<int> generateAlerts() async {
    final result = await _client.rpc<Object?>('generate_alerts');
    return _count(result);
  }

  /// Alerts of real accounts not pushed yet, oldest first. With [at],
  /// those of accounts in their quiet hours then are left out (they wait).
  Future<List<PendingAlert>> pendingNotifications({
    int limit = 20,
    DateTime? at,
  }) async {
    final rows = await _client.rpc<Object?>(
      'pending_notifications',
      params: {
        'p_limit': limit,
        if (at != null) 'p_at': at.toUtc().toIso8601String(),
      },
    ) as List<dynamic>;
    return [
      for (final row in rows) PendingAlert.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// Complete preferences for these recipients. Only an absent row means
  /// Portuguese; a failed lookup must leave notifications pending.
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async {
    final users = userIds.toSet().toList();
    final languages = {
      for (final user in users) user: NotificationLanguage.portuguese,
    };
    // Keep the filter below URL limits, even for a large summary batch.
    const batchSize = 100;
    for (var start = 0; start < users.length; start += batchSize) {
      final rows = await _client
          .from('account_languages')
          .select('user_id, language')
          .inFilter('user_id', users.skip(start).take(batchSize).toList());
      for (final row in rows) {
        languages[row['user_id'] as String] = NotificationLanguage.fromCode(
          row['language'] as String,
        );
      }
    }
    return languages;
  }

  /// For the weekly summary: listings of the models in [bikeNames] (id to
  /// name), not duplicates, that are live or were first seen or found
  /// missing since [since].
  Future<List<SummaryListing>> summaryListings(
    Map<String, String> bikeNames,
    DateTime since,
  ) async {
    if (bikeNames.isEmpty) return const [];
    final from = since.toUtc().toIso8601String();
    final rows = await readAllPages(
      (start, end) => _client
          .from('listings')
          .select(
            'id, motorcycle_id, brand, model, url, status, first_seen_at, '
            'last_checked_at, year, mileage, price, deal_score, risk_score',
          )
          .inFilter('motorcycle_id', bikeNames.keys.toList())
          .isFilter('duplicate_of', null)
          .or(
            'status.in.(active,price_changed),'
            'first_seen_at.gte."$from",last_checked_at.gte."$from"',
          )
          .order('id')
          .range(start, end),
    );
    return [for (final r in rows) SummaryListing.fromRow(r, bikeNames)];
  }

  /// The whole price history of those of [listingIds] whose price was
  /// recorded since [since] (a new price, or a new listing's first one).
  /// Only [listingIds]' rows are read, never the whole table's week.
  Future<List<PricePoint>> priceHistoryChangedSince(
    Set<String> listingIds,
    DateTime since,
  ) async {
    final from = since.toUtc().toIso8601String();
    final ids = <String>{};
    // A few ids per request keep the address short.
    for (final chunk in _chunksOf100(listingIds.toList()..sort())) {
      final recent = await readAllPages(
        (start, end) => _client
            .from('listing_price_history')
            .select('listing_id')
            .inFilter('listing_id', chunk)
            .gte('observed_at', from)
            .order('id')
            .range(start, end),
      );
      ids.addAll([for (final r in recent) r['listing_id'] as String]);
    }

    final points = <PricePoint>[];
    for (final chunk in _chunksOf100(ids.toList()..sort())) {
      final rows = await readAllPages(
        (start, end) => _client
            .from('listing_price_history')
            .select('listing_id, price, observed_at')
            .inFilter('listing_id', chunk)
            .order('id')
            .range(start, end),
      );
      points.addAll([for (final r in rows) PricePoint.fromRow(r)]);
    }
    return points;
  }

  /// The models each account follows: account -> catalog id -> first year.
  /// With [account], only that account's.
  Future<Map<String, Map<String, int>>> followedModels({
    String? account,
  }) async {
    final rows = await readAllPages((start, end) {
      var query = _client
          .from('user_models')
          .select('user_id, motorcycle_id, min_year')
          .eq('tracked', true);
      if (account != null) query = query.eq('user_id', account);
      return query.order('user_id').order('motorcycle_id').range(start, end);
    });
    final byUser = <String, Map<String, int>>{};
    for (final r in rows) {
      byUser.putIfAbsent(r['user_id'] as String, () => {})[r['motorcycle_id']
          as String] = (r['min_year'] as num)
          .toInt();
    }
    return byUser;
  }

  /// Keeps [summary] as [userId]'s latest weekly summary (the app's
  /// "Resumo da semana").
  Future<void> saveWeeklySummary(
    String userId,
    WeeklySummary summary,
    Map<String, Object?> json,
  ) async {
    await _client.from('weekly_summaries').upsert({
      'user_id': userId,
      'since': summary.since.toUtc().toIso8601String(),
      'until': summary.until.toUtc().toIso8601String(),
      'summary': json,
      'made_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Lets the database call Supabase Auth's admin API (accounts made from
  /// invites in the app) with this run's address and key; stored in the
  /// Vault, only when they changed.
  Future<void> storeServiceAccess(String url, String key) async {
    await _client.rpc<Object?>(
      'store_service_access',
      params: {'p_url': url, 'p_key': key},
    );
  }

  /// Our Web Push key pair; made and stored on the first run.
  Future<VapidKeys> pushKeys() async {
    Future<VapidKeys?> read() async {
      final rows = await _client.rpc<Object?>('push_keys') as List<dynamic>;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return VapidKeys.fromBase64(
        row['private_key'] as String,
        row['public_key'] as String,
      );
    }

    final stored = await read();
    if (stored != null) return stored;
    final keys = VapidKeys.generate();
    await _client.rpc<Object?>(
      'store_push_keys',
      params: {
        'p_public_key': keys.publicBase64,
        'p_private_key': keys.privateBase64,
      },
    );
    // Another run may have stored its pair first: use the stored one.
    return await read() ?? keys;
  }

  /// Every account's devices, by account.
  Future<Map<String, List<PushTarget>>> pushTargets() async {
    final rows = await _client
        .from('push_subscriptions')
        .select('endpoint, user_id, p256dh, auth');
    final byUser = <String, List<PushTarget>>{};
    for (final r in rows) {
      byUser
          .putIfAbsent(r['user_id'] as String, () => [])
          .add(
            PushTarget(
              endpoint: r['endpoint'] as String,
              p256dh: r['p256dh'] as String,
              auth: r['auth'] as String,
            ),
          );
    }
    return byUser;
  }

  /// A live listing for an example alert (the app's test notifications):
  /// the best Deal Score among [userId]'s models, or among all when the
  /// account follows none (or isn't given).
  Future<Map<String, dynamic>?> sampleListing(String? userId) async {
    final models = userId == null
        ? const <String>[]
        : [
            for (final r
                in await _client
                    .from('user_models')
                    .select('motorcycle_id')
                    .eq('user_id', userId)
                    .eq('tracked', true))
              r['motorcycle_id'] as String,
          ];
    var query = _client
        .from('listings')
        .select(
          'id, brand, model, url, year, mileage, price, deal_score, location',
        )
        .inFilter('status', ['active', 'price_changed'])
        .isFilter('duplicate_of', null)
        .not('motorcycle_id', 'is', null)
        .not('price', 'is', null);
    if (models.isNotEmpty) query = query.inFilter('motorcycle_id', models);
    final rows = await query
        .order('deal_score', ascending: false, nullsFirst: false)
        .limit(1);
    return rows.isEmpty ? null : rows.single;
  }

  /// Marks answered the valuations waiting for a model the run that started
  /// at [startedAt] read, with their values (`answer_bike_value_requests`).
  Future<List<BikeValueAnswer>> answerBikeValues(DateTime startedAt) async {
    final rows = await _client.rpc<List<dynamic>>(
      'answer_bike_value_requests',
      params: {'p_started_at': startedAt.toUtc().toIso8601String()},
    );
    return [
      for (final row in rows)
        BikeValueAnswer.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// The account that last started [workflow] from the app since [since].
  Future<String?> lastWorkflowStarter(String workflow, DateTime since) async {
    final rows = await _client
        .from('workflow_starts')
        .select('started_by')
        .eq('workflow', workflow)
        .gte('started_at', since.toUtc().toIso8601String())
        .not('started_by', 'is', null)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : rows.single['started_by'] as String;
  }

  /// The admins' accounts.
  Future<List<String>> adminIds() async {
    final rows = await _client.from('app_admins').select('user_id');
    return [for (final r in rows) r['user_id'] as String];
  }

  /// Devices whose push service says they no longer exist.
  Future<void> forgetPushTargets(List<String> endpoints) async {
    if (endpoints.isEmpty) return;
    await _client
        .from('push_subscriptions')
        .delete()
        .inFilter('endpoint', endpoints);
  }

  /// Devices that received a push now.
  Future<void> markPushTargetsUsed(List<String> endpoints) async {
    if (endpoints.isEmpty) return;
    await _client
        .from('push_subscriptions')
        .update({'last_sent_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('endpoint', endpoints);
  }

  Future<int> markNotified(List<String> alertIds) async {
    if (alertIds.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_alerts_notified',
      params: {'p_ids': alertIds},
    );
    return _count(result);
  }
}

/// [ids] in groups of 100, so each request's address stays short.
Iterable<List<String>> _chunksOf100(List<String> ids) sync* {
  for (var i = 0; i < ids.length; i += 100) {
    yield ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
  }
}
