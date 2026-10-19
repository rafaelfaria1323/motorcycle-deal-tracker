abstract final class AppRoutes {
  static const deals = '/deals';
  static const searches = '/searches';
  static const alerts = '/alerts';
  static const models = '/models';

  static String listingDetail(String id) => '$deals/$id';
}
