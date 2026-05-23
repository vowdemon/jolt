import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'base.dart';

/// Signal hook factory methods.
final class JoltSignalHookCreator {
  const JoltSignalHookCreator._();

  /// Creates a writable [Signal] with [value] as its initial value.
  Signal<T> call<T>(
    T value, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => Signal(value, debug: debug), keys: keys));
  }

  /// Creates a [Signal] without an initial value.
  Signal<T> lazy<T>({
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => Signal.lazy(debug: debug), keys: keys));
  }

  /// Creates a reactive [ListSignal] initialized with [value].
  ListSignal<T> list<T>(
    List<T>? value, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => ListSignal(value, debug: debug), keys: keys));
  }

  /// Creates a reactive [MapSignal] initialized with [value].
  MapSignal<K, V> map<K, V>(
    Map<K, V>? value, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => MapSignal(value, debug: debug), keys: keys));
  }

  /// Creates a reactive [SetSignal] initialized with [value].
  SetSignal<T> set<T>(
    Set<T>? value, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => SetSignal(value, debug: debug), keys: keys));
  }

  /// Creates an [IterableSignal] derived from [getter].
  IterableSignal<T> iterable<T>(
    Iterable<T> Function() getter, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(
        JoltHook(() => IterableSignal(getter, debug: debug), keys: keys));
  }

  /// Creates an [AsyncSignal] from [source].
  AsyncSignal<T> async<T>(
    AsyncSource<T> Function() source, {
    List<Object?>? keys,
    JoltDebugOption? debug,
    AsyncState<T> Function()? initialValue,
  }) {
    return use(
      JoltHook(
        () => AsyncSignal(
          source: source(),
          initialValue: initialValue?.call(),
          debug: debug,
        ),
        keys: keys,
      ),
    );
  }
}

/// Creates a writable [Signal] for the current hook scope.
///
/// The signal is disposed automatically when the widget unmounts. Use
/// [JoltSignalHookCreator.lazy], [JoltSignalHookCreator.list],
/// [JoltSignalHookCreator.map], [JoltSignalHookCreator.set],
/// [JoltSignalHookCreator.iterable], or [JoltSignalHookCreator.async] when the
/// stored value needs specialized collection or async behavior. Pass [keys] to
/// recreate the hook when dependencies change.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   return FilledButton(
///     onPressed: () => count.value++,
///     child: Text('Count: ${count.value}'),
///   );
/// }
/// ```
const useSignal = JoltSignalHookCreator._();

/// Computed hook factory methods.
final class JoltComputedHookCreator {
  const JoltComputedHookCreator._();

  /// Creates a [Computed] value from [value].
  Computed<T> call<T>(
    T Function() value, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltHook(() => Computed(value, debug: debug), keys: keys));
  }

  /// Creates a [Computed] whose [getter] receives the previous value.
  Computed<T> withPrevious<T>(
    T Function(T?) getter, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(
      JoltHook(() => Computed.withPrevious(getter, debug: debug), keys: keys),
    );
  }

  /// Creates a [WritableComputed] from [getter] and [setter].
  WritableComputed<T> writable<T>(
    T Function() getter,
    void Function(T) setter, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(
      JoltHook(() => WritableComputed(getter, setter, debug: debug),
          keys: keys),
    );
  }

  /// Creates a writable [Computed] whose [getter] receives the previous value.
  WritableComputed<T> writableWithPrevious<T>(
    T Function(T?) getter,
    void Function(T) setter, {
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(
      JoltHook(
        () => WritableComputed.withPrevious(getter, setter, debug: debug),
        keys: keys,
      ),
    );
  }
}

/// Creates a [Computed] value for the current hook scope.
///
/// Reactive reads inside the getter become dependencies. The result is cached
/// and recomputed only after one of those dependencies changes. Use
/// [JoltComputedHookCreator.withPrevious] or [JoltComputedHookCreator.writable]
/// when the derived value needs previous-value access or a writable interface.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///   final doubled = useComputed(() => count.value * 2);
///
///   return Text('Double: ${doubled.value}');
/// }
/// ```
const useComputed = JoltComputedHookCreator._();

/// Effect hook factory methods.
final class JoltEffectHookCreator {
  const JoltEffectHookCreator._();

  /// Creates an [Effect] that runs [fn] reactively.
  Effect call(
    void Function() fn, {
    bool lazy = false,
    JoltDebugOption? debug,
    List<Object?>? keys,
  }) {
    return use(
      JoltEffectHook(
        () => Effect(fn, lazy: lazy, debug: debug),
        keys: keys,
      ),
    );
  }

  /// Creates an [Effect] that waits for an explicit first run.
  Effect lazy(
    void Function() fn, {
    JoltDebugOption? debug,
    List<Object?>? keys,
  }) {
    return use(
      JoltEffectHook(
        () => Effect.lazy(fn, debug: debug),
        keys: keys,
      ),
    );
  }
}

/// Creates an [Effect] for the current hook scope.
///
/// Reactive reads inside [fn] become dependencies. Unless [lazy] is `true`, the
/// effect runs immediately and then runs again when dependencies change. Use
/// [onEffectCleanup] inside [fn] to clean up work from the previous run. Use
/// [JoltEffectHookCreator.lazy] when the first run should be triggered manually
/// with [Effect.run]. The effect is disposed when the widget unmounts.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   useJoltEffect(() {
///     debugPrint('Count changed: ${count.value}');
///   });
///
///   return Text('Count: ${count.value}');
/// }
/// ```
final useJoltEffect = JoltEffectHookCreator._();

/// Post-frame effect hook factory methods.
final class JoltPostFrameEffectHookCreator {
  const JoltPostFrameEffectHookCreator._();

  /// Creates a [PostFrameEffect] that runs [fn] at frame end.
  PostFrameEffect call(
    void Function() fn, {
    bool lazy = false,
    JoltDebugOption? debug,
    List<Object?>? keys,
  }) {
    return use(
      JoltEffectHook(
        () => PostFrameEffect(fn, lazy: lazy, debug: debug),
        keys: keys,
      ),
    );
  }

  /// Creates a [PostFrameEffect] that waits for an explicit first run.
  PostFrameEffect lazy(
    void Function() fn, {
    JoltDebugOption? debug,
    List<Object?>? keys,
  }) {
    return use(
      JoltEffectHook(
        () => PostFrameEffect(fn, lazy: true, debug: debug),
        keys: keys,
      ),
    );
  }
}

/// Creates a [PostFrameEffect] for the current hook scope.
///
/// Reactive reads inside [fn] become dependencies. Unless [lazy] is `true`, the
/// effect schedules its first run immediately, then coalesces later dependency
/// changes so the body runs once at the end of the frame. Prefer [useJoltEffect]
/// when immediate execution is acceptable.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final size = useSignal(Size.zero);
///
///   usePostFrameEffect(() {
///     debugPrint('Measured size: ${size.value}');
///   });
///
///   return const SizedBox.expand();
/// }
/// ```
final usePostFrameEffect = JoltPostFrameEffectHookCreator._();

/// Watcher hook factory methods.
final class JoltWatcherHookCreator {
  const JoltWatcherHookCreator._();

  /// Creates a [Watcher] over values returned by [sources].
  Watcher call<T>(
    T Function() sources,
    WatcherFn<T> fn, {
    List<Object?>? keys,
    JoltDebugOption? debug,
    bool immediately = false,
    WhenFn<T>? when,
  }) {
    return use(
      JoltEffectHook(
        () => Watcher<T>(
          sources,
          fn,
          immediately: immediately,
          when: when,
          debug: debug,
        ),
        keys: keys,
      ),
    );
  }

  /// Creates a [Watcher] that also runs [fn] for the initial source values.
  Watcher<T> immediately<T>(
    T Function() sources,
    WatcherFn<T> fn, {
    List<Object?>? keys,
    JoltDebugOption? debug,
    WhenFn<T>? when,
  }) {
    return use(JoltEffectHook(
        () => Watcher<T>.immediately(sources, fn, when: when, debug: debug),
        keys: keys));
  }

  /// Creates a [Watcher] that disposes itself after the first callback.
  Watcher<T> once<T>(
    T Function() sources,
    WatcherFn<T> fn, {
    List<Object?>? keys,
    JoltDebugOption? debug,
    WhenFn<T>? when,
  }) {
    return use(JoltEffectHook(
        () => Watcher<T>.once(sources, fn, when: when, debug: debug),
        keys: keys));
  }
}

/// Creates a [Watcher] for the current hook scope.
///
/// [fn] receives the new and previous source values returned by [sources]. Use
/// [when] to customize whether a change should trigger [fn]. Use
/// [JoltWatcherHookCreator.immediately] when the callback should also run for
/// the initial source values, or [JoltWatcherHookCreator.once] for a one-time
/// reaction.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   useWatcher(
///     () => count.value,
///     (current, previous) {
///       debugPrint('Count changed from $previous to $current');
///     },
///   );
///
///   return Text('Count: ${count.value}');
/// }
/// ```
final useWatcher = JoltWatcherHookCreator._();

/// Effect-scope hook factory methods.
final class JoltEffectScopeHookCreator {
  const JoltEffectScopeHookCreator._();

  /// Creates an [EffectScope] for the current hook scope.
  EffectScope call({
    void Function(EffectScope scope)? fn,
    bool detach = false,
    List<Object?>? keys,
    JoltDebugOption? debug,
  }) {
    return use(JoltEffectHook(() {
      final scope = EffectScope(detach: detach, debug: debug);
      if (fn != null) {
        scope.run(() => fn(scope));
      }
      return scope;
    }, keys: keys));
  }
}

/// Creates an [EffectScope] for the current hook scope.
///
/// Use the returned scope to group related reactive work and dispose it
/// together. When [detach] is `true`, the scope is detached from the current
/// effect context. Optionally pass [fn] to run work inside the scope during
/// hook creation.
///
/// ```dart
/// Widget build(BuildContext context) {
///   useEffectScope(fn: (scope) {
///     scope.run(() {
///       final count = Signal(0);
///       Effect(() => debugPrint('${count.value}'));
///     });
///   });
///
///   return const SizedBox.shrink();
/// }
/// ```
final useEffectScope = JoltEffectScopeHookCreator._();

/// Until hook factory methods.
final class JoltUntilHookCreator {
  const JoltUntilHookCreator._();

  /// Creates an [Until] that waits for [source] to satisfy [predicate].
  Until<T> call<T>(
    Readable<T> source,
    bool Function(T value) predicate, {
    bool? detach,
    List<Object?>? keys,
  }) {
    return use(
      JoltUntilHook<T>(
        () => Until<T>(source, predicate, detach: detach),
        keys: keys,
      ),
    );
  }

  /// Creates an [Until] that waits for [source] to equal [value].
  Until<T> when<T>(
    Readable<T> source,
    T value, {
    bool? detach,
    List<Object?>? keys,
  }) {
    return use(
      JoltUntilHook<T>(
        () => Until<T>.when(source, value, detach: detach),
        keys: keys,
      ),
    );
  }

  /// Creates an [Until] that waits for [source] to change.
  Until<T> changed<T>(
    Readable<T> source, {
    bool? detach,
    List<Object?>? keys,
  }) {
    return use(
      JoltUntilHook<T>(
        () => Until<T>.changed(source, detach: detach),
        keys: keys,
      ),
    );
  }
}

/// Creates an [Until] hook that waits for a reactive value to satisfy a condition.
///
/// The returned [Until] implements [Future] and is cancelled automatically when
/// the widget unmounts. Use [JoltUntilHookCreator.when] or
/// [JoltUntilHookCreator.changed] for equality and change-based waits.
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///   final until = useUntil(count, (value) => value >= 5);
///
///   useEffect(() {
///     until.then((value) => debugPrint('Reached $value'));
///     return null;
///   }, const []);
///
///   return Text('Count: ${count.value}');
/// }
/// ```
final useUntil = JoltUntilHookCreator._();

/// Converts a [Readable] into a [Stream] for the current hook scope.
///
/// The stream emits whenever [value] changes. Pass [keys] to recreate the hook
/// when the readable instance changes.
///
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
Stream<T> useJoltStream<T>(Readable<T> value, {List<Object?>? keys}) {
  final stream = useMemoized(() => value.stream, keys ?? const []);

  return stream;
}

/// Creates a widget that rebuilds when reactive dependencies change.
///
/// This hook must be used inside a [HookBuilder]. Reactive reads inside
/// [builder] become dependencies and schedule a rebuild when they change.
/// Pass [keys] to recreate the hook when dependencies change.
///
/// ```dart
/// Widget build(BuildContext context) {
///   return HookBuilder(
///     builder: (context) {
///       final count = useSignal(0);
///
///       return useJoltWidget(() {
///         return Column(
///           children: [
///             Text('Count: ${count.value}'),
///             ElevatedButton(
///               onPressed: () => count.value++,
///               child: const Text('Increment'),
///             ),
///           ],
///         );
///       });
///     },
///   );
/// }
/// ```
T useJoltWidget<T extends Widget>(T Function() builder, {List<Object?>? keys}) {
  return use(JoltWidgetHook(builder, keys: keys));
}
