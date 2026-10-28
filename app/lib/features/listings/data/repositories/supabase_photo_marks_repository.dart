import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/photo_marks_repository.dart';

class SupabasePhotoMarksRepository implements PhotoMarksRepository {
  SupabasePhotoMarksRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<int, bool>> marks(String listingId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'my_photo_marks',
      params: {'p_listing': listingId},
    );
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        (r['photo'] as num).toInt(): r['problem'] as bool,
    };
  }

  @override
  Future<void> setMark(String listingId, int photo, bool? problem) =>
      _client.rpc<void>(
        'set_photo_mark',
        params: {
          'p_listing': listingId,
          'p_photo': photo,
          'p_problem': problem,
        },
      );
}
