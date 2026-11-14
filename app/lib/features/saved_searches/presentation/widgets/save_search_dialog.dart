import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../listings/domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';
import '../cubit/saved_searches_cubit.dart';
import '../saved_search_summary.dart';

/// Saves [filters] as a search after asking for its name ([suggestion]
/// first), unless one like it is saved already; says how it went. Shared
/// by Ofertas' "Guardar pesquisa" and Favoritos' "Avisar-me de uma
/// parecida" (N.84).
Future<void> saveSearchWithName(
  BuildContext context,
  ListingFilters filters, {
  required String suggestion,
}) async {
  final messageStrings = context.strings;
  final messageLanguage = context.language;
  final messenger = ScaffoldMessenger.of(context);
  final searches = getIt<SavedSearchesCubit>();

  // The list loads with the Pesquisas tab: without it the same search
  // could be saved again.
  if (searches.state.status != .success) {
    await searches.load();
  }
  if (savedSearchLike(searches.state.searches, filters) case final same?) {
    showMessage(messenger, alreadySavedText(same, language: messageLanguage));
    return;
  }
  if (!context.mounted) return;

  final name = await showSaveSearchDialog(context, suggestion: suggestion);
  if (name == null) return;

  final saved = await searches.create(name, filters);
  showMessage(
    messenger,
    saved ? messageStrings.searchSaved : messageStrings.couldNotSaveSearch,
  );
}

/// Asks for a name; returns null if cancelled.
Future<String?> showSaveSearchDialog(
  BuildContext context, {
  String suggestion = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SaveSearchDialog(suggestion: suggestion),
  );
}

class const _SaveSearchDialog({required final String suggestion})
    extends StatefulWidget {
  @override
  State<_SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<_SaveSearchDialog> {
  late final _controller = TextEditingController(text: widget.suggestion);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.saveSearch),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: context.strings.name),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? context.strings.enterName
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.strings.save)),
      ],
    );
  }
}
