import 'package:supabase/supabase.dart';

import '../../collector.dart';
import 'store_support.dart';

/// The photo checks (P.1-P.4): which listings' photos to read, and what
/// was seen in them.
class PhotoStore(final SupabaseClient _client) {
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
    return rpcCount(result);
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
    return rpcCount(result);
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
    return rpcCount(result);
  }

  /// The admins' photo marks for [model] to learn from (P.3), with the
  /// marks' state now and the state the stored classifier learned from.
  Future<PhotoTrainingSet> photoTrainingSet(String model) async {
    final rows = (await _client.rpc<List<dynamic>>(
      'photo_training_set',
      params: {'p_model': model},
    )).cast<Map<String, Object?>>();
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
    return rpcCount(result);
  }
}
