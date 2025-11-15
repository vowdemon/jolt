import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:jolt_flutter/src/setup/widget.dart';

/// Creates a reactive signal hook.
Signal<T> useSignal<T>(T value, {JoltDebugFn? onDebug}) {
  return useHook(() => Signal(value, onDebug: onDebug));
}

/// Creates a computed value hook.
Computed<T> useComputed<T>(T Function() getter, {JoltDebugFn? onDebug}) {
  return useHook(() => Computed(getter, onDebug: onDebug));
}

/// Creates a writable computed value hook.
WritableComputed<T> useWritableComputed<T>(
    T Function() getter, void Function(T) setter,
    {JoltDebugFn? onDebug}) {
  return useHook(() => WritableComputed(getter, setter, onDebug: onDebug));
}

/// Creates an effect hook.
Effect useJoltEffect(void Function() effect,
    {bool immediately = true, JoltDebugFn? onDebug}) {
  return useHook(
      () => Effect(effect, immediately: immediately, onDebug: onDebug));
}

/// Creates a watcher hook.
Watcher useJoltWatcher<T>(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
    {WhenFn<T>? when, bool immediately = false, JoltDebugFn? onDebug}) {
  return useHook(() => Watcher<T>(sourcesFn, fn,
      when: when, immediately: immediately, onDebug: onDebug));
}

/// Creates an effect scope hook.
EffectScope useJoltEffectScope({bool? detach, JoltDebugFn? onDebug}) {
  return useHook(() => EffectScope(detach: detach, onDebug: onDebug));
}

/// Creates a reactive list signal hook.
ListSignal<T> useListSignal<T>(List<T>? value, {JoltDebugFn? onDebug}) {
  return useHook(() => ListSignal(value, onDebug: onDebug));
}

/// Creates a reactive map signal hook.
MapSignal<K, V> useMapSignal<K, V>(Map<K, V>? value, {JoltDebugFn? onDebug}) {
  return useHook(() => MapSignal(value, onDebug: onDebug));
}

/// Creates a reactive set signal hook.
SetSignal<T> useSetSignal<T>(Set<T>? value, {JoltDebugFn? onDebug}) {
  return useHook(() => SetSignal(value, onDebug: onDebug));
}

/// Creates a reactive iterable signal hook.
IterableSignal<T> useIterableSignal<T>(Iterable<T> Function() getter,
    {JoltDebugFn? onDebug}) {
  return useHook(() => IterableSignal<T>(getter, onDebug: onDebug));
}

/// Creates a stream hook from a reactive node.
Stream<T> useJoltStream<T>(ReadonlyNode<T> node, {JoltDebugFn? onDebug}) {
  return useHook(() => node.stream);
}

/// Creates a type-converting computed signal hook.
ConvertComputed<T, U> useConvertComputed<T, U>(
    Signal<U> source, T Function(U value) decode, U Function(T value) encode,
    {JoltDebugFn? onDebug}) {
  return useHook(() => ConvertComputed<T, U>(source,
      decode: decode, encode: encode, onDebug: onDebug));
}

/// Creates a persistent signal hook.
PersistSignal<T> usePersistSignal<T>(T Function() initialValue,
    FutureOr<T> Function() read, FutureOr<void> Function(T value) write,
    {bool lazy = false,
    Duration writeDelay = Duration.zero,
    JoltDebugFn? onDebug}) {
  return useHook(() => PersistSignal(
      initialValue: initialValue,
      read: read,
      write: write,
      lazy: lazy,
      writeDelay: writeDelay,
      onDebug: onDebug));
}
