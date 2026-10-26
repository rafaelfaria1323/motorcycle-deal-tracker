import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete.dart';
import '../../domain/entities/saved_search.dart';

/// Asks for confirmation; true only if the person chose to delete.
Future<bool> confirmDeleteSavedSearch(
  BuildContext context,
  SavedSearch search,
) {
  return confirmDelete(
    context,
    title: 'Eliminar pesquisa?',
    message:
        'A pesquisa "${search.displayName}" será eliminada. '
        'Esta ação não pode ser desfeita.',
  );
}
