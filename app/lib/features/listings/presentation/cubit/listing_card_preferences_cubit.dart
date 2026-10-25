import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_cubit.dart';
import '../../domain/entities/listing_card_preferences.dart';
import '../../domain/repositories/listing_card_preferences_repository.dart';

enum ListingCardPreferencesStatus { loading, success, failure }

class ListingCardPreferencesState extends Equatable {
  const ListingCardPreferencesState({
    this.userId,
    this.preferences = const ListingCardPreferences.defaults(),
    this.status = ListingCardPreferencesStatus.loading,
    this.saving = false,
    this.error,
  });

  final String? userId;
  final ListingCardPreferences preferences;
  final ListingCardPreferencesStatus status;
  final bool saving;
  final String? error;

  ListingCardPreferencesState copyWith({
    ListingCardPreferences? preferences,
    ListingCardPreferencesStatus? status,
    bool? saving,
    String? error,
  }) => ListingCardPreferencesState(
    userId: userId,
    preferences: preferences ?? this.preferences,
    status: status ?? this.status,
    saving: saving ?? this.saving,
    error: error,
  );

  @override
  List<Object?> get props => [userId, preferences, status, saving, error];
}

class ListingCardPreferencesCubit extends Cubit<ListingCardPreferencesState> {
  ListingCardPreferencesCubit(this._repository, this._session)
    : super(const ListingCardPreferencesState()) {
    _subscription = _session.stream.listen((session) {
      if (_accountId(session) != state.userId) unawaited(load());
    });
    unawaited(load());
  }

  final ListingCardPreferencesRepository _repository;
  final SessionCubit _session;
  late final StreamSubscription<SessionState> _subscription;
  int _request = 0;

  static String? _accountId(SessionState session) =>
      session.signedIn ? session.userId : null;

  bool _current(int request, String userId) =>
      !isClosed && request == _request && userId == _accountId(_session.state);

  Future<void> load() async {
    final request = ++_request;
    final userId = _accountId(_session.state);
    emit(
      ListingCardPreferencesState(
        userId: userId,
        preferences: userId == state.userId
            ? state.preferences
            : const ListingCardPreferences.defaults(),
        status: userId == null
            ? ListingCardPreferencesStatus.success
            : ListingCardPreferencesStatus.loading,
      ),
    );
    if (userId == null) return;

    try {
      final preferences = await _repository.get(userId);
      if (!_current(request, userId)) return;
      emit(
        state.copyWith(
          preferences: preferences,
          status: ListingCardPreferencesStatus.success,
        ),
      );
    } catch (_) {
      if (!_current(request, userId)) return;
      emit(
        state.copyWith(
          status: ListingCardPreferencesStatus.failure,
          error: 'Não foi possível carregar as suas escolhas. Tente novamente.',
        ),
      );
    }
  }

  Future<bool> save(ListingCardPreferences preferences) async {
    final userId = state.userId;
    if (userId == null || userId != _accountId(_session.state)) {
      emit(
        state.copyWith(error: 'Inicie sessão para personalizar os cartões.'),
      );
      return false;
    }
    if (state.saving) return false;
    if (state.status != ListingCardPreferencesStatus.success) {
      emit(
        state.copyWith(error: 'Carregue as suas escolhas antes de guardar.'),
      );
      return false;
    }

    final request = ++_request;
    emit(state.copyWith(saving: true));
    try {
      await _repository.save(userId, preferences);
      if (!_current(request, userId)) return false;
      emit(state.copyWith(preferences: preferences, saving: false));
      return true;
    } catch (_) {
      if (!_current(request, userId)) return false;
      emit(
        state.copyWith(
          saving: false,
          error: 'Não foi possível guardar as suas escolhas. Tente novamente.',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    ++_request;
    await _subscription.cancel();
    await super.close();
  }
}
