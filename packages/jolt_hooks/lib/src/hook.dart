import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';

import 'base.dart';

/// Creates a reactive signal hook that holds a mutable value.
///
/// A signal is the most basic reactive primitive that holds a value and
/// notifies subscribers when the value changes. This hook integrates signals
/// with Flutter's hook system for automatic disposal.
///
/// Parameters:
/// - [value]: The initial value for the signal
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [Signal] that can be read and written to
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   return Column(
///     children: [
///       Text('Count: ${count.value}'),
///       ElevatedButton(
///         onPressed: () => count.value++,
///         child: Text('Increment'),
///       ),
///     ],
///   );
/// }
/// ```
Signal<T> useSignal<T>(T value, {List<Object?>? keys, JoltDebugFn? onDebug}) {
  return use(JoltHook(Signal(value, onDebug: onDebug), keys: keys));
}

/// Creates a computed signal hook that derives its value from other signals.
///
/// A computed signal automatically recalculates its value when any of its
/// dependencies change. It's read-only and provides efficient caching.
///
/// Parameters:
/// - [value]: Function that computes the derived value
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [Computed] that automatically updates when dependencies change
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final firstName = useSignal('John');
///   final lastName = useSignal('Doe');
///   final fullName = useComputed(() => '${firstName.value} ${lastName.value}');
///
///   return Text('Hello, ${fullName.value}');
/// }
/// ```
Computed<T> useComputed<T>(
  T Function() value, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltHook(Computed(value, onDebug: onDebug), keys: keys));
}

/// Creates a writable computed signal hook with custom getter and setter.
///
/// A writable computed signal allows you to define custom read and write
/// behavior, enabling two-way data binding with derived values.
///
/// Parameters:
/// - [getter]: Function that computes the current value
/// - [setter]: Function that handles value updates
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [WritableComputed] with custom read/write behavior
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///   final doubled = useWritableComputed(
///     () => count.value * 2,
///     (value) => count.value = value ~/ 2,
///   );
///
///   return Column(
///     children: [
///       Text('Count: ${count.value}'),
///       Text('Doubled: ${doubled.value}'),
///       ElevatedButton(
///         onPressed: () => doubled.value = 10,
///         child: Text('Set doubled to 10'),
///       ),
///     ],
///   );
/// }
/// ```
WritableComputed<T> useWritableComputed<T>(
  T Function() getter,
  void Function(T) setter, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(
    JoltHook(WritableComputed(getter, setter, onDebug: onDebug), keys: keys),
  );
}

/// Creates a computed signal hook that converts between different types.
///
/// A convert computed signal provides two-way conversion between different
/// data types, useful for form inputs, API data transformation, etc.
///
/// Parameters:
/// - [source]: The source signal to convert from
/// - [decode]: Function that converts from source type to target type
/// - [encode]: Function that converts from target type back to source type
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [ConvertComputed] with type conversion capabilities
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(42);
///   final countText = useConvertComputed(
///     count,
///     (int value) => 'Count: $value',
///     (String value) => int.parse(value.split(': ')[1]),
///   );
///
///   return Column(
///     children: [
///       Text(countText.value),
///       TextField(
///         onChanged: (value) => countText.value = value,
///       ),
///     ],
///   );
/// }
/// ```
ConvertComputed<T, U> useConvertComputed<T, U>(
  Signal<U> source,
  T Function(U value) decode,
  U Function(T value) encode, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(
    JoltHook(
      ConvertComputed(source, decode: decode, encode: encode, onDebug: onDebug),
      keys: keys,
    ),
  );
}

/// Creates a persistent signal hook that automatically saves and loads data.
///
/// A persist signal automatically persists its value to storage and restores
/// it when the hook is recreated, useful for user preferences, form data, etc.
///
/// Parameters:
/// - [initialValue]: Function that provides the initial value if no persisted data exists
/// - [read]: Function that reads the persisted value from storage
/// - [write]: Function that writes the value to storage
/// - [writeDelay]: Delay before writing to storage to batch rapid changes
/// - [lazy]: Whether to load the value lazily (default is false)
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [PersistSignal] with automatic persistence
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final theme = usePersistSignal(
///     () => 'light',
///     () async => await storage.read('theme') ?? 'light',
///     (value) async => await storage.write('theme', value),
///   );
///
///   return MaterialApp(
///     theme: theme.value == 'dark' ? ThemeData.dark() : ThemeData.light(),
///     home: Scaffold(
///       body: Switch(
///         value: theme.value == 'dark',
///         onChanged: (value) => theme.value = value ? 'dark' : 'light',
///       ),
///     ),
///   );
/// }
/// ```
PersistSignal<T> usePersistSignal<T>(
  T Function() initialValue,
  FutureOr<T> Function() read,
  FutureOr<void> Function(T value) write, {
  Duration writeDelay = Duration.zero,
  List<Object?>? keys,
  bool lazy = false,
  JoltDebugFn? onDebug,
}) {
  return use(
    JoltHook(
      PersistSignal(
        initialValue: initialValue,
        read: read,
        write: write,
        writeDelay: writeDelay,
        onDebug: onDebug,
        lazy: lazy,
      ),
      keys: keys,
    ),
  );
}

/// Creates an async signal hook for managing asynchronous operations.
///
/// An async signal manages the lifecycle of asynchronous operations, providing
/// loading, success, and error states. Perfect for API calls, data fetching, etc.
///
/// Parameters:
/// - [source]: The async source that provides the data
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
/// - [initialValue]: Optional initial async state
///
/// Returns: An [AsyncSignal] that manages async state transitions
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final userData = useAsyncSignal(
///     FutureSource(() async {
///       final response = await http.get('/api/user');
///       return User.fromJson(response.data);
///     }),
///   );
///
///   return userData.value.map(
///     loading: () => CircularProgressIndicator(),
///     success: (user) => Text('Welcome, ${user.name}'),
///     error: (error, _) => Text('Error: $error'),
///   ) ?? SizedBox();
/// }
/// ```
AsyncSignal<T> useAsyncSignal<T>(
  AsyncSource<T> source, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
  AsyncState<T>? initialValue,
}) {
  return use(
    JoltHook(
      AsyncSignal(source, initialValue: initialValue, onDebug: onDebug),
      keys: keys,
    ),
  );
}

/// Creates a reactive effect hook that runs when dependencies change.
///
/// An effect is a side-effect function that automatically runs when any of
/// its reactive dependencies change. Useful for logging, analytics, etc.
///
/// Parameters:
/// - [fn]: The effect function to execute
/// - [immediately]: Whether to run the effect immediately upon creation
/// - [onDebug]: Optional debug callback for reactive system debugging
/// - [keys]: Optional keys for hook memoization
///
/// Returns: An [Effect] that tracks dependencies and runs automatically
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   useJoltEffect(() {
///     print('Count changed to: ${count.value}');
///   });
///
///   return ElevatedButton(
///     onPressed: () => count.value++,
///     child: Text('Count: ${count.value}'),
///   );
/// }
/// ```
Effect useJoltEffect(
  void Function() fn, {
  bool immediately = true,
  JoltDebugFn? onDebug,
  List<Object?>? keys,
}) {
  return use(
    JoltEffectHook(
      Effect(fn, immediately: immediately, onDebug: onDebug),
      keys: keys,
    ),
  );
}

/// Creates a watcher hook that observes changes with fine-grained control.
///
/// A watcher provides more control than effects, allowing you to compare
/// old and new values and define custom trigger conditions.
///
/// Parameters:
/// - [sources]: Function that returns the values to watch
/// - [fn]: Callback function executed when sources change
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
/// - [immediately]: Whether to execute the callback immediately
/// - [when]: Optional condition function for custom trigger logic
///
/// Returns: A [Watcher] with fine-grained change detection
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   useJoltWatcher(
///     () => count.value,
///     (newValue, oldValue) {
///       print('Count changed from $oldValue to $newValue');
///     },
///     when: (new, old) => new > old, // Only when increasing
///   );
///
///   return ElevatedButton(
///     onPressed: () => count.value++,
///     child: Text('Count: ${count.value}'),
///   );
/// }
/// ```
Watcher useJoltWatcher<T>(
  T Function() sources,
  WatcherFn<T> fn, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
  bool immediately = false,
  WhenFn<T>? when,
}) {
  return use(
    JoltEffectHook(
      Watcher<T>(
        sources,
        fn,
        immediately: immediately,
        when: when,
        onDebug: onDebug,
      ),
      keys: keys,
    ),
  );
}

/// Creates an effect scope hook for managing effect lifecycles.
///
/// An effect scope allows you to group related effects together and dispose
/// them all at once. Useful for component-based architectures.
///
/// Parameters:
/// - [fn]: Optional function to execute within the scope context
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: An [EffectScope] for managing effect lifecycles
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   useJoltEffectScope((scope) {
///     final count = useSignal(0);
///     final name = useSignal('User');
///
///     // Both signals will be disposed when scope is disposed
///   });
///
///   return Text('Component with scoped effects');
/// }
/// ```
EffectScope useJoltEffectScope(
  void Function(EffectScope scope)? fn, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltEffectHook(EffectScope(fn, onDebug: onDebug), keys: keys));
}

/// Creates a stream hook from a reactive value.
///
/// Converts a reactive value into a Dart stream, allowing you to use
/// reactive values with stream-based APIs like StreamBuilder.
///
/// Parameters:
/// - [value]: The reactive value to convert to a stream
/// - [keys]: Optional keys for hook memoization
///
/// Returns: A [Stream] that emits values when the reactive value changes
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///   final stream = useJoltStream(count);
///
///   return StreamBuilder<int>(
///     stream: stream,
///     builder: (context, snapshot) {
///       return Text('Count: ${snapshot.data ?? 0}');
///     },
///   );
/// }
/// ```
Stream<T> useJoltStream<T>(JReadonlyValue<T> value, {List<Object?>? keys}) {
  final stream = useMemoized(() => value.stream, keys ?? []);

  return stream;
}

/// Creates a reactive list signal hook.
///
/// A list signal provides reactive list operations with automatic change
/// notifications. Perfect for dynamic lists, todo items, etc.
///
/// Parameters:
/// - [value]: The initial list value
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [ListSignal] with reactive list operations
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final items = useListSignal(['Apple', 'Banana']);
///
///   return Column(
///     children: [
///       ...items.value.map((item) => ListTile(title: Text(item))),
///       ElevatedButton(
///         onPressed: () => items.add('Orange'),
///         child: Text('Add Orange'),
///       ),
///     ],
///   );
/// }
/// ```
ListSignal<T> useListSignal<T>(
  List<T>? value, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltHook(ListSignal(value, onDebug: onDebug), keys: keys));
}

/// Creates a reactive map signal hook.
///
/// A map signal provides reactive map operations with automatic change
/// notifications. Perfect for key-value data, settings, etc.
///
/// Parameters:
/// - [value]: The initial map value
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [MapSignal] with reactive map operations
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final settings = useMapSignal({'theme': 'light', 'lang': 'en'});
///
///   return Column(
///     children: [
///       Text('Theme: ${settings['theme']}'),
///       Text('Language: ${settings['lang']}'),
///       ElevatedButton(
///         onPressed: () => settings['theme'] = 'dark',
///         child: Text('Toggle Theme'),
///       ),
///     ],
///   );
/// }
/// ```
MapSignal<K, V> useMapSignal<K, V>(
  Map<K, V>? value, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltHook(MapSignal(value, onDebug: onDebug), keys: keys));
}

/// Creates a reactive set signal hook.
///
/// A set signal provides reactive set operations with automatic change
/// notifications. Perfect for unique collections, tags, etc.
///
/// Parameters:
/// - [value]: The initial set value
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: A [SetSignal] with reactive set operations
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final tags = useSetSignal({'urgent', 'important'});
///
///   return Column(
///     children: [
///       ...tags.value.map((tag) => Chip(label: Text(tag))),
///       ElevatedButton(
///         onPressed: () => tags.add('new'),
///         child: Text('Add Tag'),
///       ),
///     ],
///   );
/// }
/// ```
SetSignal<T> useSetSignal<T>(
  Set<T>? value, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltHook(SetSignal(value, onDebug: onDebug), keys: keys));
}

/// Creates a reactive iterable signal hook.
///
/// An iterable signal provides reactive iterable operations with automatic
/// change notifications. Perfect for filtered lists, computed collections, etc.
///
/// Parameters:
/// - [getter]: Function that computes the iterable value
/// - [keys]: Optional keys for hook memoization
/// - [onDebug]: Optional debug callback for reactive system debugging
///
/// Returns: An [IterableSignal] with reactive iterable operations
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   final numbers = useSignal([1, 2, 3, 4, 5]);
///   final evenNumbers = useIterableSignal(
///     () => numbers.value.where((n) => n.isEven),
///   );
///
///   return Column(
///     children: [
///       Text('All: ${numbers.value.join(', ')}'),
///       Text('Even: ${evenNumbers.value.join(', ')}'),
///       ElevatedButton(
///         onPressed: () => numbers.add(6),
///         child: Text('Add 6'),
///       ),
///     ],
///   );
/// }
/// ```
IterableSignal<T> useIterableSignal<T>(
  Iterable<T> Function() getter, {
  List<Object?>? keys,
  JoltDebugFn? onDebug,
}) {
  return use(JoltHook(IterableSignal(getter, onDebug: onDebug), keys: keys));
}
