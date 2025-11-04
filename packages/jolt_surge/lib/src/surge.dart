import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'observer.dart';
import 'shared.dart';

/// Function type for creating a writable reactive value from initial state.
///
/// This typedef defines a function that takes an initial state value and
/// returns a [JWritableValue] to manage that state reactively.
///
/// Example:
/// ```dart
/// SurgeStateCreator<int> creator = (state) => Signal(state);
/// final value = creator(42); // Creates a Signal(42)
/// ```
typedef SurgeStateCreator<T> = JWritableValue<T> Function(T state);

Signal<T> _defaultSignalCreator<T>(T state) => Signal(state);

/// Base class for state management in the Surge pattern.
///
/// Surge provides a reactive state management pattern that combines
/// a state value with change notifications and lifecycle management.
/// It uses a [JWritableValue] internally to manage the state reactively.
///
/// Example:
/// ```dart
/// class CounterSurge extends Surge<int> {
///   CounterSurge() : super(0);
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
/// }
///
/// final counter = CounterSurge();
/// print(counter.state); // 0
/// counter.increment();
/// print(counter.state); // 1
/// ```
abstract class Surge<State> implements ChainedDisposable {
  /// Creates a new surge with the given initial state.
  ///
  /// Parameters:
  /// - [initialState]: The initial state value
  /// - [creator]: Optional function to create the reactive value. If not provided,
  ///   defaults to creating a [Signal] with the initial state.
  ///
  /// The creator function allows you to customize how the state is managed,
  /// for example using a different reactive value type or adding additional
  /// behavior.
  ///
  /// Example:
  /// ```dart
  /// class MySurge extends Surge<String> {
  ///   MySurge(String initial) : super(initial);
  /// }
  ///
  /// // With custom creator
  /// class CustomSurge extends Surge<int> {
  ///   CustomSurge(int initial) : super(initial, creator: (state) => WritableComputed(...));
  /// }
  /// ```
  Surge(State initialState, {SurgeStateCreator<State>? creator})
      : _state = (creator ?? _defaultSignalCreator)(initialState) {
    SurgeObserver.observer?.onCreate(this);
  }

  /// The internal reactive value that manages the state.
  final JWritableValue<State> _state;

  /// Whether this surge has been disposed.
  bool _isDisposed = false;

  /// Gets the current state value.
  ///
  /// Returns: The current state value
  ///
  /// This getter provides reactive access to the state. When accessed within
  /// a reactive context (like an Effect or Computed), it will track dependencies.
  ///
  /// Example:
  /// ```dart
  /// final surge = MySurge(42);
  /// print(surge.state); // 42
  ///
  /// Effect(() => print('State: ${surge.state}'));
  /// surge.emit(43); // Effect prints: "State: 43"
  /// ```
  State get state => _state.value;

  /// Gets the raw reactive value that manages the state.
  ///
  /// Returns: The [JWritableValue] instance that manages the state
  ///
  /// This getter provides direct access to the underlying reactive value,
  /// allowing for advanced use cases where you need direct manipulation
  /// of the reactive value.
  ///
  /// Example:
  /// ```dart
  /// final surge = MySurge(42);
  /// final rawValue = surge.raw;
  /// rawValue.value = 43; // Directly set the value
  /// ```
  JWritableValue<State> get raw => _state;

  /// Gets a stream that emits state changes.
  ///
  /// Returns: A broadcast stream that emits the state value whenever it changes
  ///
  /// The stream emits the current state value whenever the state changes.
  /// Multiple listeners can subscribe to the same stream.
  ///
  /// Example:
  /// ```dart
  /// final surge = MySurge(0);
  /// surge.stream.listen((state) => print('State changed: $state'));
  /// surge.emit(1); // Prints: "State changed: 1"
  /// surge.emit(2); // Prints: "State changed: 2"
  /// ```
  Stream<State> get stream => _state.stream;

  /// Whether this surge has been disposed.
  ///
  /// Returns: true if the surge has been disposed, false otherwise
  ///
  /// Once disposed, the surge will no longer accept state changes via [emit].
  bool get isDisposed => _isDisposed;

  /// Disposes this surge and cleans up resources.
  ///
  /// This method marks the surge as disposed and calls [onDispose] to perform
  /// any additional cleanup. After disposal, calling [emit] will throw an assertion error.
  ///
  /// This method is idempotent - calling it multiple times has no effect.
  ///
  /// Example:
  /// ```dart
  /// final surge = MySurge(42);
  /// surge.dispose();
  /// // surge.emit(43); // Throws assertion error
  /// ```
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();
  }

  /// Emits a new state value and triggers change notifications.
  ///
  /// Parameters:
  /// - [state]: The new state value to emit
  ///
  /// This method updates the state and triggers change notifications. If the
  /// new state is the same as the current state (by equality), no update
  /// or notification occurs.
  ///
  /// Throws an assertion error if the surge has been disposed.
  ///
  /// The [onChange] method is called before the state is updated, allowing
  /// observers to react to the change.
  ///
  /// Example:
  /// ```dart
  /// final surge = MySurge(0);
  /// surge.emit(1); // State changes from 0 to 1
  /// surge.emit(1); // No change (same value)
  /// surge.emit(2); // State changes from 1 to 2
  /// ```
  void emit(State state) {
    assert(!_isDisposed, 'JoltSurge is disposed');

    if (state == _state.peek) return;
    onChange(Change(currentState: _state.peek, nextState: state));
    _state.set(state);
  }

  /// Called when the state changes.
  ///
  /// Parameters:
  /// - [change]: The change object containing the current and next state
  ///
  /// This method is called by [emit] before the state is updated. Subclasses
  /// can override this method to add custom change handling logic, such as
  /// logging, validation, or side effects.
  ///
  /// The default implementation notifies the [SurgeObserver] if one is set.
  ///
  /// Example:
  /// ```dart
  /// class MySurge extends Surge<int> {
  ///   MySurge() : super(0);
  ///
  ///   @override
  ///   void onChange(Change<int> change) {
  ///     print('State changing from ${change.currentState} to ${change.nextState}');
  ///     super.onChange(change);
  ///   }
  /// }
  /// ```
  void onChange(Change<State> change) {
    SurgeObserver.observer?.onChange(this, change);
  }

  /// Called when this surge is being disposed.
  ///
  /// This method is called by [dispose] to perform cleanup operations.
  /// Subclasses can override this method to add custom disposal logic,
  /// such as cleaning up resources or notifying observers.
  ///
  /// The default implementation notifies the [SurgeObserver] if one is set.
  ///
  /// Example:
  /// ```dart
  /// class MySurge extends Surge<int> {
  ///   MySurge() : super(0);
  ///
  ///   @override
  ///   void onDispose() {
  ///     print('Surge is being disposed');
  ///     super.onDispose();
  ///   }
  /// }
  /// ```
  @override
  void onDispose() {
    SurgeObserver.observer?.onDispose(this);
  }
}
