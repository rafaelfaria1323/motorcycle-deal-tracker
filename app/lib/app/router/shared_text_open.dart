import '../../features/valuation/presentation/ad_link.dart';
import 'app_router.dart';
import 'app_routes.dart';

/// The longest shared text carried to the form (a share holds a title and
/// a link; anything longer is not an ad's).
const _maxSharedText = 500;

/// Where text shared to the Android app opens (N.103): "Avaliar um
/// anúncio" with the ad's link filled in, or, when the text holds no OLX
/// or Standvirtual ad, with the text itself, which the form then says is
/// no ad link.
String sharedTextLocation(String text) {
  final trimmed = text.trim();
  final link =
      adLinkOf(trimmed) ??
      (trimmed.length > _maxSharedText
          ? trimmed.substring(0, _maxSharedText)
          : trimmed);
  return Uri(
    path: AppRoutes.checkAd,
    queryParameters: {'link': link},
  ).toString();
}

/// Opens the shared text's page (nothing beneath it, as a notification:
/// the back button goes to Mais).
void openSharedText(String text) => appRouter.go(sharedTextLocation(text));
