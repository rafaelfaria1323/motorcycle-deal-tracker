import 'package:equatable/equatable.dart';

/// Falls or accidents the owner reports.
enum BikeDamage { none, dropped, accident }

/// How many owners the bike has had, the seller included.
enum BikeOwners { unknown, one, two, threeOrMore }

/// Whether the bike has its service book.
enum BikeServiceBook { unknown, yes, no }

/// What the owner says about the bike in "Quanto vale a minha mota": not
/// part of the request (the collection needs only the model and year),
/// it adjusts the value the comparables give.
class BikeCondition extends Equatable {
  const BikeCondition({
    this.damage = BikeDamage.none,
    this.owners = BikeOwners.unknown,
    this.serviceBook = BikeServiceBook.unknown,
    this.warranty = false,
  });

  final BikeDamage damage;
  final BikeOwners owners;
  final BikeServiceBook serviceBook;

  /// Still under the factory's warranty.
  final bool warranty;

  BikeCondition copyWith({
    BikeDamage? damage,
    BikeOwners? owners,
    BikeServiceBook? serviceBook,
    bool? warranty,
  }) => BikeCondition(
    damage: damage ?? this.damage,
    owners: owners ?? this.owners,
    serviceBook: serviceBook ?? this.serviceBook,
    warranty: warranty ?? this.warranty,
  );

  @override
  List<Object?> get props => [damage, owners, serviceBook, warranty];
}
