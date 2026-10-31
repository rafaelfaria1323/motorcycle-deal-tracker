import 'listing.dart';
import 'motorcycle_option.dart';

/// The first page of the Ofertas list (default filters and order) with the
/// model list, asked for by `web/index.html` before the app started.
class const FirstPage({
  required final List<Listing> listings,
  required final List<MotorcycleOption> motorcycles,
});
