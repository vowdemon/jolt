import 'package:jolt/jolt.dart' as jolt;

import 'signal.dart';
import '../mixins/value_notifier.dart';

/// A computed signal that derives its value from other signals and integrates with Flutter.
///
/// [Computed] automatically recalculates its value when any of the signals it depends on
/// change. It's read-only and integrates with Flutter's ValueNotifier system for
/// seamless widget integration.
///
/// ## Parameters
///
/// - [getter]: Function that computes the value based on other signals
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // "John Doe"
///
/// firstName.value = 'Jane';
/// print(fullName.value); // "Jane Doe" (automatically updated)
/// ```
class Computed<T> extends jolt.Computed<T> with JoltValueNotifier<T> {
  Computed(super.getter, {super.autoDispose});

  /// Throws an [UnsupportedError] when attempting to set the value.
  ///
  /// Computed signals are read-only and derive their values from other signals.
  /// Use [WritableComputed] if you need a computed signal that can be written to.
  ///
  /// ## Parameters
  ///
  /// - [newValue]: The value to set (will cause an error)
  ///
  /// ## Throws
  ///
  /// [UnsupportedError] always, as computed signals are read-only
  @override
  set value(T newValue) {
    throw UnsupportedError('Computed is not supported');
  }
}

/// A computed signal that can also be written to, with custom getter and setter logic.
///
/// [WritableComputed] provides both computed behavior (automatic recalculation when
/// dependencies change) and the ability to write values through a custom setter function.
/// This is useful for creating bidirectional computed values.
///
/// ## Parameters
///
/// - [getter]: Function that computes the value based on other signals
/// - [setter]: Function that handles writing new values
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final celsius = Signal(0.0);
///
/// final fahrenheit = WritableComputed(
///   () => celsius.value * 9 / 5 + 32,
///   (value) => celsius.value = (value - 32) * 5 / 9,
/// );
///
/// print(fahrenheit.value); // 32.0
///
/// fahrenheit.value = 100.0;
/// print(celsius.value); // 37.777...
/// ```
class WritableComputed<T> extends jolt.WritableComputed<T>
    with JoltValueNotifier<T>
    implements Signal<T>, Computed<T> {
  WritableComputed(super.getter, super.setter, {super.autoDispose});
}

/// Extension methods for [WritableComputed] to provide additional Flutter integration.
extension JoltFlutterWritableComputedExtension<T> on WritableComputed<T> {
  /// Returns a read-only view of this writable computed signal.
  ///
  /// This method provides a way to expose a writable computed signal as read-only
  /// to prevent external code from modifying its value while still allowing observation.
  ///
  /// ## Returns
  ///
  /// A [Computed] view of this writable computed signal
  ///
  /// ## Example
  ///
  /// ```dart
  /// final _temperature = WritableComputed(
  ///   () => _celsius.value * 9 / 5 + 32,
  ///   (f) => _celsius.value = (f - 32) * 5 / 9,
  /// );
  ///
  /// Computed<double> get temperature => _temperature.readonly();
  ///
  /// // External code can only read, not write
  /// print(temperature.value); // OK
  /// // temperature.value = 100; // Compile error
  /// ```
  Computed<T> readonly() => this;
}
