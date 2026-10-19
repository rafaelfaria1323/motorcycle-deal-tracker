import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_dates_text.dart';
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

/// One row of a facts card: a label and its value.
typedef Fact = (String label, String value);

/// "A mota": year and mileage always (a dash when unknown), the rest only
/// when the ad says.
List<Fact> bikeFacts(Listing listing) => [
  ('Ano', listing.year?.toString() ?? '—'),
  ('Quilometragem', Formatters.mileage(listing.mileage)),
  if (listing.registrations case final owners?) ('Registos (donos)', '$owners'),
  if (listing.serviceBook case final book?)
    ('Livro de revisões', book ? 'Completo' : 'Não'),
  if (listing.origin case final origin?)
    ('Origem', origin == 'national' ? 'Nacional' : 'Importada'),
  if (listing.warrantyUntil case final until?)
    ('Garantia de fábrica até', Formatters.date(until)),
  if (listing.dealerWarrantyMonths case final months?)
    ('Garantia do vendedor', '$months meses'),
];

/// "O anúncio": where and who, the site, its dates and the status.
List<Fact> adFacts(Listing listing, {DateTime? now}) => [
  ('Localização', listing.location ?? '—'),
  ('Vendedor', listing.sellerName ?? '—'),
  ('Tipo de vendedor', listing.sellerType.label),
  ('Fonte', sourceLabel(listing.source)),
  if (listing.publishedAt case final published?)
    ('Publicado', dateWithAge(published, now: now)),
  if (renewalToShow(listing) case final renewed?)
    ('Renovado no site', dateWithAge(renewed, now: now)),
  ('Estado', listing.status.label),
];
