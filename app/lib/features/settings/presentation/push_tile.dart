import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/platform/push.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/push_repository.dart';
import '../domain/workflows_repository.dart';
import 'push_text.dart';
import 'start_workflow.dart';
import 'workflows_text.dart';
import '../../../core/localization/localizations.dart';

/// "Notificações neste aparelho" in Mais: the account's alerts as
/// notifications on this phone or computer (Web Push). When they are on,
/// a test notification or the weekly summary can be asked for now (sent by
/// the collector, so it checks the whole path to the device).
class PushTile extends StatefulWidget {
  const PushTile({required this.signedIn, super.key});

  final bool signedIn;

  @override
  State<PushTile> createState() => _PushTileState();
}

class _PushTileState extends State<PushTile> {
  final _repository = getIt<PushRepository>();
  PushState? _state;
  bool _busy = false;

  /// The workflow being started from here (test, weekly summary).
  AppWorkflow? _starting;

  /// Read ahead: Safari asks for permission only straight after a tap, so
  /// nothing may be awaited between the tap and the request.
  String? _publicKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await DevicePush.state().catchError(
      (Object _) => PushState.unsupported,
    );
    final key = await _repository.publicKey().catchError((Object _) => null);
    // The browser's subscription is what the switch shows: store it again
    // for this account, in case the database lost it (a failed save, a
    // device the collector forgot, another account signed in here).
    if (state == PushState.on && key != null && widget.signedIn) {
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
    if (workflow == AppWorkflow.pushTest) {
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
            value: state == PushState.on,
            onChanged: enabled ? _set : null,
          ),
        ),
        if (widget.signedIn && state == PushState.on)
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
