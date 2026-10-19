import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/repositories/listings_repository.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_detail_cubit.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/cubit/listing_detail_state.dart';

const _id = '123e4567-e89b-12d3-a456-426614174000';

const _listing = Listing(
  id: _id,
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/1.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: [],
);

class _Repository implements ListingsRepository {
  _Repository({this.listing, this.fails = false});

  final Listing? listing;
  final bool fails;
  final asked = <String>[];

  @override
  Future<Listing?> getListingById(String id) async {
    asked.add(id);
    if (fails) throw Exception('network');
    return listing;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a known listing is loaded', () async {
    final cubit = ListingDetailCubit(_Repository(listing: _listing));
    await cubit.load(_id);
    expect(cubit.state.status, ListingDetailStatus.success);
    expect(cubit.state.listing, _listing);
  });

  test('an id that is not a UUID is not found, without asking', () async {
    final repository = _Repository(listing: _listing);
    final cubit = ListingDetailCubit(repository);
    await cubit.load('not-an-id');
    expect(cubit.state.status, ListingDetailStatus.notFound);
    expect(repository.asked, isEmpty);
  });

  test('a UUID with no listing is not found', () async {
    final cubit = ListingDetailCubit(_Repository());
    await cubit.load(_id);
    expect(cubit.state.status, ListingDetailStatus.notFound);
    expect(cubit.state.listing, isNull);
  });

  test('a failed load is a failure, and loading again recovers', () async {
    final cubit = ListingDetailCubit(_Repository(fails: true));
    await cubit.load(_id);
    expect(cubit.state.status, ListingDetailStatus.failure);

    final retry = ListingDetailCubit(_Repository(listing: _listing));
    await retry.load(_id);
    expect(retry.state.status, ListingDetailStatus.success);
  });
}
