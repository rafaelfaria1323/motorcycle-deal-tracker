/// Where a tapped notification leads in the Android app: a page of the app
/// ([location], for go_router) or an address outside it ([external]). The
/// collector sends the web app's address of the page (`/#/deals/<id>`,
/// `/#/summary`…), or the ad's own address when it has no page here.
typedef NotificationLink = ({String? location, Uri? external});

NotificationLink? notificationLink(String url) {
  final text = url.trim();
  if (text.startsWith('/#/'))
    return (location: text.substring(2), external: null);
  if (text.startsWith('#/'))
    return (location: text.substring(1), external: null);
  if (text.startsWith('/')) return (location: text, external: null);
  final uri = Uri.tryParse(text);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    return (location: null, external: uri);
  }
  return null;
}
