import 'dart:async';

import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/extension.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Helper class for creating signal hooks in SetupWidget.
final class JoltSignalHookCreator {
  /// Helper class for creating signal hooks in SetupWidget.
  const JoltSignalHookCreator._();

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
  @defineHook
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
  @defineHook
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
  @defineHook
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
  @defineHook
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
  @defineHook
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
  @defineHook
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
  /// - [source]: A function that returns an async source providing the data
  /// - [initialValue]: Optional function that returns the initial async state
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: An [AsyncSignal] that manages async state transitions
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final userData = useSignal.async(
  ///     () => FutureSource(() async {
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
  @defineHook
  AsyncSignal<T> async<T>(
    AsyncSource<T> Function() source, {
    AsyncState<T> Function()? initialValue,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => AsyncSignal(
        source: source(),
        initialValue: initialValue?.call(),
        onDebug: onDebug));
  }
}

/// {@macro jolt_signal_hook_creator}
@defineHook
const useSignal = JoltSignalHookCreator._();

/// Helper class for creating computed hooks in SetupWidget.
final class JoltUseComputed {
  /// Helper class for creating computed hooks in SetupWidget.
  const JoltUseComputed._();

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
  @defineHook
  Computed<T> call<T>(T Function() getter, {JoltDebugFn? onDebug}) {
    return useAutoDispose(() => Computed(getter, onDebug: onDebug));
  }

  /// Creates a computed value hook with a getter that receives the previous value.
  ///
  /// The getter function receives the previous computed value (or `null` on first
  /// computation) as a parameter, allowing you to implement custom logic based on
  /// the previous state. This is useful for maintaining referential equality,
  /// implementing incremental calculations, or optimizing list/map stability.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [Computed] that can access its previous value during computation
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final signal = useSignal<List<int>>([1, 2, 3]);
  ///   final computed = useComputed.withPrevious<List<int>>((prev) {
  ///     final newList = List<int>.from(signal.value);
  ///     if (prev != null &&
  ///         prev.length == newList.length &&
  ///         prev.every((item) => newList.contains(item))) {
  ///       return prev; // Return previous to maintain stability
  ///     }
  ///     return newList;
  ///   });
  ///
  ///   return () => Text('Items: ${computed.value.join(", ")}');
  /// }
  /// ```
  @defineHook
  Computed<T> withPrevious<T>(T Function(T?) getter, {JoltDebugFn? onDebug}) {
    return useAutoDispose(
        () => Computed.withPrevious(getter, onDebug: onDebug));
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
  @defineHook
  Computed<T> writable<T>(T Function() getter, void Function(T) setter,
      {JoltDebugFn? onDebug}) {
    return useAutoDispose(
        () => WritableComputed(getter, setter, onDebug: onDebug));
  }

  /// Creates a writable computed hook with a getter that receives the previous value.
  ///
  /// The getter function receives the previous computed value (or `null` on first
  /// computation) as a parameter, allowing you to implement custom logic based on
  /// the previous state. When set, the setter function is called to update the
  /// underlying dependencies. This is useful for maintaining referential equality,
  /// implementing incremental calculations, or optimizing list/map stability while
  /// still allowing writes.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [setter]: Function called when the computed value is set
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [WritableComputed] that can access its previous value during computation
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final signal = useSignal([5]);
  ///   final computed = useComputed.writableWithPrevious<int>(
  ///     (prev) {
  ///       final newValue = signal.value[0] * 2;
  ///       if (prev != null && prev == newValue) {
  ///         return prev; // Return previous to maintain stability
  ///       }
  ///       return newValue;
  ///     },
  ///     (value) => signal.value = [value ~/ 2],
  ///   );
  ///
  ///   return () => Text('Value: ${computed.value}');
  /// }
  /// ```
  @defineHook
  WritableComputed<T> writableWithPrevious<T>(
      T Function(T?) getter, void Function(T) setter,
      {JoltDebugFn? onDebug}) {
    return useAutoDispose(
        () => WritableComputed.withPrevious(getter, setter, onDebug: onDebug));
  }
}

/// {@macro jolt_computed_hook_creator}
final useComputed = JoltUseComputed._();

/// Internal hook implementation for effect hooks, similar to [_UseWatcherHook].
/// Provides fine-grained control over effect lifecycle and hot reload behavior.
// ignore: unused_element
class _UseEffectHook extends SetupHook<EffectImpl> {
  _UseEffectHook(this.effect, this.lazy, this.onDebug);

  late void Function() effect;
  late bool lazy;
  late JoltDebugFn? onDebug;

  @override
  EffectImpl build() {
    return EffectImpl(effect, lazy: lazy, onDebug: onDebug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _UseEffectHook newHook) {
    if (onDebug != newHook.onDebug) {
      onDebug = newHook.onDebug;
      if (newHook.onDebug != null) {
        setJoltDebugFn(state, newHook.onDebug!);
      }
    }
    lazy = newHook.lazy;
    effect = newHook.effect;
  }
  // coverage:ignore-end
}

/// Helper class for creating effect hooks in SetupWidget.
final class JoltEffectHookCreator {
  /// Helper class for creating effect hooks in SetupWidget.
  const JoltEffectHookCreator._();

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
  @defineHook
  Effect call(void Function() effect,
      {bool lazy = false, JoltDebugFn? onDebug}) {
    return useHook(_UseEffectHook(effect, lazy, onDebug));
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
  @defineHook
  Effect lazy(void Function() effect, {JoltDebugFn? onDebug}) {
    return useHook(_UseEffectHook(effect, true, onDebug));
  }
}

/// {@macro jolt_effect_hook_creator}
final useEffect = JoltEffectHookCreator._();

class _UseFlutterEffectHook extends SetupHook<FlutterEffectImpl> {
  _UseFlutterEffectHook(this.effect, this.lazy, this.onDebug);

  late void Function() effect;
  late bool lazy;
  late JoltDebugFn? onDebug;

  @override
  FlutterEffectImpl build() {
    return FlutterEffectImpl(effect, lazy: lazy, onDebug: onDebug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _UseEffectHook newHook) {
    if (onDebug != newHook.onDebug) {
      onDebug = newHook.onDebug;
      if (newHook.onDebug != null) {
        setJoltDebugFn(state, newHook.onDebug!);
      }
    }
    lazy = newHook.lazy;
    effect = newHook.effect;
  }
  // coverage:ignore-end
}

/// Helper class for creating Flutter effect hooks in SetupWidget.
final class JoltFlutterEffectHookCreator {
  /// Helper class for creating Flutter effect hooks in SetupWidget.
  const JoltFlutterEffectHookCreator._();

  /// {@template jolt_flutter_effect_hook_creator}
  /// Creates a Flutter effect hook that schedules execution at frame end.
  ///
  /// Flutter effects run automatically when their reactive dependencies change,
  /// but execution is scheduled at the end of the current Flutter frame. This
  /// batches multiple triggers within the same frame into a single execution,
  /// which is useful for UI-related side effects that should not interfere
  /// with frame rendering. Use [onEffectCleanup] inside the effect to register
  /// cleanup functions.
  ///
  /// Parameters:
  /// - [effect]: The effect function to execute
  /// - [lazy]: Whether to run the effect immediately upon creation.
  ///   If `true`, the effect will execute once immediately when created,
  ///   then automatically re-run at frame end whenever its reactive dependencies change.
  ///   If `false` (default), the effect will only run at frame end when dependencies change,
  ///   not immediately upon creation.
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [FlutterEffect] that tracks dependencies and runs at frame end
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///
  ///   useFlutterEffect(() {
  ///     print('Count changed: ${count.value}'); // Executes at frame end
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
  @defineHook
  FlutterEffect call(void Function() effect,
      {bool lazy = false, JoltDebugFn? onDebug}) {
    return useHook(_UseFlutterEffectHook(effect, lazy, onDebug));
  }

  /// Creates a Flutter effect hook that runs immediately upon creation.
  ///
  /// This method is a convenience constructor for creating a Flutter effect
  /// with [lazy] set to `true`. The effect will execute once immediately when
  /// created, then automatically re-run at frame end whenever its reactive dependencies change.
  ///
  /// Parameters:
  /// - [effect]: The effect function to execute
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A [FlutterEffect] that executes immediately
  ///
  /// Example:
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(10);
  ///
  ///   useFlutterEffect.lazy(() {
  ///     print('Count is: ${count.value}'); // Executes immediately
  ///   });
  ///
  ///   return () => Text('Count: ${count.value}');
  /// }
  /// ```
  @defineHook
  FlutterEffect lazy(void Function() effect, {JoltDebugFn? onDebug}) {
    return useHook(_UseFlutterEffectHook(effect, true, onDebug));
  }
}

/// {@macro jolt_flutter_effect_hook_creator}
final useFlutterEffect = JoltFlutterEffectHookCreator._();

class _UseWatcherHook<T> extends SetupHook<WatcherImpl<T>> {
  _UseWatcherHook(this.sourcesFn, this.fn,
      {this.when, this.immediately = false, this.onDebug});

  late SourcesFn<T> sourcesFn;
  late WatcherFn<T> fn;
  late WhenFn<T>? when;
  late bool immediately;
  late JoltDebugFn? onDebug;

  @override
  WatcherImpl<T> build() {
    return WatcherImpl(sourcesFn, fn,
        when: when, immediately: immediately, onDebug: onDebug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _UseWatcherHook<T> newHook) {
    if (newHook.immediately != immediately) {
      state.dispose();
      immediately = newHook.immediately;
      sourcesFn = newHook.sourcesFn;
      fn = newHook.fn;
      when = newHook.when;
      rawState = build();
      return;
    }

    if (onDebug != newHook.onDebug) {
      if (newHook.onDebug != null) {
        setJoltDebugFn(state, newHook.onDebug!);
      }
    }

    if (sourcesFn == newHook.sourcesFn &&
        fn == newHook.fn &&
        when == newHook.when) {
      return;
    }

    state.sourcesFn = newHook.sourcesFn;
    state.fn = newHook.fn;
    state.when = newHook.when;
  }
  // coverage:ignore-end
}

/// Helper class for creating watcher hooks in SetupWidget.
final class JoltWatcherHookCreator {
  /// Helper class for creating watcher hooks in SetupWidget.
  const JoltWatcherHookCreator._();

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
  @defineHook
  Watcher call<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool immediately = false,
    JoltDebugFn? onDebug,
  }) {
    return useHook(_UseWatcherHook<T>(sourcesFn, fn,
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
  @defineHook
  Watcher<T> immediately<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugFn? onDebug,
  }) {
    return useHook(_UseWatcherHook<T>(sourcesFn, fn,
        when: when, immediately: true, onDebug: onDebug));
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
  @defineHook
  Watcher<T> once<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugFn? onDebug,
  }) {
    late _UseWatcherHook<T> hook;
    hook = _UseWatcherHook<T>(sourcesFn, (newValue, oldValue) {
      fn(newValue, oldValue);
      hook.state.dispose();
    }, when: when, immediately: false, onDebug: onDebug);
    return useHook(hook);
  }
}

/// {@macro jolt_watcher_hook_creator}
final useWatcher = JoltWatcherHookCreator._();

/// Helper class for creating effect scope hooks in SetupWidget.
final class JoltEffectScopeHookCreator {
  /// Helper class for creating effect scope hooks in SetupWidget.
  const JoltEffectScopeHookCreator._();

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
  @defineHook
  EffectScope call({
    bool? detach,
    JoltDebugFn? onDebug,
  }) {
    return useAutoDispose(() => EffectScope(detach: detach, onDebug: onDebug));
  }
}

/// {@macro jolt_effect_scope_hook_creator}
final useEffectScope = JoltEffectScopeHookCreator._();

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
///   final stream = useJoltStream(count);
///
///   return () => StreamBuilder<int>(
///     stream: stream,
///     builder: (context, snapshot) {
///       return Text('Count: ${snapshot.data ?? 0}');
///     },
///   );
/// }
/// ```
@defineHook
Stream<T> useJoltStream<T>(Readable<T> value) {
  return useMemoized(() => value.stream);
}
