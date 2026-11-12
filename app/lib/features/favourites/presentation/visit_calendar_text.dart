import '../../../core/calendar/calendar_event.dart';
import '../../../core/localization/localizations.dart';
import '../../listings/presentation/listing_detail_text.dart';
import '../../listings/presentation/listing_labels.dart';
import '../domain/entities/favourite.dart';

/// How long the visit takes in the calendar.
const visitLength = Duration(hours: 1);

/// The calendar's own reminder, besides the app's the day before.
const visitCalendarReminder = Duration(hours: 1);

/// The planned visit of [favourite] at [at] as a calendar event (N.73):
/// "Visita: Yamaha MT-07 · 2021", an hour long, at the ad's place, with
/// the price, the app's page of the ad (at [origin]), the seller's ad and
/// a word on the checklist. One per favourite: adding it again replaces it
/// in calendars that import .ics files.
CalendarEvent visitEvent(
  Favourite favourite,
  DateTime at, {
  required String origin,
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  final listing = favourite.listing;
  return CalendarEvent(
    uid: 'visit-${favourite.listingId}@motorcycle-deal-tracker',
    title: messages.visitEventTitle(
      bike: listing?.nameAndYear ?? messages.visitEventBike,
    ),
    start: at,
    end: at.add(visitLength),
    location: listing?.location,
    description: [
      if (listing != null && listing.price != null)
        listing.priceLabel(language: language),
      listingLink(origin, favourite.listingId),
      if (listing != null && adAddress(listing) != null)
        messages.originalAdAddress(url: '${adAddress(listing)}'),
      messages.visitEventChecklist,
    ].join('\n'),
    reminder: visitCalendarReminder,
  );
}
