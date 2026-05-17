/// Marker interface for mutable collection types.
///
/// Used internally to identify reactive collections that need special
/// change detection handling.
///
/// Example:
/// ```dart
/// class MutableListSignal<T> extends ListSignal<T>
///     implements IMutableCollection<T> {}
/// ```
abstract interface class IMutableCollection<T> {
  /// Returns a skip function if target is a mutable collection.
  ///
  /// Parameters:
  /// - [target]: The object to check
  ///
  /// Returns: A function that always returns true (skip change detection),
  /// or null if target is not a mutable collection
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static bool Function(dynamic, dynamic)? skipNode(dynamic target) =>
      target is IMutableCollection ? _skip : null;

  static bool _skip(dynamic newValue, dynamic oldValue) {
    return true;
  }
}
