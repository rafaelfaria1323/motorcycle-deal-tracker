import '../calendar/calendar_event.dart';
import 'download_web.dart';

/// The browser: the event as an .ics file, downloaded; the phone's or the
/// computer's calendar opens it.
Future<bool> addToCalendar(CalendarEvent event) => downloadText(
  'visita.ics',
  icsText(event, stamp: DateTime.now()),
  type: 'text/calendar;charset=utf-8',
);
