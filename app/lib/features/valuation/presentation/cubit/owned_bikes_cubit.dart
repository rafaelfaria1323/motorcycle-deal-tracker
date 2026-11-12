import 'package:equatable/equatable.dart';

import '../../../../core/auth/account_scoped_cubit.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/owned_bike.dart';
import '../../domain/repositories/owned_bikes_repository.dart';

enum OwnedBikesStatus { initial, loading, success, failure }

class const OwnedBikesState({
  final OwnedBikesStatus status = OwnedBikesStatus.initial,
  final List<OwnedBike> bikes = const [],
}) extends Equatable {
  /// The bike bought from ad [listingId]; null when none was.
  OwnedBike? boughtFrom(String listingId) {
    for (final bike in bikes) {
      if (bike.purchase.listingId == listingId) return bike;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, bikes];
}

/// The account's own bikes ("A minha mota", N.67): shared by that page
/// and each ad's "Comprei esta", so a purchase shows in both. Anonymous
/// sessions have none.
class OwnedBikesCubit extends AccountScopedCubit<OwnedBikesState> {
  OwnedBikesCubit(this._repository, this._session)
    : super(_session, const OwnedBikesState());

  final OwnedBikesRepository _repository;
  final SessionCubit _session;

  /// Bumped by each load: an answer to an older one is dropped.
  var _request = 0;

  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final request = ++_request;
    if (!_session.state.signedIn) {
      emit(const OwnedBikesState(status: .success));
      return;
    }
    emit(OwnedBikesState(status: .loading, bikes: state.bikes));
    try {
      final bikes = await _repository.list();
      if (!isCurrentAccount(account) || request != _request) return;
      emit(OwnedBikesState(status: .success, bikes: bikes));
    } catch (_) {
      if (!isCurrentAccount(account) || request != _request) return;
      emit(OwnedBikesState(status: .failure, bikes: state.bikes));
    }
  }

  /// Adds a bike (or updates the one bought from the same ad); false when
  /// it was not saved.
  Future<bool> add(OwnedBikeDraft bike) => _write(() => _repository.add(bike));

  Future<bool> edit(String id, OwnedBikeDraft bike) =>
      _write(() => _repository.update(id, bike));

  Future<bool> remove(String id) => _write(() => _repository.delete(id));

  /// Runs [write], then reads the list again (its model's names and
  /// figures come from the database).
  Future<bool> _write(Future<void> Function() write) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return false;
    try {
      await write();
    } catch (_) {
      return false;
    }
    if (isCurrentAccount(account)) await load();
    return true;
  }
}
