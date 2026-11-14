import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../listings/domain/entities/listing.dart';
import '../../listings/presentation/listing_detail_text.dart';
import '../../listings/presentation/listing_labels.dart';
import '../domain/entities/favourite.dart';
import '../domain/entities/favourite_share.dart';
import 'viewing_checklist.dart';

/// The page a shared list's link opens (`/#/share?code=…`, 16.11).
String favouriteShareLink(String origin, String code) =>
    '$origin/#/share?code=${Uri.encodeQueryComponent(code)}';

/// What the sharing sheet says about the account's own share: who sees
/// the list, and the link waiting to be used.
String favouriteShareStateText(
  FavouriteShare share, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final viewer = share.viewerEmail;
  final lines = [
    if (viewer != null) m.favouritesSeenBy(email: viewer),
    if (share.codeExpiresAt case final expires? when share.waiting)
      m.favouritesLinkWaiting(date: Formatters.date(expires.toLocal())),
  ];
  return lines.isEmpty ? m.favouritesNotShared : lines.join('\n');
}

/// The favourites as a spreadsheet (16.11): one row per favourite with
/// its listing, in the list's order. Portuguese uses ";" between cells,
/// as a Portuguese spreadsheet expects, English ","; a byte order mark
/// first so the spreadsheet reads the accents; RFC 4180 quoting. Numbers
/// are plain (no thousands separators), so they sort as numbers; a text
/// cell that would start a formula gets an apostrophe first.
String favouritesCsv(
  List<Favourite> favourites, {
  required String origin,
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final separator = language == .portuguese ? ';' : ',';
  String cell(Object? value) {
    if (value == null) return '';
    if (value is num) return '$value';
    var text = '$value';
    if (text.startsWith(RegExp('[=+\\-@\t\r]'))) text = "'$text";
    final quote =
        text.contains(separator) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    return quote ? '"${text.replaceAll('"', '""')}"' : text;
  }

  final header = [
    m.csvBike,
    m.csvYear,
    m.csvMileage,
    m.csvPrice,
    m.csvDealScore,
    m.csvRiskScore,
    m.csvStatus,
    m.csvPlace,
    m.csvNote,
    m.csvVisit,
    m.csvChecklist,
    m.csvAd,
    m.csvAppLink,
  ];
  final rows = [
    for (final f in favourites)
      if (f.listing case final listing?) _row(f, listing, origin, language),
  ];
  return '\uFEFF${[
    for (final row in [header, ...rows]) row.map(cell).join(separator),
  ].join('\r\n')}\r\n';
}

List<Object?> _row(
  Favourite favourite,
  Listing listing,
  String origin,
  AppLanguage language,
) => [
  listing.name,
  listing.year,
  listing.mileage,
  listing.askingPrice?.round(),
  listing.dealScore,
  listing.riskScore,
  listing.status.label(language: language),
  listing.location?.trim(),
  favourite.note,
  if (favourite.visitAt case final visit?)
    '${Formatters.date(visit)} ${Formatters.time(visit)}'
  else
    null,
  if (favourite.checklist.isEmpty)
    null
  else
    checklistIssuesText(
          favourite.checklist,
          language: language,
          listing: listing,
        ) ??
        checklistSummaryText(
          favourite.checklist,
          language: language,
          listing: listing,
        ),
  adAddress(listing)?.toString(),
  listingLink(origin, listing.id),
];
