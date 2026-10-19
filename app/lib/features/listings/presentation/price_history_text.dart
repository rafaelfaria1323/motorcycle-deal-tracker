import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';

/// A line about an earlier price the site reported from before we started
/// tracking; null when there is none or our own history already covers it.
String? siteDropLine(Listing listing) {
  final before = listing.priceBeforeDrop;
  final current = listing.price;
  if (!listing.referenceIsFromSite || before == null || current == null) {
    return null;
  }
  if (before - current < 1) return null;
  final pct = ((before - current) / before * 100).toStringAsFixed(1);
  return 'Segundo o ${_sourceName(listing.source)}, o preço já foi '
      '${Formatters.price(before)} (−${pct.replaceAll('.', ',')} % até hoje), '
      'antes de começarmos a seguir este anúncio.';
}

String _sourceName(String source) => switch (source) {
  'standvirtual' => 'Standvirtual',
  _ => 'site',
};
