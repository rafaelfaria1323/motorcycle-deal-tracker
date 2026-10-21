import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/platform/push.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/push_repository.dart';
import '../domain/workflows_repository.dart';
import 'push_text.dart';
import 'start_workflow.dart';
import 'workflows_text.dart';

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
    if (!mounted) return;
    setState(() {
      _state = state;
      _publicKey = key;
    });
  }

  Future<void> _set(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final key = _publicKey;
    if (on && key == null) {
      showMessage(
        messenger,
        'As notificações ficam disponíveis depois da próxima recolha.',
      );
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
            ? 'Não foi possível ativar as notificações. Verifique a permissão '
                  'e tente novamente.'
            : 'Não foi possível desativar. Tente novamente.',
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = workflow);
    final message = await startWorkflow(workflow);
    if (!mounted) return;
    setState(() => _starting = null);
    showMessage(messenger, message);
  }

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
          title: const Text('Notificações neste aparelho'),
          subtitle: Text(
            state == null
                ? 'A verificar…'
                : pushSubtitle(state, signedIn: widget.signedIn),
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
              title: Text(workflowText(workflow).title),
              subtitle: Text(workflowText(workflow).subtitle),
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
