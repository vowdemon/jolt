import 'package:flutter/foundation.dart';
import 'package:free_disposer/free_disposer.dart';

import 'computed.dart';
import 'signal.dart';
import 'collection.dart';
import 'async.dart';

/// Extension methods for converting any object to a Signal.
extension JoltFlutterObjectExtension<T extends Object?> on T {
  /// Converts this object to a Signal with the object as the initial value.
  ///
  /// This extension method provides a convenient way to create a Signal from
  /// any object, making it reactive and observable.
  ///
  /// ## Returns
  ///
  /// A [Signal] containing this object as the initial value
  ///
  /// ## Example
  ///
  /// ```dart
  /// final name = 'John'.toSignal();
  /// final count = 42.toSignal();
  /// final user = User(name: 'Alice').toSignal();
  ///
  /// // All become reactive signals
  /// JoltBuilder(
  ///   builder: (context) => Text('Hello ${name.value}'),
  /// )
  /// ```
  Signal<T> toSignal() => Signal(this);
}

/// Extension methods for converting List to ListSignal.
extension JoltFlutterListExtension<E> on List<E> {
  /// Converts this List to a reactive ListSignal.
  ///
  /// This extension method provides a convenient way to make a List reactive,
  /// automatically tracking mutations and notifying listeners of changes.
  ///
  /// ## Returns
  ///
  /// A [ListSignal] wrapping this List
  ///
  /// ## Example
  ///
  /// ```dart
  /// final todos = ['Buy milk', 'Walk dog'].toListSignal();
  ///
  /// // Now reactive - widgets will rebuild when list changes
  /// todos.add('Finish project');
  /// todos.removeAt(0);
  ///
  /// JoltBuilder(
  ///   builder: (context) => ListView(
  ///     children: todos.value.map((todo) => Text(todo)).toList(),
  ///   ),
  /// )
  /// ```
  ListSignal<E> toListSignal() => ListSignal(this);
}

/// Extension methods for converting Map to MapSignal.
extension JoltFlutterMapExtension<K, V> on Map<K, V> {
  /// Converts this Map to a reactive MapSignal.
  ///
  /// This extension method provides a convenient way to make a Map reactive,
  /// automatically tracking mutations and notifying listeners of changes.
  ///
  /// ## Returns
  ///
  /// A [MapSignal] wrapping this Map
  ///
  /// ## Example
  ///
  /// ```dart
  /// final settings = {
  ///   'theme': 'dark',
  ///   'notifications': true,
  /// }.toMapSignal();
  ///
  /// // Now reactive - widgets will rebuild when map changes
  /// settings['theme'] = 'light';
  /// settings.remove('notifications');
  ///
  /// JoltBuilder(
  ///   builder: (context) => Text('Theme: ${settings.value['theme']}'),
  /// )
  /// ```
  MapSignal<K, V> toMapSignal() => MapSignal(this);
}

/// Extension methods for converting Set to SetSignal.
extension JoltFlutterSetExtension<E> on Set<E> {
  /// Converts this Set to a reactive SetSignal.
  ///
  /// This extension method provides a convenient way to make a Set reactive,
  /// automatically tracking mutations and notifying listeners of changes.
  ///
  /// ## Returns
  ///
  /// A [SetSignal] wrapping this Set
  ///
  /// ## Example
  ///
  /// ```dart
  /// final tags = {'flutter', 'dart', 'mobile'}.toSetSignal();
  ///
  /// // Now reactive - widgets will rebuild when set changes
  /// tags.add('web');
  /// tags.remove('mobile');
  ///
  /// JoltBuilder(
  ///   builder: (context) => Text('Tags: ${tags.value.join(', ')}'),
  /// )
  /// ```
  SetSignal<E> toSetSignal() => SetSignal(this);
}

/// Extension methods for converting Iterable to IterableSignal.
extension JoltFlutterIterableExtension<E> on Iterable<E> {
  /// Converts this Iterable to a reactive IterableSignal.
  ///
  /// This extension method provides a convenient way to make an Iterable reactive,
  /// creating a computed signal that provides access to the Iterable's values.
  ///
  /// ## Returns
  ///
  /// An [IterableSignal] that provides this Iterable
  ///
  /// ## Example
  ///
  /// ```dart
  /// final numbers = [1, 2, 3, 4, 5];
  /// final evenNumbers = numbers.where((n) => n.isEven).toIterableSignal();
  ///
  /// JoltBuilder(
  ///   builder: (context) => Text('Even: ${evenNumbers.value.join(', ')}'),
  /// )
  /// ```
  IterableSignal<E> toIterableSignal() => IterableSignal(() => this);
}

/// Extension methods for converting Future to async signals.
extension JoltFlutterFutureExtension<T> on Future<T> {
  /// Converts this Future to a reactive AsyncSignal.
  ///
  /// This extension method provides a convenient way to make a Future reactive,
  /// automatically tracking its loading, success, and error states.
  ///
  /// ## Returns
  ///
  /// A [FutureSignal] that tracks this Future's state
  ///
  /// ## Example
  ///
  /// ```dart
  /// final userData = fetchUserFromApi().toAsyncSignal();
  ///
  /// JoltBuilder(
  ///   builder: (context) => userData.value.when(
  ///     loading: () => CircularProgressIndicator(),
  ///     data: (user) => UserProfile(user),
  ///     error: (error) => Text('Error: $error'),
  ///   ),
  /// )
  /// ```
  FutureSignal<T> toAsyncSignal() => FutureSignal(this);
}

/// Extension methods for converting Stream to async signals.
extension JoltFlutterStreamExtension<T> on Stream<T> {
  /// Converts this Stream to a reactive StreamSignal.
  ///
  /// This extension method provides a convenient way to make a Stream reactive,
  /// automatically tracking its values and states over time.
  ///
  /// ## Returns
  ///
  /// A [StreamSignal] that tracks this Stream's values
  ///
  /// ## Example
  ///
  /// ```dart
  /// final messages = FirebaseFirestore.instance
  ///   .collection('chat')
  ///   .snapshots()
  ///   .map((snapshot) => snapshot.docs.map(Message.fromDoc))
  ///   .toStreamSignal();
  ///
  /// JoltBuilder(
  ///   builder: (context) => messages.value.when(
  ///     loading: () => Text('Loading...'),
  ///     data: (msgs) => MessageList(msgs),
  ///     error: (error) => Text('Error: $error'),
  ///   ),
  /// )
  /// ```
  StreamSignal<T> toStreamSignal() => StreamSignal(this);
}

/// Extension methods for integrating Flutter ValueNotifier with Jolt signals.
extension JoltFlutterValueNotifierExtension<T> on ValueNotifier<T> {
  /// Converts this ValueNotifier to a reactive Signal with bidirectional sync.
  ///
  /// This extension method creates a bridge between Flutter's ValueNotifier and
  /// Jolt signals, allowing seamless interoperability. Changes to either the
  /// original ValueNotifier or the returned Signal will be synchronized.
  ///
  /// ## Returns
  ///
  /// A [Signal] that stays synchronized with this ValueNotifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// final textController = TextEditingController();
  /// final textSignal = textController.toSignal();
  ///
  /// // Changes to textController update textSignal
  /// textController.text = 'Hello';
  /// print(textSignal.value); // 'Hello'
  ///
  /// // Changes to textSignal update textController
  /// textSignal.value = 'World';
  /// print(textController.text); // 'World'
  ///
  /// JoltBuilder(
  ///   builder: (context) => TextField(
  ///     controller: textController,
  ///     // Signal automatically updates when text changes
  ///   ),
  /// )
  /// ```
  Signal<T> toSignal() {
    final signal = WritableComputed(() => value, (value) => this.value = value);
    void listener() {
      if (value != signal.peek) {
        signal.set(value);
      }
    }

    addListener(listener);
    signal.disposeWith(() {
      removeListener(listener);
    });
    return signal;
  }
}
