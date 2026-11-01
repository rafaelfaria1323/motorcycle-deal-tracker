import 'listing_alert.dart';

/// Alertas' chips (F.6): which alerts the list shows. A bike back on sale
/// counts as new, a target price reached as a drop.
enum AlertFilter {
  all(<AlertType>{}),
  newListings({AlertType.newListing, AlertType.backOnMarket}),
  priceDrops({AlertType.priceReduction, AlertType.targetPriceReached}),
  excellent({AlertType.excellentOpportunity}),
  removed({AlertType.listingRemoved});

  const AlertFilter(this.types);

  /// The alert types shown; empty for every type.
  final Set<AlertType> types;
}
