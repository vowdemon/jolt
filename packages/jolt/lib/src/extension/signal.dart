import 'package:jolt/src/async.dart';
import 'package:jolt/src/collection/iterable_signal.dart';
import 'package:jolt/src/collection/list_signal.dart';
import 'package:jolt/src/collection/map_signal.dart';
import 'package:jolt/src/collection/set_signal.dart';
import 'package:jolt/src/signal.dart';

/// Extension methods for converting any object to a reactive signal.
extension JoltObjectExtension<T extends Object?> on T {
  /// Converts this object to a reactive signal.
  ///
  /// Returns: A new Signal containing this object as its initial value
  ///
  /// Example:
  /// ```dart
  /// final nameSignal = 'Alice'.toSignal();
  /// final countSignal = 42.toSignal();
  /// final listSignal = [1, 2, 3].toSignal();
  /// ```
  Signal<T> toSignal() => Signal(this);
}

/// Extension methods for converting List to reactive ListSignal.
extension JoltListExtension<E> on List<E> {
  /// Converts this list to a reactive list signal.
  ///
  /// The resulting ListSignal provides reactive access to list operations
  /// and automatically notifies subscribers when the list changes.
  ///
  /// Returns: A new ListSignal containing this list as its initial value
  ///
  /// Example:
  /// ```dart
  /// final numbers = [1, 2, 3].toListSignal();
  ///
  /// Effect(() => print('Length: ${numbers.length}'));
  ///
  /// numbers.add(4); // Triggers effect: "Length: 4"
  /// ```
  ListSignal<E> toListSignal() => ListSignal(this);
}

/// Extension methods for converting Map to reactive MapSignal.
extension JoltMapExtension<K, V> on Map<K, V> {
  /// Converts this map to a reactive map signal.
  ///
  /// The resulting MapSignal provides reactive access to map operations
  /// and automatically notifies subscribers when the map changes.
  ///
  /// Returns: A new MapSignal containing this map as its initial value
  ///
  /// Example:
  /// ```dart
  /// final userMap = {'name': 'Alice', 'age': 30}.toMapSignal();
  ///
  /// Effect(() => print('User: ${userMap['name']}'));
  ///
  /// userMap['name'] = 'Bob'; // Triggers effect: "User: Bob"
  /// ```
  MapSignal<K, V> toMapSignal() => MapSignal(this);
}

/// Extension methods for converting Set to reactive SetSignal.
extension JoltSetExtension<E> on Set<E> {
  /// Converts this set to a reactive set signal.
  ///
  /// The resulting SetSignal provides reactive access to set operations
  /// and automatically notifies subscribers when the set changes.
  ///
  /// Returns: A new SetSignal containing this set as its initial value
  ///
  /// Example:
  /// ```dart
  /// final tags = {'dart', 'flutter'}.toSetSignal();
  ///
  /// Effect(() => print('Tags: ${tags.join(', ')}'));
  ///
  /// tags.add('reactive'); // Triggers effect: "Tags: dart, flutter, reactive"
  /// ```
  SetSignal<E> toSetSignal() => SetSignal(this);
}

/// Extension methods for converting Iterable to reactive IterableSignal.
extension JoltIterableExtension<E> on Iterable<E> {
  /// Converts this iterable to a reactive iterable signal.
  ///
  /// The resulting IterableSignal provides reactive access to the iterable
  /// through a getter function that returns the current iterable.
  ///
  /// Returns: A new IterableSignal that lazily evaluates this iterable
  ///
  /// Example:
  /// ```dart
  /// final range = Iterable.generate(5).toIterableSignal();
  ///
  /// Effect(() => print('Items: ${range.toList()}'));
  /// ```
  IterableSignal<E> toIterableSignal() => IterableSignal(() => this);
}

/// Extension methods for converting Future to reactive AsyncSignal.
extension JoltFutureExtension<T> on Future<T> {
  /// Converts this future to a reactive async signal.
  ///
  /// The resulting FutureSignal automatically manages the async state
  /// transitions from loading to success/error, providing reactive
  /// access to the future's progress and result.
  ///
  /// Returns: A new FutureSignal that manages this future's lifecycle
  ///
  /// Example:
  /// ```dart
  /// final dataSignal = fetchUserData().toAsyncSignal();
  ///
  /// Effect(() {
  ///   final state = dataSignal.value;
  ///   if (state.isLoading) print('Loading user data...');
  ///   if (state.isSuccess) print('User: ${state.data}');
  ///   if (state.isError) print('Error: ${state.error}');
  /// });
  /// ```
  FutureSignal<T> toAsyncSignal() => FutureSignal(this);
}

/// Extension methods for converting Stream to reactive StreamSignal.
extension JoltStreamExtension<T> on Stream<T> {
  /// Converts this stream to a reactive stream signal.
  ///
  /// The resulting StreamSignal automatically manages the stream's
  /// lifecycle and provides reactive access to stream events through
  /// async state transitions.
  ///
  /// Returns: A new StreamSignal that manages this stream's lifecycle
  ///
  /// Example:
  /// ```dart
  /// final eventSignal = eventStream.toStreamSignal();
  ///
  /// Effect(() {
  ///   final state = eventSignal.value;
  ///   if (state.isLoading) print('Waiting for events...');
  ///   if (state.isSuccess) print('Event: ${state.data}');
  ///   if (state.isError) print('Stream error: ${state.error}');
  /// });
  /// ```
  StreamSignal<T> toStreamSignal() => StreamSignal(this);
}
