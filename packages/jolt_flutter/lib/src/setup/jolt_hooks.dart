import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:jolt_flutter/src/setup/framework.dart';

/// Helper class for creating signal hooks in SetupWidget.
abstract class JoltSignalHookCreator {
  /// {@template jolt_signal_hook_creator}
  /// Creates a reactive signal hook with an initial value.
  ///
  /// The signal persists across rebuilds and is automatically disposed
  /// when the widget is unmounted.
  ///
  /// Parameters:
  /// - [value]: The initial value for the signal
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Signal] that can be read and written to
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///   final name = useSignal('Alice');
  ///
  ///   return () => Text('${name.value}: ${count.value}');
  /// }
  /// ```
  /// {@endtemplate}
  Signal<T> call<T>(
    T value, {
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => Signal(value, onDebug: onDebug));
  }

  /// Creates a lazy signal hook without an initial value.
  ///
  /// Parameters:
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Signal] that can be read and written to
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final data = useSignal.lazy<String>();
  ///
  ///   onMounted(() {
  ///     // Set value later
  ///     data.value = 'loaded data';
  ///   });
  ///
  ///   return () => Text(data.peek ?? 'Loading...');
  /// }
  /// ```
  Signal<T> lazy<T>({
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => Signal.lazy(onDebug: onDebug));
  }

  /// Creates a reactive list signal hook.
  ///
  /// All list operations (add, remove, etc.) will trigger reactive updates.
  ///
  /// Parameters:
  /// - [value]: The initial list value
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [ListSignal] with reactive list operations
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final items = useSignal.list(['Apple', 'Banana']);
  ///
  ///   return () => Column(
  ///     children: [
  ///       ...items.map((item) => Text(item)),
  ///       ElevatedButton(
  ///         onPressed: () => items.add('Cherry'),
  ///         child: Text('Add'),
  ///       ),
  ///     ],
  ///   );
  /// }
  /// ```
  ListSignal<T> list<T>(
    List<T>? value, {
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => ListSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive map signal hook.
  ///
  /// All map operations will trigger reactive updates.
  ///
  /// Parameters:
  /// - [value]: The initial map value
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [MapSignal] with reactive map operations
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final user = useSignal.map({'name': 'Alice', 'age': 30});
  ///
  ///   return () => Text('${user['name']}, age ${user['age']}');
  /// }
  /// ```
  MapSignal<K, V> map<K, V>(
    Map<K, V>? value, {
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => MapSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive set signal hook.
  ///
  /// All set operations will trigger reactive updates.
  ///
  /// Parameters:
  /// - [value]: The initial set value
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [SetSignal] with reactive set operations
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final tags = useSignal.set({'dart', 'flutter'});
  ///
  ///   return () => Text('Tags: ${tags.join(', ')}');
  /// }
  /// ```
  SetSignal<T> set<T>(
    Set<T>? value, {
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => SetSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive iterable signal hook.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the iterable value
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [IterableSignal] with reactive iterable operations
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final numbers = useSignal([1, 2, 3, 4, 5]);
  ///   final evens = useSignal.iterable(() => numbers.value.where((n) => n.isEven));
  ///
  ///   return () => Text('Evens: ${evens.toList()}');
  /// }
  /// ```
  IterableSignal<T> iterable<T>(
    Iterable<T> Function() getter, {
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => IterableSignal<T>(getter, onDebug: onDebug));
  }

  /// Creates an async signal hook for managing asynchronous operations.
  ///
  /// An async signal manages the lifecycle of asynchronous operations, providing
  /// loading, success, and error states. Perfect for API calls, data fetching, etc.
  ///
  /// Parameters:
  /// - [source]: The async source that provides the data
  /// - [initialValue]: Optional initial async state
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [AsyncSignal] that manages async state transitions
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final userData = useSignal.async(
  ///     FutureSource(() async {
  ///       final response = await http.get('/api/user');
  ///       return User.fromJson(response.data);
  ///     }),
  ///   );
  ///
  ///   return () => userData.value.map(
  ///     loading: () => CircularProgressIndicator(),
  ///     success: (user) => Text('Welcome, ${user.name}'),
  ///     error: (error, _) => Text('Error: $error'),
  ///   ) ?? SizedBox();
  /// }
  /// ```
  AsyncSignal<T> async<T>(
    AsyncSource<T> source, {
    AsyncState<T>? initialValue,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => AsyncSignal(
        source: source, initialValue: initialValue, onDebug: onDebug));
  }

  /// Creates a persistent signal hook that saves to external storage.
  ///
  /// The signal automatically reads from storage on creation and writes
  /// on value changes.
  ///
  /// Parameters:
  /// - [initialValue]: Function that provides the initial value if no persisted data exists
  /// - [read]: Function that reads the persisted value from storage
  /// - [write]: Function that writes the value to storage
  /// - [lazy]: Whether to load the value lazily (default is false)
  /// - [writeDelay]: Delay before writing to storage to batch rapid changes
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [PersistSignal] with automatic persistence
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final theme = useSignal.persist(
  ///     () => 'light',
  ///     () => storage.read('theme'),
  ///     (value) => storage.write('theme', value),
  ///   );
  ///
  ///   return () => Text('Theme: ${theme.value}');
  /// }
  /// ```
  PersistSignal<T> persist<T>(T Function() initialValue,
      FutureOr<T> Function() read, FutureOr<void> Function(T value) write,
      {bool lazy = false,
      Duration writeDelay = Duration.zero,
      JoltDebugFn? onDebug}) {
    return useAutoDispose(() => PersistSignal(
        initialValue: initialValue,
        read: read,
        write: write,
        lazy: lazy,
        writeDelay: writeDelay,
        onDebug: onDebug));
  }
}

final class _JoltSignalHookCreatorImpl extends JoltSignalHookCreator {}

/// {@macro jolt_signal_hook_creator}
final useSignal = _JoltSignalHookCreatorImpl();

/// Helper class for creating computed hooks in SetupWidget.
abstract class JoltUseComputed {
  /// {@template jolt_computed_hook_creator}
  /// Creates a computed value hook that derives from reactive dependencies.
  ///
  /// The computed value is cached and only recalculates when its dependencies change.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the derived value
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Computed] that automatically updates when dependencies change
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(5);
  ///   final doubled = useComputed(() => count.value * 2);
  ///   final message = useComputed(() => 'Count is ${count.value}');
  ///
  ///   return () => Text('${message.value}, doubled: ${doubled.value}');
  /// }
  /// ```
  /// {@endtemplate}
  Computed<T> call<T>(T Function() getter, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Computed(getter, onDebug: onDebug));
  }

  /// Creates a writable computed hook that can be both read and written.
  ///
  /// When set, the setter function is called to update the underlying dependencies.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the current value
  /// - [setter]: Function that handles value updates
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [WritableComputed] with custom read/write behavior
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final firstName = useSignal('John');
  ///   final lastName = useSignal('Doe');
  ///   final fullName = useComputed.writable(
  ///     () => '${firstName.value} ${lastName.value}',
  ///     (value) {
  ///       final parts = value.split(' ');
  ///       firstName.value = parts[0];
  ///       lastName.value = parts[1];
  ///     },
  ///   );
  ///
  ///   return () => Text(fullName.value);
  /// }
  /// ```
  Computed<T> writable<T>(T Function() getter, void Function(T) setter,
      {JoltDebugFn? onDebug}) {
    return useAutoDispose(
        () => WritableComputed(getter, setter, onDebug: onDebug));
  }

  /// Creates a type-converting computed hook.
  ///
  /// Automatically converts between different types while maintaining reactivity.
  ///
  /// Parameters:
  /// - [source]: The source signal to convert from
  /// - [decode]: Function that converts from source type to target type
  /// - [encode]: Function that converts from target type back to source type
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [ConvertComputed] with type conversion capabilities
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(42);
  ///   final countText = useComputed.convert(
  ///     count,
  ///     (int value) => value.toString(),
  ///     (String value) => int.parse(value),
  ///   );
  ///
  ///   return () => TextField(
  ///     controller: TextEditingController(text: countText.value),
  ///     onChanged: (text) => countText.value = text,
  ///   );
  /// }
  /// ```
  ConvertComputed<T, U> convert<T, U>(WritableNode<U> source,
      T Function(U value) decode, U Function(T value) encode,
      {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => ConvertComputed<T, U>(source,
        decode: decode, encode: encode, onDebug: onDebug));
  }
}

final class _JoltUseComputedImpl extends JoltUseComputed {}

/// {@macro jolt_computed_hook_creator}
final useComputed = _JoltUseComputedImpl();

/// Helper class for creating effect hooks in SetupWidget.
abstract class JoltEffectHookCreator {
  /// {@template jolt_effect_hook_creator}
  /// Creates an effect hook that runs in response to reactive dependencies.
  ///
  /// Effects run automatically when their reactive dependencies change.
  /// Use [onEffectCleanup] inside the effect to register cleanup functions.
  ///
  /// Parameters:
  /// - [effect]: The effect function to execute
  /// - [lazy]: Whether to run the effect immediately upon creation.
  ///   If `true`, the effect will execute once immediately when created,
  ///   then automatically re-run whenever its reactive dependencies change.
  ///   If `false` (default), the effect will only run when dependencies change,
  ///   not immediately upon creation.
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [Effect] that tracks dependencies and runs automatically
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///
  ///   useEffect(() {
  ///     print('Count changed: ${count.value}');
  ///
  ///     final timer = Timer.periodic(Duration(seconds: 1), (_) {
  ///       count.value++;
  ///     });
  ///
  ///     onEffectCleanup(() => timer.cancel());
  ///   });
  ///
  ///   return () => Text('Count: ${count.value}');
  /// }
  /// ```
  /// {@endtemplate}
  Effect call(void Function() effect,
      {bool lazy = false, JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Effect(effect, lazy: lazy, onDebug: onDebug));
  }

  /// Creates an effect hook that runs immediately upon creation.
  ///
  /// This method is a convenience constructor for creating an effect
  /// with [lazy] set to `true`. The effect will execute once immediately when
  /// created, then automatically re-run whenever its reactive dependencies change.
  ///
  /// Parameters:
  /// - [effect]: The effect function to execute
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [Effect] that executes immediately
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(10);
  ///
  ///   useEffect.lazy(() {
  ///     print('Count is: ${count.value}'); // Executes immediately
  ///   });
  ///
  ///   return () => Text('Count: ${count.value}');
  /// }
  /// ```
  Effect lazy(void Function() effect, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Effect.lazy(effect, onDebug: onDebug));
  }
}

final class _JoltEffectHookCreatorImpl extends JoltEffectHookCreator {}

/// {@macro jolt_effect_hook_creator}
final useEffect = _JoltEffectHookCreatorImpl();

/// Helper class for creating watcher hooks in SetupWidget.
abstract class JoltWatcherHookCreator {
  /// {@template jolt_watcher_hook_creator}
  /// Creates a watcher hook that observes specific reactive sources.
  ///
  /// Watchers provide more control than effects by explicitly defining what to watch
  /// and comparing old vs new values before executing the callback.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [when]: Optional condition function for custom trigger logic
  /// - [immediately]: Whether to execute the callback immediately (default is false)
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Watcher] with fine-grained change detection
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///   final name = useSignal('Alice');
  ///
  ///   useWatcher(
  ///     () => [count.value, name.value],
  ///     (newValues, oldValues) {
  ///       print('Changed from $oldValues to $newValues');
  ///     },
  ///   );
  ///
  ///   return () => Text('${name.value}: ${count.value}');
  /// }
  /// ```
  /// {@endtemplate}
  Watcher call<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool immediately = false,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => Watcher<T>(sourcesFn, fn,
        when: when, immediately: immediately, onDebug: onDebug));
  }

  /// Creates a watcher hook that executes immediately upon creation.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [when]: Optional condition function for custom trigger logic
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Watcher] that executes immediately
  Watcher<T> immediately<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() =>
        Watcher<T>.immediately(sourcesFn, fn, when: when, onDebug: onDebug));
  }

  /// Creates a watcher hook that executes only once.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [when]: Optional condition function for custom trigger logic
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Watcher] that executes only once
  Watcher<T> once<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(
        () => Watcher<T>.once(sourcesFn, fn, when: when, onDebug: onDebug));
  }
}

final class _JoltWatcherHookCreatorImpl extends JoltWatcherHookCreator {}

/// {@macro jolt_watcher_hook_creator}
final useWatcher = _JoltWatcherHookCreatorImpl();

abstract class JoltEffectScopeHookCreator {
  /// {@template jolt_effect_scope_hook_creator}
  /// Creates an effect scope hook for managing groups of effects.
  ///
  /// Effect scopes allow you to group related effects and dispose them together.
  ///
  /// Parameters:
  /// - [detach]: Whether to detach the scope from the current effect context
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [EffectScope] for managing effect lifecycles
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final scope = useEffectScope();
  ///
  ///   onMounted(() {
  ///     scope.run(() {
  ///       final signal = Signal(0);
  ///       Effect(() => print(signal.value));
  ///
  ///       onScopeDispose(() => print('Scope cleaned up'));
  ///     });
  ///   });
  ///
  ///   return () => Text('Hello');
  /// }
  /// ```
  /// {@endtemplate}
  EffectScope call({
    bool? detach,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => EffectScope(detach: detach, onDebug: onDebug));
  }
}

final class _JoltEffectScopeHookCreatorImpl
    extends JoltEffectScopeHookCreator {}

/// {@macro jolt_effect_scope_hook_creator}
final useEffectScope = _JoltEffectScopeHookCreatorImpl();

/// Creates a stream hook from a reactive value.
///
/// Converts a reactive value into a Dart stream, allowing you to use
/// reactive values with stream-based APIs like StreamBuilder.
///
/// Parameters:
/// - [value]: The reactive value to convert to a stream
///
/// Returns: A [Stream] that emits values when the reactive value changes
///
/// Example:
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///   final stream = useStream(count);
///
///   return () => StreamBuilder<int>(
///     stream: stream,
///     builder: (context, snapshot) {
///       return Text('Count: ${snapshot.data ?? 0}');
///     },
///   );
/// }
/// ```
Stream<T> useStream<T>(ReadonlyNode<T> value) {
  return useMemoized(() => value.stream);
}
