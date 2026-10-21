abstract final class AppRoutes {
  static const deals = '/deals';
  static const searches = '/searches';
  static const alerts = '/alerts';
  static const more = '/more';
  static const models = '/models';
  static const modelMarket = '/market';
  static const comparePath = '/compare';
  static const favourites = '/favourites';
  static const accounts = '/accounts';
  static const join = '/join';
  static const collectionStatus = '/collection-status';

  static String listingDetail(String id) => '$deals/$id';

  static String compare(List<String> ids) =>
      '$comparePath?ids=${ids.join(',')}';
}
