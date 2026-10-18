import 'package:flutter/material.dart';

import '../../domain/entities/saved_search.dart';

/// Asks for confirmation; true only if the person chose to delete.
Future<bool> confirmDeleteSavedSearch(
  BuildContext context,
  SavedSearch search,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar pesquisa?'),
      content: Text(
        'A pesquisa "${search.displayName}" será eliminada. '
        'Esta ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
