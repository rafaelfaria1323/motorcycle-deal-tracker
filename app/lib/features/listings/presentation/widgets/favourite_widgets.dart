import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/listing.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../../../../core/localization/localizations.dart';

/// The star in the listing page's app bar: adds the listing to the
/// favourites or takes it out (asking first when that deletes a note).
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({required this.listing, super.key});

  final Listing listing;

  Future<void> _toggle(BuildContext context, FavouritesCubit cubit) async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final favourite = cubit.state.favouriteOf(listing.id);
    if (favourite?.note != null && !await _confirmRemove(context)) return;

    final saved = await cubit.toggle(listing);
    if (!saved) {
      showMessage(messenger, messageStrings.couldNotSaveTryAgain);
    } else if (favourite == null) {
      showMessage(messenger, messageStrings.addedToFavouritesWeWillAlertYouIf);
    } else {
      showMessage(messenger, messageStrings.removedFromFavourites);
    }
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.removeFromFavourites),
        content: Text(context.strings.yourNoteAboutThisListingWillAlsoBe),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.remove),
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
              ? context.strings.removeFromFavouritesFavouriteWidgets
              : context.strings.addToFavourites,
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
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (localizationContext) => NoteDialog(
        title: localizationContext.strings.yourNotes,
        initial: note ?? '',
        hintText: localizationContext.strings.favouriteNoteHint,
        maxLength: FavouritesCubit.maxNoteLength,
      ),
    );
    if (text == null) return;
    final saved = await getIt<FavouritesCubit>().saveNote(listingId, text);
    if (!saved) {
      showMessage(messenger, messageStrings.couldNotSaveNote);
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
                          context.strings.yourNotes,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note ?? context.strings.tapToWriteWhatYouStillNeedTo,
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
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.strings.save),
        ),
      ],
    );
  }
}
