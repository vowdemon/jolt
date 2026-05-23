import 'dart:async';

import 'package:jolt/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../setup/framework.dart';
import 'annotation.dart';

/// Signal hook factory methods.
final class JoltSetupHookSignalCreator {
  const JoltSetupHookSignalCreator._();

  /// Creates a writable [Signal] with [value] as its initial value.
  @defineHook
  Signal<T> call<T>(
    T value, {
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => Signal(value, debug: debug));
  }

  /// Creates a [Signal] without an initial value.
  @defineHook
  Signal<T> lazy<T>({
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => Signal.lazy(debug: debug));
  }

  /// Creates a reactive [ListSignal] initialized with [value].
  @defineHook
  ListSignal<T> list<T>(
    List<T>? value, {
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => ListSignal(value, debug: debug));
  }

  /// Creates a reactive [MapSignal] initialized with [value].
  @defineHook
  MapSignal<K, V> map<K, V>(
    Map<K, V>? value, {
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => MapSignal(value, debug: debug));
  }

  /// Creates a reactive [SetSignal] initialized with [value].
  @defineHook
  SetSignal<T> set<T>(
    Set<T>? value, {
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => SetSignal(value, debug: debug));
  }

  /// Creates an [IterableSignal] derived from [getter].
  @defineHook
  IterableSignal<T> iterable<T>(
    Iterable<T> Function() getter, {
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => IterableSignal<T>(getter, debug: debug));
  }

  /// Creates an [AsyncSignal] from [source].
  @defineHook
  AsyncSignal<T> async<T>(
    AsyncSource<T> Function() source, {
    AsyncState<T> Function()? initialValue,
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => AsyncSignal(
        source: source(), initialValue: initialValue?.call(), debug: debug));
  }
}

/// Creates a writable [Signal] for the current setup scope.
///
/// The signal is created once, survives reactive rebuilds, and is disposed when
/// the setup scope unmounts. Use [JoltSetupHookSignalCreator.lazy],
/// [JoltSetupHookSignalCreator.list], [JoltSetupHookSignalCreator.map],
/// [JoltSetupHookSignalCreator.set], [JoltSetupHookSignalCreator.iterable], or
/// [JoltSetupHookSignalCreator.async] when the stored value needs specialized
/// collection or async behavior.
///
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///
///   return () => FilledButton(
///     onPressed: () => count.value++,
///     child: Text('Count: ${count.value}'),
///   );
/// }
/// ```
@defineHook
const useSignal = JoltSetupHookSignalCreator._();

/// Computed hook factory methods.
final class JoltSetupHookComputedCreator {
  const JoltSetupHookComputedCreator._();

  /// Creates a [Computed] value from [getter].
  @defineHook
  Computed<T> call<T>(T Function() getter, {JoltDebugOption? debug}) {
    return useAutoDispose(() => Computed(getter, debug: debug));
  }

  /// Creates a [Computed] whose [getter] receives the previous value.
  @defineHook
  Computed<T> withPrevious<T>(T Function(T?) getter, {JoltDebugOption? debug}) {
    return useAutoDispose(() => Computed.withPrevious(getter, debug: debug));
  }

  /// Creates a [WritableComputed] from [getter] and [setter].
  @defineHook
  WritableComputed<T> writable<T>(T Function() getter, void Function(T) setter,
      {JoltDebugOption? debug}) {
    return useAutoDispose(() => WritableComputed(getter, setter, debug: debug));
  }

  /// Creates a writable [Computed] whose [getter] receives the previous value.
  @defineHook
  WritableComputed<T> writableWithPrevious<T>(
      T Function(T?) getter, void Function(T) setter,
      {JoltDebugOption? debug}) {
    return useAutoDispose(
        () => WritableComputed.withPrevious(getter, setter, debug: debug));
  }
}

/// Creates a [Computed] value for the current setup scope.
///
/// Reactive reads inside the getter become dependencies. The result is cached
/// and recomputed only after one of those dependencies changes. Use
/// [JoltSetupHookComputedCreator.withPrevious] or
/// [JoltSetupHookComputedCreator.writable] when the derived value needs
/// previous-value access or a writable interface.
///
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///   final doubled = useComputed(() => count.value * 2);
///
///   return () => Text('Double: ${doubled.value}');
/// }
/// ```
const useComputed = JoltSetupHookComputedCreator._();

// ignore: unused_element
class _UseEffectHook extends SetupHook<EffectImpl> {
  _UseEffectHook(this.effect, this.lazy, this.debug);

  late void Function() effect;
  late bool lazy;
  late JoltDebugOption? debug;

  void _runEffect() {
    effect();
  }

  @override
  EffectImpl build() {
    return EffectImpl(_runEffect, lazy: lazy, debug: debug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  @override
  void reassemble(covariant _UseEffectHook newHook) {
    if (debug != newHook.debug) {
      debug = newHook.debug;
      JoltDevTools.setDebug(state.raw, newHook.debug?.onDebug);
    }
    lazy = newHook.lazy;
    effect = newHook.effect;
  }
}

/// Effect hook factory methods.
final class JoltSetupHookEffectCreator {
  const JoltSetupHookEffectCreator._();

  /// Creates an [Effect] that runs [effect] reactively.
  @defineHook
  Effect call(void Function() effect,
      {bool lazy = false, JoltDebugOption? debug}) {
    return useHook(_UseEffectHook(effect, lazy, debug));
  }

  /// Creates an [Effect] that waits for an explicit first run.
  @defineHook
  Effect lazy(void Function() effect, {JoltDebugOption? debug}) {
    return useHook(_UseEffectHook(effect, true, debug));
  }
}

/// Creates an [Effect] for the current setup scope.
///
/// Reactive reads inside [effect] become dependencies. Unless [lazy] is
/// `true`, the effect runs immediately and then runs again when dependencies
/// change. Use [onEffectCleanup] inside [effect] to clean up work from the
/// previous run. Use [JoltSetupHookEffectCreator.lazy] when the first run should
/// be triggered manually with [Effect.run].
///
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///
///   useEffect(() {
///     debugPrint('Count changed: ${count.value}');
///   });
///
///   return () => Text('Count: ${count.value}');
/// }
/// ```
const useEffect = JoltSetupHookEffectCreator._();

class _UsePostFrameEffectHook extends SetupHook<PostFrameEffect> {
  _UsePostFrameEffectHook(this.effect, this.lazy, this.debug);

  late void Function() effect;
  late bool lazy;
  late JoltDebugOption? debug;

  void _runEffect() {
    effect();
  }

  @override
  PostFrameEffect build() {
    return PostFrameEffect(_runEffect, lazy: lazy, debug: debug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  @override
  void reassemble(covariant _UsePostFrameEffectHook newHook) {
    if (debug != newHook.debug) {
      debug = newHook.debug;
      JoltDevTools.setDebug((state as EffectImpl).raw, newHook.debug?.onDebug);
    }
    lazy = newHook.lazy;
    effect = newHook.effect;
  }
}

/// Post-frame effect hook factory methods.
final class JoltSetupHookPostFrameEffectCreator {
  const JoltSetupHookPostFrameEffectCreator._();

  /// Creates a [PostFrameEffect] that runs [effect] at frame end.
  @defineHook
  PostFrameEffect call(void Function() effect,
      {bool lazy = false, JoltDebugOption? debug}) {
    return useHook(_UsePostFrameEffectHook(effect, lazy, debug));
  }

  /// Creates a [PostFrameEffect] that waits for an explicit first run.
  @defineHook
  PostFrameEffect lazy(void Function() effect, {JoltDebugOption? debug}) {
    return useHook(_UsePostFrameEffectHook(effect, true, debug));
  }
}

/// Creates a [PostFrameEffect] for the current setup scope.
///
/// Reactive reads inside [effect] become dependencies. Unless [lazy] is
/// `true`, the effect schedules its first run immediately, then coalesces later
/// dependency changes so the body runs once at the end of the frame. Use
/// [onEffectCleanup] inside [effect] to clean up work from the previous run.
/// Use [JoltSetupHookPostFrameEffectCreator.lazy] when the first run should be
/// triggered manually with [PostFrameEffect.run].
///
/// ```dart
/// setup(context, props) {
///   final controller = useScrollController();
///   final shouldScroll = useSignal(false);
///
///   usePostFrameEffect(() {
///     if (shouldScroll.value && controller.hasClients) {
///       controller.jumpTo(controller.position.maxScrollExtent);
///     }
///   });
///
///   return () => ListView(controller: controller);
/// }
/// ```
const usePostFrameEffect = JoltSetupHookPostFrameEffectCreator._();

class _UseWatcherHook<T> extends SetupHook<WatcherImpl<T>> {
  _UseWatcherHook(this.sourcesFn, this.fn,
      {this.when, this.immediately = false, this.debug});

  late SourcesFn<T> sourcesFn;
  late WatcherFn<T> fn;
  late WhenFn<T>? when;
  late bool immediately;
  late JoltDebugOption? debug;

  @override
  WatcherImpl<T> build() {
    return WatcherImpl(sourcesFn, fn,
        when: when, immediately: immediately, debug: debug);
  }

  @override
  void unmount() {
    state.dispose();
  }

  @override
  void reassemble(covariant _UseWatcherHook<T> newHook) {
    final shouldRecreate = newHook.immediately != immediately;
    final wasPaused = state.isPaused;

    if (debug != newHook.debug) {
      debug = newHook.debug;
      JoltDevTools.setDebug(state, newHook.debug?.onDebug);
    }

    sourcesFn = newHook.sourcesFn;
    fn = newHook.fn;
    when = newHook.when;
    immediately = newHook.immediately;

    if (shouldRecreate) {
      state.dispose();
      rawState = build();
      return;
    }

    state.sourcesFn = sourcesFn;
    state.fn = fn;
    state.when = when;

    state.currentValues = state.previosValues = untracked(state.sourcesFn);

    if (!wasPaused) {
      state.pause();
      state.resume();
    }
  }
}

/// Watcher hook factory methods.
final class JoltSetupHookWatcherCreator {
  const JoltSetupHookWatcherCreator._();

  /// Creates a [Watcher] over values returned by [sourcesFn].
  @defineHook
  Watcher call<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool immediately = false,
    JoltDebugOption? debug,
  }) {
    return useHook(_UseWatcherHook<T>(sourcesFn, fn,
        when: when, immediately: immediately, debug: debug));
  }

  /// Creates a [Watcher] that also runs [fn] for the initial source values.
  @defineHook
  Watcher<T> immediately<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugOption? debug,
  }) {
    return useHook(_UseWatcherHook<T>(sourcesFn, fn,
        when: when, immediately: true, debug: debug));
  }

  /// Creates a [Watcher] that disposes itself after the first callback.
  @defineHook
  Watcher<T> once<T>(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    JoltDebugOption? debug,
  }) {
    late _UseWatcherHook<T> hook;
    hook = _UseWatcherHook<T>(sourcesFn, (newValue, oldValue) {
      fn(newValue, oldValue);
      hook.state.dispose();
    }, when: when, immediately: false, debug: debug);
    return useHook(hook);
  }
}

/// Creates a [Watcher] for the current setup scope.
///
/// [fn] receives the new and previous source values returned by [sourcesFn].
/// Use [when] to customize whether a change should trigger [fn]. Use
/// [JoltSetupHookWatcherCreator.immediately] when the callback should also run
/// for the initial source values, or [JoltSetupHookWatcherCreator.once] for a
/// one-time reaction.
///
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///
///   useWatcher(
///     () => count.value,
///     (current, previous) {
///       debugPrint('Count changed from $previous to $current');
///     },
///   );
///
///   return () => Text('Count: ${count.value}');
/// }
/// ```
const useWatcher = JoltSetupHookWatcherCreator._();

/// Effect-scope hook factory methods.
final class JoltSetupHookEffectScopeCreator {
  const JoltSetupHookEffectScopeCreator._();

  /// Creates an [EffectScope] owned by the current setup scope.
  @defineHook
  EffectScope call({
    bool detach = false,
    JoltDebugOption? debug,
  }) {
    return useAutoDispose(() => EffectScope(detach: detach, debug: debug));
  }
}

/// Creates an [EffectScope] for the current setup scope.
///
/// Use the returned scope to group related reactive work and dispose it
/// together. When [detach] is `true`, the scope is detached from the current
/// effect context.
///
/// ```dart
/// setup(context, props) {
///   final scope = useEffectScope();
///
///   onMounted(() {
///     scope.run(() {
///       final count = Signal(0);
///       Effect(() => debugPrint('${count.value}'));
///     });
///   });
///
///   return () => const SizedBox.shrink();
/// }
/// ```
const useEffectScope = JoltSetupHookEffectScopeCreator._();

class _UseUntilHook<T> extends SetupHook<Until<T>> {
  _UseUntilHook(this.source, this.predicate, {this.detach});

  late Readable<T> source;
  late bool Function(T value) predicate;
  late bool? detach;

  @override
  Until<T> build() => Until<T>(source, predicate, detach: detach);

  @override
  void unmount() {
    state.cancel();
  }

  @override
  void reassemble(covariant _UseUntilHook<T> newHook) {
    state.cancel();
    source = newHook.source;
    predicate = newHook.predicate;
    detach = newHook.detach;
    rawState = build();
  }
}

class _UseUntilWhenHook<T> extends SetupHook<Until<T>> {
  _UseUntilWhenHook(this.source, this.value, {this.detach});

  late Readable<T> source;
  late T value;
  late bool? detach;

  @override
  Until<T> build() => Until<T>.when(source, value, detach: detach);

  @override
  void unmount() {
    state.cancel();
  }

  @override
  void reassemble(covariant _UseUntilWhenHook<T> newHook) {
    state.cancel();
    source = newHook.source;
    value = newHook.value;
    detach = newHook.detach;
    rawState = build();
  }
}

class _UseUntilChangedHook<T> extends SetupHook<Until<T>> {
  _UseUntilChangedHook(this.source, {this.detach});

  late Readable<T> source;
  late bool? detach;

  @override
  Until<T> build() => Until<T>.changed(source, detach: detach);

  @override
  void unmount() {
    state.cancel();
  }

  @override
  void reassemble(covariant _UseUntilChangedHook<T> newHook) {
    state.cancel();
    source = newHook.source;
    detach = newHook.detach;
    rawState = build();
  }
}

/// Until hook factory methods.
final class JoltSetupHookUntilCreator {
  const JoltSetupHookUntilCreator._();

  /// Creates an [Until] that waits for [source] to satisfy [predicate].
  @defineHook
  Until<T> call<T>(
    Readable<T> source,
    bool Function(T value) predicate, {
    bool? detach,
  }) {
    return useHook(_UseUntilHook<T>(source, predicate, detach: detach));
  }

  /// Creates an [Until] that waits for [source] to equal [value].
  @defineHook
  Until<T> when<T>(
    Readable<T> source,
    T value, {
    bool? detach,
  }) {
    return useHook(_UseUntilWhenHook<T>(source, value, detach: detach));
  }

  /// Creates an [Until] that waits for [source] to change.
  @defineHook
  Until<T> changed<T>(
    Readable<T> source, {
    bool? detach,
  }) {
    return useHook(_UseUntilChangedHook<T>(source, detach: detach));
  }
}

/// Creates an [Until] hook that waits for a reactive value to satisfy a condition.
///
/// The returned [Until] implements [Future] and completes when the predicate
/// returns `true` for the current value. It is cancelled automatically when the
/// setup scope unmounts. Use [JoltSetupHookUntilCreator.when] or
/// [JoltSetupHookUntilCreator.changed] for equality and change-based waits.
///
/// ```dart
/// setup(context, props) {
///   final count = useSignal(0);
///   final until = useUntil(count, (value) => value >= 5);
///
///   onMounted(() async {
///     debugPrint('Reached ${await until}');
///   });
///
///   return () => Text('Count: ${count.value}');
/// }
/// ```
const useUntil = JoltSetupHookUntilCreator._();
