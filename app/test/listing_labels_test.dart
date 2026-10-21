import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_labels.dart';

void main() {
  test('sources are shown by the names people know', () {
    expect(sourceLabel('standvirtual'), 'Standvirtual');
    expect(sourceLabel('olx'), 'OLX');
    expect(sourceLabel('something-new'), 'something-new');
  });
}
