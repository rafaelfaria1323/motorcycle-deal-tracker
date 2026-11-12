import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/favourite.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../domain/repositories/favourites_repository.dart';
import 'favourites_state.dart';

/// The user's favourites, shared by Ofertas (the star on cards), the
/// listing page (star and note) and the Favoritos page. Changes show at
/// once and are undone if saving fails, except the viewing checklist's:
/// without a connection (at the viewing) it is kept on this device and
/// sent later (N.66).
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
  bool _sending = false;

  /// Notes are kept to this length (the database refuses longer ones).
  static const maxNoteLength = 2000;

  /// A checklist item's note is kept to this length.
  static const maxChecklistNoteLength = 300;

  /// Loads (or refreshes) the favourites, after sending the checklists
  /// kept on this device. A failed refresh keeps the list that is already
  /// on screen; with none, this device's last copy is shown
  /// ([FavouritesState.fromDevice]). An account change clears it first.
  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final generation = ++_loadGeneration;
    if (state.status != .success) {
      emit(state.copyWith(status: FavouritesStatus.loading));
    }
    await sendUnsent();
    bool current() =>
        isCurrentAccount(account) && generation == _loadGeneration;
    if (!current()) return;
    final unsent = await _unsent();
    try {
      final favourites = await _repository.getAll();
      if (!current()) return;
      emit(
        state.copyWith(
          status: FavouritesStatus.success,
          favourites: _withUnsent(favourites, unsent),
          fromDevice: false,
          unsent: unsent.keys.toSet(),
        ),
      );
    } catch (_) {
      if (!current() || state.status == .success) return;
      List<Favourite>? copy;
      try {
        copy = await _repository.lastCopy();
      } catch (_) {}
      if (!current() || state.status == .success) return;
      emit(
        copy == null
            ? state.copyWith(status: FavouritesStatus.failure)
            : state.copyWith(
                status: FavouritesStatus.success,
                favourites: _withUnsent(copy, unsent),
                fromDevice: true,
                unsent: unsent.keys.toSet(),
              ),
      );
    }
  }

  /// Sends the checklists kept on this device, oldest change first, until
  /// one fails for want of a connection. One the database refuses (no
  /// longer a favourite) is dropped. Never throws.
  Future<void> sendUnsent() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account) || _sending) return;
    _sending = true;
    try {
      for (final MapEntry(key: listingId, value: checklist)
          in (await _unsent()).entries) {
        if (!isCurrentAccount(account)) return;
        try {
          await _repository.saveChecklist(listingId, checklist);
        } on StateError {
          // Taken out of the favourites meanwhile: nothing to send.
        } catch (_) {
          break;
        }
        if (!isCurrentAccount(account)) return;
        // A newer change made while this one was on its way stays.
        final now = await _unsent();
        if (mapEquals(now[listingId], checklist)) {
          await _repository.keepUnsentChecklist(listingId, null);
        }
      }
    } catch (_) {
      // This device's copy can't be read or written: nothing to do.
    } finally {
      _sending = false;
    }
    if (isCurrentAccount(account)) await _showUnsent(account);
  }

  Future<Map<String, Map<String, ChecklistEntry>>> _unsent() async {
    try {
      return await _repository.unsentChecklists();
    } catch (_) {
      return const {};
    }
  }

  Future<void> _showUnsent(int account) async {
    final unsent = (await _unsent()).keys.toSet();
    if (isCurrentAccount(account) && !setEquals(unsent, state.unsent)) {
      emit(state.copyWith(unsent: unsent));
    }
  }

  /// The checklists kept on this device are newer than the database's.
  static List<Favourite> _withUnsent(
    List<Favourite> favourites,
    Map<String, Map<String, ChecklistEntry>> unsent,
  ) => [
    for (final f in favourites)
      if (unsent[f.listingId] case final checklist?)
        f.withChecklist(checklist)
      else
        f,
  ];

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

  /// Plans the visit to the bike (null clears it). Returns false when it
  /// could not be saved; the change is undone then.
  Future<bool> saveVisit(String listingId, DateTime? visitAt) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    final before = state.favourites;
    if (!state.isFavourite(listingId)) return false;

    emit(
      state.copyWith(
        favourites: [
          for (final f in before)
            f.listingId == listingId ? f.withVisit(visitAt) : f,
        ],
      ),
    );
    try {
      await _repository.saveVisit(listingId, visitAt);
      return isCurrentAccount(account);
    } catch (_) {
      if (isCurrentAccount(account)) _undo(listingId, before);
      return false;
    }
  }

  /// Saves one item of a favourite's viewing checklist: its mark (null:
  /// not looked at) and note (trimmed; empty clears it). Without a
  /// connection the change stays and is kept on this device
  /// ([ChecklistSave.kept]); it is undone ([ChecklistSave.failed]) when the
  /// listing is not a favourite or neither could take it.
  Future<ChecklistSave> saveChecklistItem(
    String listingId,
    String key, {
    ChecklistMark? mark,
    String? note,
  }) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return ChecklistSave.failed;
    final before = state.favourites;
    final favourite = state.favouriteOf(listingId);
    if (favourite == null) return ChecklistSave.failed;

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
      if (!isCurrentAccount(account)) return ChecklistSave.failed;
      if (state.unsent.isNotEmpty) {
        // This listing's whole checklist is in; the others may go now too.
        try {
          await _repository.keepUnsentChecklist(listingId, null);
        } catch (_) {}
        unawaited(sendUnsent());
      }
      return ChecklistSave.saved;
    } on StateError {
      if (isCurrentAccount(account)) _undoItem(listingId, key, favourite);
      return ChecklistSave.failed;
    } catch (_) {
      if (!isCurrentAccount(account)) return ChecklistSave.failed;
      try {
        await _repository.keepUnsentChecklist(listingId, checklist);
      } catch (_) {
        if (isCurrentAccount(account)) _undoItem(listingId, key, favourite);
        return ChecklistSave.failed;
      }
      if (!isCurrentAccount(account)) return ChecklistSave.failed;
      emit(state.copyWith(unsent: {...state.unsent, listingId}));
      return ChecklistSave.kept;
    }
  }

  /// Puts only [key] back as it was in [favourite]: another item may have
  /// been saved since.
  void _undoItem(String listingId, String key, Favourite favourite) {
    final now = state.favouriteOf(listingId);
    if (now == null) return;
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

/// How saving a checklist item went: in the database, kept on this
/// device until there is a connection, or undone.
enum ChecklistSave { saved, kept, failed }

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
