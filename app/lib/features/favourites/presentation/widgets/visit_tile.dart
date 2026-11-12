import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/favourite.dart';
import '../cubit/favourites_cubit.dart';
import '../favourites_text.dart';

/// When the user goes to see the bike (N.65): a day, then a time. The day
/// before, the collector reminds them on their devices.
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
          : IconButton(
              tooltip: context.strings.cancelVisit,
              icon: const Icon(Icons.event_busy_outlined),
              onPressed: () =>
                  _save(ScaffoldMessenger.of(context), context.strings, null),
            ),
    );
  }
}
