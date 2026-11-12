import '../calendar/calendar_event.dart';
import 'calendar_stub.dart'
    if (dart.library.js_interop) 'calendar_web.dart'
    as impl;

/// Puts [event] in the person's calendar (N.73): in the Android app the
/// calendar app opens with it filled in (the person saves it there); in
/// the browser an .ics file is downloaded, which the phone's or the
/// computer's calendar opens. False when neither could be done.
Future<bool> addToCalendar(CalendarEvent event) => impl.addToCalendar(event);
