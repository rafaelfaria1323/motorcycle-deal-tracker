# calendar_event

The Android app's "Adicionar ao calendário" for a planned visit (N.73).
Android only, no Dart code: `lib/core/platform/calendar_stub.dart` calls
the channel `deal_tracker/calendar_event` (method `insert`: title,
description, location, begin and end in milliseconds since the epoch).

The plugin opens the calendar app's new-event screen
(`Intent.ACTION_INSERT` on `CalendarContract.Events.CONTENT_URI`) with the
visit filled in; the person saves it there. No permission: the app never
reads or writes the calendar itself. Without a calendar app it answers
`false` and the app says so.

The web app downloads the same event as an `.ics` file instead
(`calendar_web.dart`, `core/calendar/calendar_event.dart`).
