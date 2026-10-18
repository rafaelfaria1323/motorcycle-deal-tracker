abstract final class AppRoutes {
  static const deals = '/deals';
  static const searches = '/searches';
  static const alerts = '/alerts';

  static String listingDetail(String id) => '$deals/$id';
}
