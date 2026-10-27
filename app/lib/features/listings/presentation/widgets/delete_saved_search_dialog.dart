import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete.dart';
import '../../domain/entities/saved_search.dart';
import '../saved_search_summary.dart';
import '../../../../core/localization/localizations.dart';

/// Asks for confirmation; true only if the person chose to delete.
Future<bool> confirmDeleteSavedSearch(
  BuildContext context,
  SavedSearch search,
) {
  return confirmDelete(
    context,
    title: context.strings.deleteSearchDeleteSavedSearchDialog,
    message: context.strings.searchWillBeDeletedThisCannotBeUndone(
      displayName: savedSearchName(search, language: context.language),
    ),
  );
}
