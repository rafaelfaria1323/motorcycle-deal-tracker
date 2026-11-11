import 'package:url_launcher/url_launcher.dart';

import 'home_screen_app.dart';

/// Opens a seller's ad outside the app.
Future<bool> openAd(Uri ad) {
  final target = adLaunch(ad, iosHomeScreenApp: isIosHomeScreenApp);
  return launchUrl(
    target.address,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: target.window,
  );
}

/// Where [openAd] sends an ad. The iPhone's home-screen app opens a new
/// window as a sheet inside itself; when the site's own app (OLX) takes
/// the address, that sheet stays behind, blank, over the app. There the ad
/// goes to Safari instead (`x-safari-https:`, iOS 17+, from the page
/// itself, `_top`, which stays as it was), and the site's app can still
/// be opened from Safari's banner. Elsewhere: the address as it is.
({Uri address, String? window}) adLaunch(
  Uri ad, {
  required bool iosHomeScreenApp,
}) {
  if (!iosHomeScreenApp || (ad.scheme != 'https' && ad.scheme != 'http')) {
    return (address: ad, window: null);
  }
  return (address: Uri.parse('x-safari-$ad'), window: '_top');
}
