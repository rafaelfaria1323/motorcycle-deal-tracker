import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../domain/entities/favourite.dart';
import '../favourites_text.dart';
import '../viewing_checklist.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../../../../core/localization/localizations.dart';

/// Adds [listing] to the favourites or takes it out (asking first when
/// that deletes a note), and says how it went: the listing page's star and
/// the card's.
Future<void> toggleFavourite(BuildContext context, Listing listing) async {
  final cubit = getIt<FavouritesCubit>();
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

/// The star in the listing page's app bar ([toggleFavourite]).
class const FavouriteButton({required final Listing listing, super.key})
    extends StatelessWidget {
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
          onPressed: () => toggleFavourite(context, listing),
        );
      },
    );
  }
}

/// "As suas notas" on the listing page, shown while it is a favourite.
class const FavouriteNoteCard({required final String listingId, super.key})
    extends StatelessWidget {
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

/// What changed since the favourite was last opened (N.97,
/// `favouriteChangesText`): in Favoritos under the card, and on the ad's
/// page the first time it is opened after.
class const FavouriteChangesLine({required final String text, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.update, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.titleSmall)),
      ],
    );
  }
}

/// Edits a note; returns the text, or null if cancelled.
class const NoteDialog({
  required final String title,
  required final String initial,
  required final String hintText,
  required final int maxLength,
  final int minLines = 3,
  super.key,
}) extends StatefulWidget {
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

/// Under a favourite's card, in Favoritos and in a list shared with the
/// account (16.11): its note, the planned visit, the checklist and since
/// when it is a favourite.
class const FavouriteFacts({required final Favourite favourite, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final f = favourite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (f.note != null) ...[
          Text(f.note!, style: body),
          const SizedBox(height: 4),
        ],
        if (f.visitAt case final visit?) ...[
          Text(visitText(visit, language: context.language), style: body),
          const SizedBox(height: 4),
        ],
        if (f.checklist.isNotEmpty) ...[
          Text(
            checklistIssuesText(
                  f.checklist,
                  language: context.language,
                  listing: f.listing,
                ) ??
                checklistSummaryText(
                  f.checklist,
                  language: context.language,
                  listing: f.listing,
                ),
            style: body,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          favouriteSinceText(f, language: context.language),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
