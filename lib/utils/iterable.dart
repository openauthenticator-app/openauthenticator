/// Contains some useful iterable methods.
extension IterableUtils<T> on Iterable<T> {
  /// Returns the first element satisfying [test], or `null` if there are none.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

/// Returns whether the given type [S] is a subtype of type [T].
bool isSubtype<S, T>() => <S>[] is List<T>;
