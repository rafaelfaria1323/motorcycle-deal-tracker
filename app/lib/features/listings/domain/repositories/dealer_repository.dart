import '../entities/dealer_reliability.dart';

abstract interface class DealerRepository {
  /// The figures of the dealer with this name (case and surrounding spaces
  /// ignored); null when there are none.
  Future<DealerReliability?> getByName(String sellerName);
}
