import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/platform/push.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/push_repository.dart';
import '../domain/quiet_hours.dart';
import '../domain/workflows_repository.dart';
import 'push_text.dart';
import 'start_workflow.dart';
import 'workflows_text.dart';
import '../../../core/localization/localizations.dart';

/// "Notificações neste aparelho" in Mais: the account's alerts as
/// notifications on this phone or computer (Web Push). When they are on,
/// a test notification or the weekly summary can be asked for now (sent by
/// the collector, so it checks the whole path to the device). Signed-in
/// accounts also set their quiet hours here (all their devices).
class const PushTile({required final bool signedIn, super.key})
    extends StatefulWidget {
  @override
  State<PushTile> createState() => _PushTileState();
}

class _PushTileState extends State<PushTile> {
  final _repository = getIt<PushRepository>();
  PushState? _state;
  bool _busy = false;

  /// The account's quiet hours; null while loading or when they could not
  /// be read ([_quietFailed]).
  QuietHours? _quiet;
  bool _quietFailed = false;

  /// The workflow being started from here (test, weekly summary).
  AppWorkflow? _starting;

  /// Read ahead: Safari asks for permission only straight after a tap, so
  /// nothing may be awaited between the tap and the request.
  String? _publicKey;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.signedIn) _loadQuiet();
  }

  Future<void> _loadQuiet() async {
    if (_quietFailed) setState(() => _quietFailed = false);
    try {
      final hours = await _repository.quietHours();
      if (mounted) setState(() => _quiet = hours);
    } on Object catch (_) {
      if (mounted) setState(() => _quietFailed = true);
    }
  }

  Future<void> _editQuiet(QuietHours current) async {
    final messageStrings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final hours = await showDialog<QuietHours>(
      context: context,
      builder: (_) => _QuietHoursDialog(current),
    );
    if (hours == null || hours == current) return;
    try {
      await _repository.saveQuietHours(hours);
    } on Object catch (_) {
      showMessage(messenger, messageStrings.couldNotSaveTryAgain);
      return;
    }
    if (mounted) setState(() => _quiet = hours);
  }

  Future<void> _load() async {
    final state = await DevicePush.state().catchError(
      (Object _) => PushState.unsupported,
    );
    final key = await _repository.publicKey().catchError((Object _) => null);
    // The browser's subscription is what the switch shows: store it again
    // for this account, in case the database lost it (a failed save, a
    // device the collector forgot, another account signed in here).
    if (state == .on && key != null && widget.signedIn) {
      try {
        await _repository.save(await DevicePush.enable(key));
      } on Object catch (_) {
        // Shown as on; the next visit tries again.
      }
    }
    if (!mounted) return;
    setState(() {
      _state = state;
      _publicKey = key;
    });
  }

  Future<void> _set(bool on) async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final key = _publicKey;
    if (on && key == null) {
      showMessage(messenger, messageStrings.pushNotReadyYet);
      return;
    }
    setState(() => _busy = true);
    try {
      if (on) {
        await _repository.save(await DevicePush.enable(key!));
      } else {
        final endpoint = await DevicePush.disable();
        if (endpoint != null) await _repository.remove(endpoint);
      }
    } catch (_) {
      showMessage(
        messenger,
        on
            ? messageStrings.pushEnableFailed
            : messageStrings.couldNotDisableNotificationsTryAgain,
      );
    }
    final state = await DevicePush.state().catchError(
      (Object _) => PushState.unsupported,
    );
    if (mounted) {
      setState(() {
        _state = state;
        _busy = false;
      });
    }
  }

  Future<void> _send(AppWorkflow workflow) async {
    final messageLanguage = context.language;

    final messenger = ScaffoldMessenger.of(context);
    PushTestKind? kind;
    if (workflow == .pushTest) {
      kind = await _pickKind();
      if (kind == null || !mounted) return;
    }
    setState(() => _starting = workflow);
    final message = await startWorkflow(
      workflow,
      kind: kind,
      language: messageLanguage,
    );
    if (!mounted) return;
    setState(() => _starting = null);
    showMessage(messenger, message);
  }

  /// Which example to send: one of each alert and collection message, as
  /// the real one would look (marked as a test).
  Future<PushTestKind?> _pickKind() => showModalBottomSheet<PushTestKind>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.strings.whichNotificationShouldWeSend),
              subtitle: Text(context.strings.exampleOfEachTypeUsingOneOfYour),
            ),
            for (final kind in PushTestKind.values)
              ListTile(
                title: Text(pushTestKindText(kind, language: context.language)),
                onTap: () => Navigator.of(context).pop(kind),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final enabled =
        state != null &&
        !_busy &&
        pushSwitchEnabled(state, signedIn: widget.signedIn);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.strings.notificationsOnThisDevice),
          subtitle: Text(
            state == null
                ? context.strings.checking
                : pushSubtitle(
                    state,
                    signedIn: widget.signedIn,
                    language: context.language,
                  ),
          ),
          trailing: Switch(
            value: state == .on,
            onChanged: enabled ? _set : null,
          ),
        ),
        if (widget.signedIn) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(context.strings.quietHours),
            subtitle: Text(switch (_quiet) {
              final hours? => quietHoursSubtitle(
                hours,
                language: context.language,
              ),
              null when _quietFailed => context.strings.couldNotLoad,
              null => context.strings.checking,
            }),
            trailing: const Icon(Icons.chevron_right),
            enabled: _quiet != null || _quietFailed,
            onTap: switch (_quiet) {
              final hours? => () => _editQuiet(hours),
              null => _loadQuiet,
            },
          ),
        ],
        if (widget.signedIn && state == .on)
          for (final (workflow, icon) in const [
            (AppWorkflow.pushTest, Icons.send_outlined),
            (AppWorkflow.weeklySummary, Icons.summarize_outlined),
          ]) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(icon),
              title: Text(
                workflowText(workflow, language: context.language).title,
              ),
              subtitle: Text(
                workflowText(workflow, language: context.language).subtitle,
              ),
              trailing: _starting == workflow
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              enabled: _starting == null && !_busy,
              onTap: () => _send(workflow),
            ),
          ],
      ],
    );
  }
}

/// Quiet hours: on or off, and from which hour to which (Portugal time).
class const _QuietHoursDialog(final QuietHours initial) extends StatefulWidget {
  @override
  State<_QuietHoursDialog> createState() => _QuietHoursDialogState();
}

class _QuietHoursDialogState extends State<_QuietHoursDialog> {
  late QuietHours _hours = widget.initial;

  Widget _hour(String label, int value, ValueChanged<int> onChanged) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var hour = 0; hour < 24; hour++)
            DropdownMenuItem(value: hour, child: Text(quietHourText(hour))),
        ],
        onChanged: _hours.enabled
            ? (hour) {
                if (hour != null) onChanged(hour);
              }
            : null,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.quietHours),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.quietHoursSwitch),
              value: _hours.enabled,
              onChanged: (on) =>
                  setState(() => _hours = _hours.copyWith(enabled: on)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _hour(
                    context.strings.quietHoursFrom,
                    _hours.startHour,
                    (hour) => setState(
                      () => _hours = _hours.copyWith(startHour: hour),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _hour(
                    context.strings.quietHoursTo,
                    _hours.endHour,
                    (hour) =>
                        setState(() => _hours = _hours.copyWith(endHour: hour)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(context.strings.quietHoursHelp),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          // The database refuses equal hours (no quiet time at all).
          onPressed: _hours.startHour == _hours.endHour
              ? null
              : () => Navigator.of(context).pop(_hours),
          child: Text(context.strings.save),
        ),
      ],
    );
  }
}
