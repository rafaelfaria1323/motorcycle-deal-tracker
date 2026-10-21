import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/accounts_repository.dart';
import '../domain/workflows_repository.dart';
import 'start_workflow.dart';
import 'workflows_text.dart';

/// For admins, in "Recolha de dados": the "Estado da recolha" page, and
/// starting the collection now. Nothing for anyone else.
class RunNowTiles extends StatefulWidget {
  const RunNowTiles({required this.signedIn, super.key});

  final bool signedIn;

  @override
  State<RunNowTiles> createState() => _RunNowTilesState();
}

class _RunNowTilesState extends State<RunNowTiles> {
  late final Future<bool> _admin = widget.signedIn
      ? getIt<AccountsRepository>().isAdmin().catchError((Object _) => false)
      : Future.value(false);

  bool _starting = false;

  Future<void> _start() async {
    const workflow = AppWorkflow.collect;
    final text = workflowText(workflow);
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${text.title}?'),
            content: Text('${text.subtitle}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Iniciar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    final message = await startWorkflow(workflow);
    if (!mounted) return;
    setState(() => _starting = false);
    showMessage(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _admin,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Column(
          children: [
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Estado da recolha'),
              subtitle: const Text(
                'Últimas recolhas e erros, pedidos de hoje e o token do GitHub',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.collectionStatus),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(workflowText(AppWorkflow.collect).title),
              subtitle: Text(workflowText(AppWorkflow.collect).subtitle),
              trailing: _starting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              enabled: !_starting,
              onTap: _start,
            ),
          ],
        );
      },
    );
  }
}
