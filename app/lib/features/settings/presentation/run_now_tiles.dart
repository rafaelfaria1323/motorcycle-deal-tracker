import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/accounts_repository.dart';
import '../domain/workflows_repository.dart';
import 'workflows_text.dart';

/// For admins, in "Recolha de dados": the "Estado da recolha" page, and
/// starting the collection or the weekly summary now. Nothing for anyone
/// else.
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

  AppWorkflow? _starting;

  Future<void> _start(AppWorkflow workflow) async {
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
    setState(() => _starting = workflow);
    String message;
    try {
      await getIt<WorkflowsRepository>().start(workflow);
      message = text.started;
    } on PostgrestException catch (e) {
      message = startErrorText(e.code);
    } on Exception {
      message = startErrorText(null);
    }
    if (!mounted) return;
    setState(() => _starting = null);
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
            for (final (workflow, icon) in const [
              (AppWorkflow.collect, Icons.play_circle_outline),
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
                enabled: _starting == null,
                onTap: () => _start(workflow),
              ),
            ],
          ],
        );
      },
    );
  }
}
