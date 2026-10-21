import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/listing.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';

/// The star in the listing page's app bar: adds the listing to the
/// favourites or takes it out (asking first when that deletes a note).
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({required this.listing, super.key});

  final Listing listing;

  Future<void> _toggle(BuildContext context, FavouritesCubit cubit) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final favourite = cubit.state.favouriteOf(listing.id);
    if (favourite?.note != null && !await _confirmRemove(context)) return;

    final saved = await cubit.toggle(listing);
    if (!saved) {
      showMessage(messenger, 'Não foi possível guardar. Tente novamente.');
    } else if (favourite == null) {
      showMessage(
        messenger,
        'Nos favoritos. Avisamos quando baixar de preço ou sair do mercado.',
      );
    } else {
      showMessage(messenger, 'Retirado dos favoritos');
    }
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar dos favoritos?'),
        content: const Text('A sua nota sobre este anúncio também é apagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<FavouritesCubit>();
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      bloc: cubit,
      buildWhen: (previous, current) =>
          previous.isFavourite(listing.id) != current.isFavourite(listing.id),
      builder: (context, state) {
        final favourite = state.isFavourite(listing.id);
        return IconButton(
          tooltip: favourite
              ? 'Retirar dos favoritos'
              : 'Adicionar aos favoritos',
          isSelected: favourite,
          icon: const Icon(Icons.star_border),
          selectedIcon: const Icon(Icons.star),
          onPressed: () => _toggle(context, cubit),
        );
      },
    );
  }
}

/// "As suas notas" on the listing page, shown while it is a favourite.
class FavouriteNoteCard extends StatelessWidget {
  const FavouriteNoteCard({required this.listingId, super.key});

  final String listingId;

  Future<void> _edit(BuildContext context, String? note) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (_) => NoteDialog(
        title: 'As suas notas',
        initial: note ?? '',
        hintText: 'Ex.: Liguei, ainda disponível. Revisão feita em março.',
        maxLength: FavouritesCubit.maxNoteLength,
      ),
    );
    if (text == null) return;
    final saved = await getIt<FavouritesCubit>().saveNote(listingId, text);
    if (!saved) {
      showMessage(messenger, 'Não foi possível guardar a nota');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      bloc: getIt<FavouritesCubit>(),
      builder: (context, state) {
        final favourite = state.favouriteOf(listingId);
        if (favourite == null) return const SizedBox.shrink();
        final note = favourite.note;
        return Card(
          child: InkWell(
            onTap: () => _edit(context, note),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'As suas notas',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note ??
                              'Toque para escrever o que falta saber, o que '
                                  'o vendedor disse ou quanto quer oferecer.',
                          style: note == null
                              ? theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Edits a note; returns the text, or null if cancelled.
class NoteDialog extends StatefulWidget {
  const NoteDialog({
    required this.title,
    required this.initial,
    required this.hintText,
    required this.maxLength,
    this.minLines = 3,
    super.key,
  });

  final String title;
  final String initial;
  final String hintText;
  final int maxLength;
  final int minLines;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: widget.minLines,
          maxLines: 8,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
