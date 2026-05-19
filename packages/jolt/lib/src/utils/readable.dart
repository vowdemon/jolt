import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

/// Extension methods for [Readable] values.
extension JoltUtilsReadableExtension<T> on Readable<T> {
  /// The current value using callable syntax.
  ///
  /// This is equivalent to reading [Readable.value], so it preserves the same
  /// dependency-tracking behavior.
  T call() => value;

  /// The current value using method syntax.
  ///
  /// This is equivalent to reading [Readable.value], so it preserves the same
  /// dependency-tracking behavior.
  T get() => value;

  /// A computed value derived from this readable.
  ///
  /// The [computed] callback receives this readable's current tracked value and
  /// re-runs whenever that value changes.
  Computed<U> derived<U>(U Function(T value) computed) =>
      Computed(() => computed(value));
}
