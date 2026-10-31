import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/photo_exams_repository.dart';
import '../models/listing_model.dart';

class SupabasePhotoExamsRepository(final SupabaseClient _client)
    implements PhotoExamsRepository {
  @override
  Future<DateTime?> request(String listingId) async {
    try {
      final at = await _client.rpc<Object?>(
        'request_photo_exam',
        params: {'p_listing': listingId},
      );
      return ListingModel.dateOf(at);
    } on PostgrestException catch (e) {
      if (e.code == '54000') throw const PhotoExamLimit();
      rethrow;
    }
  }
}
