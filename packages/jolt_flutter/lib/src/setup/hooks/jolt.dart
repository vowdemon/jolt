import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:jolt_flutter/src/setup/widget.dart';

Signal<T> useSignal<T>(T value, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => Signal(value, onDebug: onDebug));
}

Computed<T> useComputed<T>(T Function() getter, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => Computed(getter, onDebug: onDebug));
}

WritableComputed<T> useWritableComputed<T>(
    T Function() getter, void Function(T) setter,
    {JoltDebugFn? onDebug}) {
  return HookUtils.use(
      () => WritableComputed(getter, setter, onDebug: onDebug));
}

Effect useJoltEffect(void Function() effect,
    {bool immediately = true, JoltDebugFn? onDebug}) {
  return HookUtils.use(
      () => Effect(effect, immediately: immediately, onDebug: onDebug));
}

Watcher useJoltWatcher<T>(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
    {WhenFn<T>? when, bool immediately = false, JoltDebugFn? onDebug}) {
  return HookUtils.use(() => Watcher<T>(sourcesFn, fn,
      when: when, immediately: immediately, onDebug: onDebug));
}

EffectScope useJoltEffectScope({bool? detach, JoltDebugFn? onDebug}) {
  return HookUtils.use(() => EffectScope(detach: detach, onDebug: onDebug));
}

ListSignal<T> useListSignal<T>(List<T>? value, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => ListSignal(value, onDebug: onDebug));
}

MapSignal<K, V> useMapSignal<K, V>(Map<K, V>? value, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => MapSignal(value, onDebug: onDebug));
}

SetSignal<T> useSetSignal<T>(Set<T>? value, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => SetSignal(value, onDebug: onDebug));
}

IterableSignal<T> useIterableSignal<T>(Iterable<T> Function() getter,
    {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => IterableSignal<T>(getter, onDebug: onDebug));
}

Stream<T> useJoltStream<T>(ReadonlyNode<T> node, {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => node.stream);
}

ConvertComputed<T, U> useConvertComputed<T, U>(
    Signal<U> source, T Function(U value) decode, U Function(T value) encode,
    {JoltDebugFn? onDebug}) {
  return HookUtils.use(() => ConvertComputed<T, U>(source,
      decode: decode, encode: encode, onDebug: onDebug));
}

PersistSignal<T> usePersistSignal<T>(T Function() initialValue,
    FutureOr<T> Function() read, FutureOr<void> Function(T value) write,
    {bool lazy = false,
    Duration writeDelay = Duration.zero,
    JoltDebugFn? onDebug}) {
  return HookUtils.use(() => PersistSignal(
      initialValue: initialValue,
      read: read,
      write: write,
      lazy: lazy,
      writeDelay: writeDelay,
      onDebug: onDebug));
}
