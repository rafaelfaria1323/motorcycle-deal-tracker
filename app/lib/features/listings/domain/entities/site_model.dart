import 'package:equatable/equatable.dart';

/// A brand in Standvirtual's search filters, for the model picker.
class SiteMake extends Equatable {
  const SiteMake({required this.id, required this.name, required this.ads});

  /// The site's id, used in search addresses ("harley-davidson").
  final String id;
  final String name;

  /// Ads the site has for the brand.
  final int ads;

  @override
  List<Object?> get props => [id, name, ads];
}

/// A model in a site's search filters (`site_models`), for the picker.
class SiteModel extends Equatable {
  const SiteModel({
    required this.source,
    required this.makeId,
    required this.id,
    required this.name,
    this.ads,
  });

  /// 'standvirtual' or 'olx'.
  final String source;
  final String makeId;

  /// The site's id, used in search addresses ("africa-twin").
  final String id;
  final String name;

  /// Ads the site has for the model (Standvirtual only).
  final int? ads;

  @override
  List<Object?> get props => [source, makeId, id, name, ads];
}
