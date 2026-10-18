import 'package:flutter/material.dart';

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

class _SaveSearchDialog extends StatefulWidget {
  const _SaveSearchDialog({required this.suggestion});

  final String suggestion;

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
      title: const Text('Guardar pesquisa'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Nome'),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Indique um nome'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
