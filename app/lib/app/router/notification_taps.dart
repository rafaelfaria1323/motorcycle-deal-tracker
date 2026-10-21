import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/notification_link.dart';
import 'app_router.dart';

/// Opens the page of a notification tapped in the Android app, as the
/// browser does with a Web Push one (nothing beneath it: the back button
/// goes to Mais, or Ofertas).
void openNotification(String url) {
  final link = notificationLink(url);
  if (link?.location case final location?) {
    appRouter.go(location);
  } else if (link?.external case final uri?) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
