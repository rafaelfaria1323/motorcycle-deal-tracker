abstract final class AppRoutes {
  static const deals = '/deals';
  static const searches = '/searches';
  static const alerts = '/alerts';
  static const more = '/more';
  static const models = '/models';
  static const modelMarket = '/market';
  static const bikeValue = '/worth';
  static const importBike = '/import';
  static const comparePath = '/compare';
  static const favourites = '/favourites';
  static const accounts = '/accounts';
  static const join = '/join';
  static const collectionStatus = '/collection-status';
  static const summary = '/summary';

  static String listingDetail(String id) => '$deals/$id';

  /// The `extra` of an ad opened from a list of ads (a plain string, so
  /// the browser's history keeps it): it opens on the part last read, to
  /// go through ads one after another. Opened any other way (a
  /// notification, an alert, a shared link) it starts on Avaliação.
  static const fromList = 'list';

  static String listingPhotos(String id) => '$deals/$id/photos';

  static String compare(List<String> ids) =>
      '$comparePath?ids=${ids.join(',')}';
}
