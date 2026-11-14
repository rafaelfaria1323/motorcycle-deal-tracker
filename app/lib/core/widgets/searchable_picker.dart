import 'package:material_ui/material_ui.dart';

import '../formatting/name_search.dart';
import '../localization/localizations.dart';

/// A form field for one choice out of a long list (a brand, a model):
/// it shows the choice, and a tap opens the list with a search box on
/// top, already focused, that narrows it as one types ([searchByName]).
class const SearchablePickerField<T>({
  required final String label,
  required final List<T> items,
  required final String Function(T) itemLabel,
  required final ValueChanged<T> onSelected,
  required final String searchHint,
  final T? selected,
  final String? errorText,
  final bool enabled = true,
  super.key,
}) extends StatelessWidget {
  Future<void> _open(BuildContext context) async {
    final chosen = await showDialog<_Chosen<T>>(
      context: context,
      builder: (_) => _PickerDialog<T>(
        title: label,
        items: items,
        itemLabel: itemLabel,
        searchHint: searchHint,
        selected: selected,
      ),
    );
    if (chosen != null) onSelected(chosen.value);
  }

  @override
  Widget build(BuildContext context) {
    final value = selected;
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          errorText: errorText,
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value == null ? '' : itemLabel(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// The picked item, so a nullable [T] can still tell "cancelled" apart.
class const _Chosen<T>(final T value);

class const _PickerDialog<T>({
  required final String title,
  required final List<T> items,
  required final String Function(T) itemLabel,
  required final String searchHint,
  required final T? selected,
}) extends StatefulWidget {
  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = searchByName(widget.items, widget.itemLabel, _search.text);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(context.strings.nothingFound))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final item = shown[index];
                        final isSelected = item == widget.selected;
                        return ListTile(
                          title: Text(widget.itemLabel(item)),
                          selected: isSelected,
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(_Chosen(item)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
      ],
    );
  }
}
