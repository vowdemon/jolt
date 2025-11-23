import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:jolt_flutter/src/setup/widget.dart';

/// Helper class for creating signal hooks in SetupWidget.
final class JoltUseSignal {
  /// Creates a reactive signal hook with an initial value.
  ///
  /// The signal persists across rebuilds and is automatically disposed
  /// when the widget is unmounted.
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
  Signal<T> call<T>(T value, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Signal(value, onDebug: onDebug));
  }

  /// Creates a lazy signal hook without an initial value.
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
  Signal<T> lazy<T>({JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Signal.lazy(onDebug: onDebug));
  }

  /// Creates a reactive list signal hook.
  ///
  /// All list operations (add, remove, etc.) will trigger reactive updates.
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
  ListSignal<T> list<T>(List<T>? value, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => ListSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive map signal hook.
  ///
  /// All map operations will trigger reactive updates.
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final user = useSignal.map({'name': 'Alice', 'age': 30});
  ///
  ///   return () => Text('${user['name']}, age ${user['age']}');
  /// }
  /// ```
  MapSignal<K, V> map<K, V>(Map<K, V>? value, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => MapSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive set signal hook.
  ///
  /// All set operations will trigger reactive updates.
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final tags = useSignal.set({'dart', 'flutter'});
  ///
  ///   return () => Text('Tags: ${tags.join(', ')}');
  /// }
  /// ```
  SetSignal<T> set<T>(Set<T>? value, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => SetSignal(value, onDebug: onDebug));
  }

  /// Creates a reactive iterable signal hook.
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
  IterableSignal<T> iterable<T>(Iterable<T> Function() getter,
      {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => IterableSignal<T>(getter, onDebug: onDebug));
  }

  /// Creates a persistent signal hook that saves to external storage.
  ///
  /// The signal automatically reads from storage on creation and writes
  /// on value changes.
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

/// Creates a reactive signal hook.
///
/// Provides methods for creating different types of signals:
/// - `useSignal(value)` - Basic signal
/// - `useSignal.lazy()` - Lazy signal
/// - `useSignal.list()` - List signal
/// - `useSignal.map()` - Map signal
/// - `useSignal.set()` - Set signal
/// - `useSignal.iterable()` - Iterable signal
/// - `useSignal.persist()` - Persistent signal
final useSignal = JoltUseSignal();

/// Helper class for creating computed hooks in SetupWidget.
final class JoltUseComputed {
  /// Creates a computed value hook that derives from reactive dependencies.
  ///
  /// The computed value is cached and only recalculates when its dependencies change.
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
  Computed<T> call<T>(T Function() getter, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Computed(getter, onDebug: onDebug));
  }

  /// Creates a writable computed hook that can be both read and written.
  ///
  /// When set, the setter function is called to update the underlying dependencies.
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

/// Creates a computed value hook.
///
/// Provides methods for creating different types of computed values:
/// - `useComputed(getter)` - Basic computed
/// - `useComputed.writable(getter, setter)` - Writable computed
/// - `useComputed.convert(source, decode, encode)` - Type-converting computed
final useComputed = JoltUseComputed();

/// Helper class for creating effect hooks in SetupWidget.
final class JoltUseEffect {
  /// Creates an effect hook that runs in response to reactive dependencies.
  ///
  /// Effects run automatically when their reactive dependencies change.
  /// Use [onEffectCleanup] inside the effect to register cleanup functions.
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
  Effect call(void Function() effect,
      {bool immediately = true, JoltDebugFn? onDebug}) {
    return useAutoDispose(
        () => Effect(effect, immediately: immediately, onDebug: onDebug));
  }
}

/// Creates an effect hook that runs when reactive dependencies change.
///
/// The effect runs immediately by default and whenever tracked dependencies update.
final useEffect = JoltUseEffect();

/// Helper class for creating watcher hooks in SetupWidget.
final class JoltUseWatcher {
  /// Creates a watcher hook that observes specific reactive sources.
  ///
  /// Watchers provide more control than effects by explicitly defining what to watch
  /// and comparing old vs new values before executing the callback.
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
  Watcher call<T>(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, bool immediately = false, JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Watcher<T>(sourcesFn, fn,
        when: when, immediately: immediately, onDebug: onDebug));
  }
}

/// Creates a watcher hook that observes changes to reactive sources.
///
/// Provides explicit control over which values to watch and when to trigger.
final useWatcher = JoltUseWatcher();

/// Helper class for creating effect scope hooks in SetupWidget.
final class JoltUseEffectScope {
  /// Creates an effect scope hook for managing groups of effects.
  ///
  /// Effect scopes allow you to group related effects and dispose them together.
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
  EffectScope call({bool? detach, JoltDebugFn? onDebug}) {
    return useAutoDispose(() => EffectScope(detach: detach, onDebug: onDebug));
  }
}

/// Creates an effect scope hook for managing groups of reactive effects.
///
/// Useful for organizing and cleaning up multiple related effects at once.
final useEffectScope = JoltUseEffectScope();
