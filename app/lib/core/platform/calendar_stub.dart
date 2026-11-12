import 'package:flutter/services.dart';

import '../calendar/calendar_event.dart';

const _channel = MethodChannel('deal_tracker/calendar_event');

/// The Android app: the in-repo plugin packages/calendar_event opens the
/// calendar app's new-event screen.
Future<bool> addToCalendar(CalendarEvent event) async {
  try {
    return await _channel.invokeMethod<bool>('insert', {
          'title': event.title,
          'description': event.description,
          'location': event.location ?? '',
          'begin': event.start.millisecondsSinceEpoch,
          'end': event.end.millisecondsSinceEpoch,
        }) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
