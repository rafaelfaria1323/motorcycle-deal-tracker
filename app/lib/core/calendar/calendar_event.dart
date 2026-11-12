import 'dart:convert';

/// One event to put in the person's calendar (N.73): the Android app hands
/// it to the calendar app, the browser downloads it as an .ics file.
class const CalendarEvent({
  required final String uid,
  required final String title,
  required final DateTime start,
  required final DateTime end,
  required final String description,
  final String? location,
  final Duration? reminder,
});

/// [event] as an iCalendar file (RFC 5545): CRLF lines folded at 75
/// octets, text escaped, times in UTC, and an alarm [CalendarEvent.reminder]
/// before the start. [stamp] is when the file was made.
String icsText(CalendarEvent event, {required DateTime stamp}) {
  final location = event.location?.trim();
  final reminder = event.reminder;
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Motorcycle Deal Tracker//Visit//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${_escape(event.uid)}',
    'DTSTAMP:${icsTime(stamp)}',
    'DTSTART:${icsTime(event.start)}',
    'DTEND:${icsTime(event.end)}',
    'SUMMARY:${_escape(event.title)}',
    'DESCRIPTION:${_escape(event.description)}',
    if (location != null && location.isNotEmpty)
      'LOCATION:${_escape(location)}',
    if (reminder != null) ...[
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_escape(event.title)}',
      'TRIGGER:-PT${reminder.inMinutes}M',
      'END:VALARM',
    ],
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  // Every line ends with CRLF, the last one too.
  return lines.map((line) => '${_fold(line)}\r\n').join();
}

/// [at] in UTC as iCalendar writes it: 20261120T090000Z.
String icsTime(DateTime at) {
  final utc = at.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\n');

/// Folds a content line into pieces of at most 75 octets, each piece after
/// the first starting with a space; never inside a UTF-8 character.
String _fold(String line) {
  const limit = 75;
  if (utf8.encode(line).length <= limit) return line;
  final pieces = <String>[];
  final piece = StringBuffer();
  var octets = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    // Continuation lines lose one octet to their leading space.
    final room = pieces.isEmpty ? limit : limit - 1;
    if (octets + size > room) {
      pieces.add(piece.toString());
      piece.clear();
      octets = 0;
    }
    piece.write(char);
    octets += size;
  }
  pieces.add(piece.toString());
  return pieces.join('\r\n ');
}
