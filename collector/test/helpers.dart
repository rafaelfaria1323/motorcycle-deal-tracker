import 'package:collector/collector.dart';

/// Catalog entries as the real catalog has them, for tests of matching.
const mt07Entry = CatalogEntry(
  slug: 'yamaha-mt-07',
  brand: 'Yamaha',
  model: 'MT-07',
  minYear: 2023,
  excludedWords: ['tracer'],
  engineCcMin: 680,
  engineCcMax: 710,
);

const r7Entry = CatalogEntry(
  slug: 'yamaha-r7',
  brand: 'Yamaha',
  model: 'R7',
  minYear: 2023,
  engineCcMin: 680,
  engineCcMax: 710,
);

/// A minimal valid listing; tests set only what they look at.
NormalizedListing testListing(
  String id, {
  String source = 'olx',
  double price = 7000,
  SellerType sellerType = SellerType.private,
  String? motorcycleSlug,
}) => NormalizedListing(
  source: source,
  motorcycleSlug: motorcycleSlug,
  sourceListingId: id,
  url: 'https://example.com/$id',
  brand: 'Yamaha',
  model: 'MT-07',
  price: price,
  sellerType: sellerType,
  images: const [],
);
