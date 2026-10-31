import 'package:equatable/equatable.dart';

/// A brand in Standvirtual's search filters, for the model picker.
class const SiteMake({
  /// The site's id, used in search addresses ("harley-davidson").
  required final String id,
  required final String name,

  /// Ads the site has for the brand.
  required final int ads,
}) extends Equatable {
  @override
  List<Object?> get props => [id, name, ads];
}

/// A model in a site's search filters (`site_models`), for the picker.
class const SiteModel({
  /// 'standvirtual' or 'olx'.
  required final String source,
  required final String makeId,

  /// The site's id, used in search addresses ("africa-twin").
  required final String id,
  required final String name,

  /// Ads the site has for the model (Standvirtual only).
  final int? ads,
}) extends Equatable {
  @override
  List<Object?> get props => [source, makeId, id, name, ads];
}
