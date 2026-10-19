import 'package:collector/collector.dart';
import 'package:test/test.dart';

MappedRecord mapped(String id) => MappedRecord(
  id,
  Mapped(
    NormalizedListing(
      source: 'standvirtual',
      sourceListingId: id,
      url: 'https://example.com/$id',
      brand: 'Yamaha',
      model: 'MT-07',
      price: 7000,
      sellerType: SellerType.dealer,
      images: const [],
    ),
  ),
);

SourceBatch batch(List<MappedRecord> records) =>
    SourceBatch('standvirtual', const [], records);

void main() {
  test('a rejected bike still on the site counts as seen', () {
    final ids = liveIds(
      batch([
        mapped('a'),
        const MappedRecord(
          'old',
          Rejected('year 2016 is below the tracked range'),
          liveId: 'b',
        ),
      ]),
    );

    expect(ids, unorderedEquals(['a', 'b']));
  });

  test('a rejected record without an id makes the input untrustworthy', () {
    final ids = liveIds(
      batch([
        mapped('a'),
        const MappedRecord('gone', Rejected('listing is not active')),
      ]),
    );

    expect(ids, isNull);
  });
}
