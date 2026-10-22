import 'listing.dart';
import 'motorcycle_option.dart';

/// The first page of the Ofertas list (default filters and order) with the
/// model list, asked for by `web/index.html` before the app started.
class FirstPage {
  const FirstPage({required this.listings, required this.motorcycles});

  final List<Listing> listings;
  final List<MotorcycleOption> motorcycles;
}
