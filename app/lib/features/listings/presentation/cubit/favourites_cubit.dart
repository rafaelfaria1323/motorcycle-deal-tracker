import 'dart:math';

import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/favourite.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/favourites_repository.dart';
import 'favourites_state.dart';

/// The user's favourites, shared by Ofertas (the star on cards), the
/// listing page (star and note) and the Favoritos page. Changes show at
/// once and are undone if saving fails.
class FavouritesCubit extends AccountScopedCubit<FavouritesState> {
  FavouritesCubit(
    this._repository,
    SessionCubit session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(session, const FavouritesState());

  final FavouritesRepository _repository;
  final DateTime Function() _clock;
  int _loadGeneration = 0;

  /// Notes are kept to this length (the database refuses longer ones).
  static const maxNoteLength = 2000;

  /// A checklist item's note is kept to this length.
  static const maxChecklistNoteLength = 300;

  /// Loads (or refreshes) the favourites. A failed refresh keeps the list
  /// that is already on screen; an account change clears it first.
  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_loadGeneration;
    if (state.status != FavouritesStatus.success) {
      emit(state.copyWith(status: FavouritesStatus.loading));
    }
    try {
      final favourites = await _repository.getAll();
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: FavouritesStatus.success,
          favourites: favourites,
        ),
      );
    } catch (_) {
      if (!isCurrentAccount(account) || generation != _loadGeneration) return;
      if (state.status != FavouritesStatus.success) {
        emit(state.copyWith(status: FavouritesStatus.failure));
      }
    }
  }

  /// Adds [listing] to the favourites, or takes it out (with its note).
  /// Returns false when saving failed and the change was undone.
  Future<bool> toggle(Listing listing) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
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
      return isCurrentAccount(account);
    } catch (_) {
      if (isCurrentAccount(account)) _undo(listing.id, before);
      return false;
    }
  }

  /// Saves the note of a favourite: trimmed, and an empty one clears it.
  /// Returns false when the listing is not a favourite or saving failed.
  Future<bool> saveNote(String listingId, String text) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
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
      return isCurrentAccount(account);
    } catch (_) {
      if (isCurrentAccount(account)) _undo(listingId, before);
      return false;
    }
  }

  /// Sets the price to be alerted at (null clears it). Returns false when
  /// it could not be saved; the change is undone then.
  Future<bool> saveTargetPrice(String listingId, double? targetPrice) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    final before = state.favourites;
    if (!state.isFavourite(listingId)) return false;

    emit(
      state.copyWith(
        favourites: [
          for (final f in before)
            f.listingId == listingId ? f.withTargetPrice(targetPrice) : f,
        ],
      ),
    );
    try {
      await _repository.saveTargetPrice(listingId, targetPrice);
      return isCurrentAccount(account);
    } catch (_) {
      if (isCurrentAccount(account)) _undo(listingId, before);
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
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
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
      return isCurrentAccount(account);
    } catch (_) {
      if (!isCurrentAccount(account)) return false;
      // Only this item goes back: another one may have been saved since.
      final now = state.favouriteOf(listingId);
      if (now != null) {
        final previous = favourite.checklist[key];
        final restored = {...now.checklist}..remove(key);
        if (previous != null) restored[key] = previous;
        emit(
          state.copyWith(
            favourites: [
              for (final f in state.favourites)
                f.listingId == listingId ? f.withChecklist(restored) : f,
            ],
          ),
        );
      }
      return false;
    }
  }

  /// Puts [listingId]'s favourite back as it was in [before] (or takes it
  /// out), leaving the changes made to other listings since then.
  void _undo(String listingId, List<Favourite> before) {
    final index = before.indexWhere((f) => f.listingId == listingId);
    final rest = [
      for (final f in state.favourites)
        if (f.listingId != listingId) f,
    ];
    if (index >= 0) rest.insert(min(index, rest.length), before[index]);
    emit(state.copyWith(favourites: rest));
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
