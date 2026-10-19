import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';

/// The line under the price: "2022 · 12 300 km · Lisboa · Profissional".
/// Missing facts are left out rather than shown as dashes.
String keyFactsLine(Listing listing) => [
  if (listing.year != null) '${listing.year}',
  if (listing.mileage != null) Formatters.mileage(listing.mileage),
  if (listing.location case final location? when location.trim().isNotEmpty)
    location.trim(),
  if (listing.sellerType != SellerType.unknown) listing.sellerType.label,
].join(' · ');

/// "3 / 12" on the photo gallery.
String photoCounterText(int index, int count) => '${index + 1} / $count';

/// The button to the seller's ad: "Ver no OLX".
String originalLinkLabel(String source) => switch (source) {
  'standvirtual' || 'olx' => 'Ver no ${sourceLabel(source)}',
  _ => 'Ver anúncio original',
};
