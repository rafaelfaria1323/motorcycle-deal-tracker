import 'package:flutter_bloc/flutter_bloc.dart';

import '../compare_text.dart';

/// The listings picked for the comparison (ids, in the order picked), at
/// most [maxCompared]. Shared by Ofertas and the listing page; kept only
/// while the app is open.
class CompareCubit extends Cubit<List<String>> {
  CompareCubit() : super(const []);

  bool contains(String id) => state.contains(id);

  /// Adds or removes [id]; returns false when it could not be added
  /// because the comparison is full.
  bool toggle(String id) {
    if (state.contains(id)) {
      emit([
        for (final other in state)
          if (other != id) other,
      ]);
      return true;
    }
    if (state.length >= maxCompared) return false;
    emit([...state, id]);
    return true;
  }

  void clear() => emit(const []);
}
