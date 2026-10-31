import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/auth/account_scoped_cubit.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/localization/app_language.dart';
import '../domain/language_repository.dart';

enum LanguageFailure { load, save }

class const LanguageState({
  final AppLanguage language = AppLanguage.portuguese,
  final bool loading = false,
  final bool saving = false,
  final LanguageFailure? failure,
}) extends Equatable {
  @override
  List<Object?> get props => [language, loading, saving, failure];
}

class LanguageCubit extends AccountScopedCubit<LanguageState> {
  LanguageCubit(this._repository, this._session)
    : super(
        _session,
        LanguageState(language: _repository.cached(_account(_session.state))),
      ) {
    unawaited(load());
  }

  final LanguageRepository _repository;
  final SessionCubit _session;
  int _request = 0;

  static String? _account(SessionState session) =>
      session.signedIn ? session.userId : null;

  bool _current(int request, int generation) =>
      request == _request && isCurrentAccount(generation);

  @override
  void resetForAccount() {
    ++_request;
    emit(LanguageState(language: _repository.cached(_account(_session.state))));
  }

  @override
  Future<void> load() async {
    if (isClosed || state.saving) return;
    final request = ++_request;
    final generation = accountGeneration;
    final userId = _account(_session.state);
    if (userId == null) {
      emit(LanguageState(language: _repository.cached(null)));
      return;
    }
    emit(LanguageState(language: state.language, loading: true));
    try {
      final language = await _repository.load(userId);
      if (!_current(request, generation)) return;
      await _repository.remember(userId, language);
      if (!_current(request, generation)) return;
      emit(LanguageState(language: language));
    } on Object {
      if (!_current(request, generation)) return;
      emit(
        LanguageState(language: state.language, failure: LanguageFailure.load),
      );
    }
  }

  Future<bool> select(AppLanguage language) async {
    if (state.loading || state.saving) return false;
    final generation = accountGeneration;
    if (!isCurrentAccount(generation)) return false;
    if (state.language == language && state.failure == null) return true;
    final request = ++_request;
    final userId = _account(_session.state);
    emit(LanguageState(language: state.language, saving: true));
    try {
      if (userId != null) await _repository.save(userId, language);
      if (!_current(request, generation)) return false;
      await _repository.remember(userId, language);
      if (!_current(request, generation)) return false;
      emit(LanguageState(language: language));
      return true;
    } on Object {
      if (!_current(request, generation)) return false;
      emit(
        LanguageState(language: state.language, failure: LanguageFailure.save),
      );
      return false;
    }
  }
}
