import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/catalog_model.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Lets the owner choose which catalog models are tracked.
class TrackedModelsPage extends StatefulWidget {
  const TrackedModelsPage({super.key});

  @override
  State<TrackedModelsPage> createState() => _TrackedModelsPageState();
}

class _TrackedModelsPageState extends State<TrackedModelsPage> {
  final _repository = getIt<CatalogRepository>();
  List<CatalogModel>? _models;
  bool _failed = false;

  /// Models with a change on its way, so a switch can't be flipped twice.
  final _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final models = await _repository.getModels();
      if (mounted) setState(() => _models = models);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle(CatalogModel model, bool tracked) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving.add(model.id);
      _replace(model.withTracked(tracked));
    });
    try {
      await _repository.setTracked(model.id, tracked: tracked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _replace(model));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível guardar. Confirma que tens sessão iniciada.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(model.id));
    }
  }

  void _replace(CatalogModel model) {
    _models = [for (final m in _models!) m.id == model.id ? model : m];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modelos acompanhados')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar os modelos',
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    final models = _models;
    if (models == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Só os modelos ligados recebem pontuação, alertas e dados de '
            'mercado. As alterações contam a partir da próxima recolha '
            '(até 4 horas), incluindo os anúncios já guardados. Só entram '
            'anúncios das pesquisas configuradas no recolhedor.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final MapEntry(key: brand, value: brandModels) in modelsByBrand(
          models,
        ).entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(brand, style: theme.textTheme.titleMedium),
          ),
          for (final m in brandModels)
            SwitchListTile(
              title: Text(m.model),
              subtitle: Text('Desde ${m.minYear}'),
              value: m.isTracked,
              onChanged: _saving.contains(m.id)
                  ? null
                  : (tracked) => _toggle(m, tracked),
            ),
        ],
      ],
    );
  }
}
