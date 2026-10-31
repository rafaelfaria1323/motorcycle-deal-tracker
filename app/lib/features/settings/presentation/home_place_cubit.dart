import 'package:equatable/equatable.dart';

import '../../../core/auth/account_scoped_cubit.dart';
import '../../../core/auth/session_cubit.dart';
import '../domain/home_repository.dart';
import '../domain/place.dart';

enum HomePlaceStatus { initial, loading, success, failure }

class const HomePlaceState({
  final HomePlaceStatus status = HomePlaceStatus.initial,
  final Place? home,
}) extends Equatable {
  /// Known to have no home, so no listing has a distance: the distance
  /// sort and filter would give nonsense. While the home is loading, or
  /// could not be read, they stay offered.
  bool get noHome => status == .success && home == null;

  @override
  List<Object?> get props => [status, home];
}

/// The account's home place ("A sua localidade" in Mais), which every
/// listing's distance is measured from. Shared by Mais, the sort menu and
/// the filters, so setting it in one enables the distance in the others.
class HomePlaceCubit extends AccountScopedCubit<HomePlaceState> {
  HomePlaceCubit(this._repository, SessionCubit session)
    : super(session, const HomePlaceState());

  final HomeRepository _repository;

  /// Bumped by each load and save: an answer to an older one is dropped.
  var _request = 0;

  @override
  Future<void> load() async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final request = ++_request;
    emit(HomePlaceState(status: .loading, home: state.home));
    try {
      final home = await _repository.getHome();
      if (!isCurrentAccount(account) || request != _request) return;
      emit(HomePlaceState(status: .success, home: home));
    } catch (_) {
      if (!isCurrentAccount(account) || request != _request) return;
      emit(HomePlaceState(status: .failure, home: state.home));
    }
  }

  /// Saves [place] as the account's home; throws when it was not saved.
  Future<void> save(Place place) async {
    final account = accountGeneration;
    if (!isCurrentAccount(account)) return;
    final request = ++_request;
    await _repository.saveHome(place);
    if (!isCurrentAccount(account) || request != _request) return;
    emit(HomePlaceState(status: .success, home: place));
  }
}
