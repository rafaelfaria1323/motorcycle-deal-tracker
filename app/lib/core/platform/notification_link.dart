/// Where a tapped notification leads in the Android app: a page of the app
/// ([location], for go_router) or an address outside it ([external]). The
/// collector sends the web app's address of the page (`/#/deals/<id>`,
/// `/#/summary`…), or the ad's own address when it has no page here.
typedef NotificationLink = ({String? location, Uri? external});

NotificationLink? notificationLink(String url) {
  final text = url.trim();
  if (text.startsWith('/#/')) {
    return (location: text.substring(2), external: null);
  }
  if (text.startsWith('#/')) {
    return (location: text.substring(1), external: null);
  }
  if (text.startsWith('/')) return (location: text, external: null);
  final uri = Uri.tryParse(text);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    return (location: null, external: uri);
  }
  return null;
}

/// The page a link to the web app opens in the Android app (App Links). The
/// link is the web app's own address (`https://<site>/#/deals/<id>`), and
/// Android hands the app its path and fragment (`/#/deals/<id>`), so the
/// page is the fragment. Null for anything else (the web's own hash
/// addresses never have a fragment here).
String? appLinkLocation(Uri uri) {
  final page = uri.fragment;
  if (!page.startsWith('/')) return null;
  if (uri.path.isNotEmpty && uri.path != '/') return null;
  return page;
}
