import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/platform/calendar.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/favourite.dart';
import '../cubit/favourites_cubit.dart';
import '../favourites_text.dart';
import '../visit_calendar_text.dart';

/// When the user goes to see the bike (N.65): a day, then a time. The day
/// before, the collector reminds them on their devices; a planned visit
/// also goes to the phone's calendar (N.73).
class const VisitTile({required final Favourite favourite, super.key})
    extends StatelessWidget {
  /// How far ahead a visit can be planned.
  static const maxDaysAhead = 90;

  Future<void> _plan(BuildContext context) async {
    final messageStrings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = favourite.visitAt;
    final day = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today)
          ? current
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: maxDaysAhead)),
      helpText: messageStrings.planVisit,
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(current),
      helpText: messageStrings.planVisit,
    );
    if (time == null) return;
    await _save(
      messenger,
      messageStrings,
      DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _save(
    ScaffoldMessengerState messenger,
    AppLocalizations strings,
    DateTime? at,
  ) async {
    final saved = await getIt<FavouritesCubit>().saveVisit(
      favourite.listingId,
      at,
    );
    if (!saved) showMessage(messenger, strings.couldNotSaveVisit);
  }

  Future<void> _addToCalendar(BuildContext context, DateTime at) async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final added = await addToCalendar(
      visitEvent(favourite, at, origin: webOrigin, language: context.language),
    );
    if (!added) {
      showMessage(messenger, strings.couldNotAddToCalendar);
    } else if (kIsWeb) {
      // The browser only downloaded the file.
      showMessage(messenger, strings.visitCalendarDownloaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = favourite.visitAt;
    return ListTile(
      leading: const Icon(Icons.event_outlined),
      title: Text(
        visit == null
            ? context.strings.visitNotPlanned
            : visitText(visit, language: context.language),
      ),
      subtitle: Text(context.strings.visitReminderHint),
      onTap: () => _plan(context),
      trailing: visit == null
          ? TextButton(
              onPressed: () => _plan(context),
              child: Text(context.strings.planVisit),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.strings.addVisitToCalendar,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  onPressed: () => _addToCalendar(context, visit),
                ),
                IconButton(
                  tooltip: context.strings.cancelVisit,
                  icon: const Icon(Icons.event_busy_outlined),
                  onPressed: () => _save(
                    ScaffoldMessenger.of(context),
                    context.strings,
                    null,
                  ),
                ),
              ],
            ),
    );
  }
}
