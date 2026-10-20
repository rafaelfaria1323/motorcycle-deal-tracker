import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/favourite.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/favourites_repository.dart';
import 'favourites_state.dart';

/// The user's favourites, shared by Ofertas (the star on cards), the
/// listing page (star and note) and the Favoritos page. Changes show at
/// once and are undone if saving fails.
class FavouritesCubit extends Cubit<FavouritesState> {
  FavouritesCubit(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const FavouritesState());

  final FavouritesRepository _repository;
  final DateTime Function() _clock;

  /// Notes are kept to this length (the database refuses longer ones).
  static const maxNoteLength = 2000;

  /// A checklist item's note is kept to this length.
  static const maxChecklistNoteLength = 300;

  /// Loads (or refreshes) the favourites. A failed refresh keeps the list
  /// that is already on screen.
  Future<void> load() async {
    if (state.status != FavouritesStatus.success) {
      emit(state.copyWith(status: FavouritesStatus.loading));
    }
    try {
      final favourites = await _repository.getAll();
      emit(
        state.copyWith(
          status: FavouritesStatus.success,
          favourites: favourites,
        ),
      );
    } catch (_) {
      if (state.status != FavouritesStatus.success) {
        emit(state.copyWith(status: FavouritesStatus.failure));
      }
    }
  }

  /// Adds [listing] to the favourites, or takes it out (with its note).
  /// Returns false when saving failed and the change was undone.
  Future<bool> toggle(Listing listing) async {
    final before = state.favourites;
    final adding = !state.isFavourite(listing.id);
    emit(
      state.copyWith(
        favourites: adding
            ? [
                Favourite(
                  listingId: listing.id,
                  createdAt: _clock(),
                  listing: listing,
                ),
                ...before,
              ]
            : [
                for (final f in before)
                  if (f.listingId != listing.id) f,
              ],
      ),
    );
    try {
      if (adding) {
        await _repository.add(listing.id);
      } else {
        await _repository.remove(listing.id);
      }
      return true;
    } catch (_) {
      emit(state.copyWith(favourites: before));
      return false;
    }
  }

  /// Saves the note of a favourite: trimmed, and an empty one clears it.
  /// Returns false when the listing is not a favourite or saving failed.
  Future<bool> saveNote(String listingId, String text) async {
    final before = state.favourites;
    if (!state.isFavourite(listingId)) return false;

    final note = normalizeNote(text);
    emit(
      state.copyWith(
        favourites: [
          for (final f in before)
            f.listingId == listingId ? f.withNote(note) : f,
        ],
      ),
    );
    try {
      await _repository.saveNote(listingId, note);
      return true;
    } catch (_) {
      emit(state.copyWith(favourites: before));
      return false;
    }
  }

  /// Saves one item of a favourite's viewing checklist: its mark (null:
  /// not looked at) and note (trimmed; empty clears it). Returns false when
  /// the listing is not a favourite or saving failed.
  Future<bool> saveChecklistItem(
    String listingId,
    String key, {
    ChecklistMark? mark,
    String? note,
  }) async {
    final before = state.favourites;
    final favourite = state.favouriteOf(listingId);
    if (favourite == null) return false;

    final entry = ChecklistEntry(
      mark: mark,
      note: note == null ? null : normalizeNote(note, maxChecklistNoteLength),
    );
    final checklist = {...favourite.checklist}..remove(key);
    if (!entry.isEmpty) checklist[key] = entry;
    emit(
      state.copyWith(
        favourites: [
          for (final f in before)
            f.listingId == listingId ? f.withChecklist(checklist) : f,
        ],
      ),
    );
    try {
      await _repository.saveChecklist(listingId, checklist);
      return true;
    } catch (_) {
      emit(state.copyWith(favourites: before));
      return false;
    }
  }
}

/// The note as stored: without surrounding spaces, at most
/// [maxLength] characters (a favourite's note by default), null when
/// nothing is left.
String? normalizeNote(
  String text, [
  int maxLength = FavouritesCubit.maxNoteLength,
]) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > maxLength
      ? trimmed.substring(0, maxLength).trimRight()
      : trimmed;
}
