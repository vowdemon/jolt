import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../setup/framework.dart';
import 'annotation.dart';

/// Creates a [ValueNotifier] initialized with [initialValue].
///
/// The notifier is created once for the setup scope and disposed when the
/// scope unmounts.
///
/// ```dart
/// setup(context, props) {
///   final count = useValueNotifier(0);
///
///   return () => ValueListenableBuilder(
///     valueListenable: count,
///     builder: (_, value, __) => Text('$value'),
///   );
/// }
/// ```
@defineHook
ValueNotifier<T> useValueNotifier<T>(T initialValue) {
  return useChangeNotifier(
    () => ValueNotifier(initialValue),
  );
}

/// Value-listenable listener hook factory methods.
final class JoltSetupHookListenValueCreator {
  const JoltSetupHookListenValueCreator._();

  /// Subscribes [listener] to a stable [ValueListenable].
  @defineHook
  void call<T>(
    ValueListenable<T> listenable,
    void Function(T value) listener,
  ) {
    useHook(_ValueListenableHook(listenable, listener));
  }

  /// Subscribes to a [ValueListenable] held by [source].
  @defineHook
  void watch<T>(
    Readable<ValueListenable<T>> source,
    void Function(T value) listener,
  ) {
    useHook(_ValueListenableFromHook(source, listener));
  }
}

final class JoltSetupHookListenListenableCreator {
  const JoltSetupHookListenListenableCreator._();

  /// Subscribes [listener] to a stable [Listenable].
  @defineHook
  void call(Listenable listenable, VoidCallback listener) {
    useHook(_ListenableHook(listenable, listener));
  }

  /// Subscribes to a [Listenable] held by [source].
  @defineHook
  void watch(
    Readable<Listenable> source,
    VoidCallback listener,
  ) {
    useHook(_ListenableFromHook(source, listener));
  }
}

final class JoltSetupHookListenStreamCreator {
  const JoltSetupHookListenStreamCreator._();

  /// Subscribes to [stream] and cancels the subscription on unmount.
  @defineHook
  StreamSubscription<T> call<T>(
    Stream<T> stream,
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return useHook(_UseStreamSubscriptionHook(
      stream,
      onData,
      onError,
      onDone,
      cancelOnError,
    ));
  }

  /// Subscribes to the stream held by [source].
  @defineHook
  void watch<T>(
    Readable<Stream<T>?> source,
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    useHook(_StreamFromHook(source, onData, onError, onDone, cancelOnError));
  }
}

final class JoltSetupHookListenCreator {
  const JoltSetupHookListenCreator._();

  final value = const JoltSetupHookListenValueCreator._();
  final listenable = const JoltSetupHookListenListenableCreator._();
  final stream = const JoltSetupHookListenStreamCreator._();
}

/// Subscribes to external listenables for the current setup scope.
///
/// `useListen` is intentionally limited to subscription side effects: it
/// attaches a listener, updates callbacks on hot reload, and detaches on
/// unmount. Use [useSync] when a source should be synchronized into a
/// [Writable]. Reach for `.value`, `.listenable`, or `.stream`, and their
/// `.watch` variants when the source itself can change.
///
/// ```dart
/// setup(context, props) {
///   final notifier = useValueNotifier(0);
///
///   useListen.value(notifier, (value) {
///     debugPrint('value: $value');
///   });
///
///   return () => const SizedBox.shrink();
/// }
/// ```
const useListen = JoltSetupHookListenCreator._();

class _ValueListenableHook<E, T extends ValueListenable<E>>
    extends SetupHook<T> {
  _ValueListenableHook(this.listenable, this.listener);

  late T listenable;
  late void Function(E value) listener;

  void _listener() {
    listener(listenable.value);
  }

  @override
  T build() {
    listenable.addListener(_listener);
    return listenable;
  }

  @override
  void unmount() {
    listenable.removeListener(_listener);
  }

  @override
  void reassemble(covariant _ValueListenableHook<E, T> newHook) {
    final hasNewListenable = newHook.listenable != listenable;

    if (hasNewListenable) {
      listenable.removeListener(_listener);
      listenable = newHook.listenable;
      listener = newHook.listener;
      listenable.addListener(_listener);
    } else {
      listener = newHook.listener;
    }
  }
}

class _ValueListenableFromHook<T> extends SetupHook<ValueListenable<T>> {
  _ValueListenableFromHook(this.source, this.listener);

  late Readable<ValueListenable<T>> source;
  late void Function(T value) listener;

  ValueListenable<T>? _listenable;
  void Function()? _disposeEffect;

  void _listener() {
    final listenable = _listenable;
    if (listenable == null) {
      return;
    }
    listener(listenable.value);
  }

  void _attach(ValueListenable<T> listenable, {bool notify = false}) {
    _listenable = listenable;
    listenable.addListener(_listener);
    if (notify) {
      listener(listenable.value);
    }
  }

  void _detach() {
    final listenable = _listenable;
    if (listenable == null) {
      return;
    }
    listenable.removeListener(_listener);
    _listenable = null;
  }

  @override
  ValueListenable<T> build() {
    final listenable = source.value;
    _attach(listenable);
    return listenable;
  }

  @override
  void mount() {
    _disposeEffect = Effect(() {
      final next = source.value;
      if (identical(next, _listenable)) {
        return;
      }
      _detach();
      _attach(next, notify: true);
      rawState = next;
    }).dispose;
  }

  @override
  void unmount() {
    _disposeEffect?.call();
    _disposeEffect = null;
    _detach();
  }

  @override
  void reassemble(covariant _ValueListenableFromHook<T> newHook) {
    source = newHook.source;
    listener = newHook.listener;

    final next = source.value;
    if (!identical(next, _listenable)) {
      _detach();
      _attach(next, notify: true);
      rawState = next;
    }
  }
}

class _ListenableHook<T extends Listenable> extends SetupHook<T> {
  _ListenableHook(this.listenable, this.listener);

  late T listenable;
  late VoidCallback listener;

  void _listener() {
    listener();
  }

  @override
  T build() {
    listenable.addListener(_listener);
    return listenable;
  }

  @override
  void unmount() {
    listenable.removeListener(_listener);
  }

  @override
  void reassemble(covariant _ListenableHook<T> newHook) {
    final hasNewListenable = newHook.listenable != listenable;

    if (hasNewListenable) {
      listenable.removeListener(_listener);
      listenable = newHook.listenable;
      listener = newHook.listener;
      listenable.addListener(_listener);
    } else {
      listener = newHook.listener;
    }
  }
}

class _ListenableFromHook extends SetupHook<Listenable> {
  _ListenableFromHook(this.source, this.listener);

  late Readable<Listenable> source;
  late VoidCallback listener;

  Listenable? _listenable;
  void Function()? _disposeEffect;

  void _listener() {
    listener();
  }

  void _attach(Listenable listenable, {bool notify = false}) {
    _listenable = listenable;
    listenable.addListener(_listener);
    if (notify) {
      listener();
    }
  }

  void _detach() {
    final listenable = _listenable;
    if (listenable == null) {
      return;
    }
    listenable.removeListener(_listener);
    _listenable = null;
  }

  @override
  Listenable build() {
    final listenable = source.value;
    _attach(listenable);
    return listenable;
  }

  @override
  void mount() {
    _disposeEffect = Effect(() {
      final next = source.value;
      if (identical(next, _listenable)) {
        return;
      }
      _detach();
      _attach(next, notify: true);
      rawState = next;
    }).dispose;
  }

  @override
  void unmount() {
    _disposeEffect?.call();
    _disposeEffect = null;
    _detach();
  }

  @override
  void reassemble(covariant _ListenableFromHook newHook) {
    source = newHook.source;
    listener = newHook.listener;

    final next = source.value;
    if (!identical(next, _listenable)) {
      _detach();
      _attach(next, notify: true);
      rawState = next;
    }
  }
}

class _UseStreamSubscriptionHook<T> extends SetupHook<StreamSubscription<T>> {
  _UseStreamSubscriptionHook(
    this.stream,
    this.onData,
    this.onError,
    this.onDone,
    this.cancelOnError,
  );

  late Stream<T> stream;
  late void Function(T event)? onData;
  late Function? onError;
  late void Function()? onDone;
  late bool? cancelOnError;

  void _onData(T data) {
    onData?.call(data);
  }

  void _onError(Object error, StackTrace stackTrace) {
    onError?.call(error, stackTrace);
  }

  void _onDone() {
    onDone?.call();
  }

  @override
  StreamSubscription<T> build() {
    return stream.listen(_onData,
        onError: _onError, onDone: _onDone, cancelOnError: cancelOnError);
  }

  @override
  void unmount() {
    state.cancel();
  }

  @override
  void reassemble(covariant _UseStreamSubscriptionHook<T> newHook) {
    final needRecreate =
        stream != newHook.stream || cancelOnError != newHook.cancelOnError;

    stream = newHook.stream;
    onData = newHook.onData;
    onError = newHook.onError;
    onDone = newHook.onDone;
    cancelOnError = newHook.cancelOnError;

    if (needRecreate) {
      state.cancel();
      rawState = build();
    }
  }
}

class _StreamFromHook<T> extends SetupHook<StreamSubscription<T>?> {
  _StreamFromHook(
    this.source,
    this.onData,
    this.onError,
    this.onDone,
    this.cancelOnError,
  );

  late Readable<Stream<T>?> source;
  late void Function(T event)? onData;
  late Function? onError;
  late void Function()? onDone;
  late bool? cancelOnError;

  Stream<T>? _stream;
  StreamSubscription<T>? _subscription;
  void Function()? _disposeEffect;

  void _onData(T data) {
    onData?.call(data);
  }

  void _onError(Object error, StackTrace stackTrace) {
    onError?.call(error, stackTrace);
  }

  void _onDone() {
    onDone?.call();
  }

  StreamSubscription<T>? _subscribe(Stream<T>? stream) {
    _stream = stream;
    if (stream == null) {
      return null;
    }
    _subscription = stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: cancelOnError,
    );
    return _subscription;
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  StreamSubscription<T>? build() {
    return _subscribe(source.value);
  }

  @override
  void mount() {
    _disposeEffect = Effect(() {
      final next = source.value;
      if (identical(next, _stream)) {
        return;
      }
      _unsubscribe();
      rawState = _subscribe(next);
    }).dispose;
  }

  @override
  void unmount() {
    _disposeEffect?.call();
    _disposeEffect = null;
    _unsubscribe();
    _stream = null;
  }

  @override
  void reassemble(covariant _StreamFromHook<T> newHook) {
    final needRecreate =
        cancelOnError != newHook.cancelOnError || source != newHook.source;

    source = newHook.source;
    onData = newHook.onData;
    onError = newHook.onError;
    onDone = newHook.onDone;
    cancelOnError = newHook.cancelOnError;

    final next = source.value;
    if (needRecreate || !identical(next, _stream)) {
      _unsubscribe();
      rawState = _subscribe(next);
    }
  }
}

/// Listenables synchronization hook factory methods.
final class JoltSetupHookSyncCreator {
  const JoltSetupHookSyncCreator._();

  /// Synchronizes [source] into [target].
  @defineHook
  void from<T, C extends Listenable>(
    Writable<T> target,
    C source, {
    required T Function(C source) getter,
  }) {
    useMemoized(() {
      void listener() {
        target.value = getter(source);
      }

      source.addListener(listener);

      return () {
        source.removeListener(listener);
      };
    }, (disposer) => disposer());
  }

  /// Synchronizes [source] and [target] in both directions.
  @defineHook
  void bidi<T, C extends Listenable>(
    Writable<T> target,
    C source, {
    required T Function(C source) getter,
    required void Function(T value) setter,
  }) {
    useMemoized(() {
      bool skip = true;
      final effect = Effect(() {
        final value = target.value;
        if (skip) {
          skip = false;
          return;
        }
        setter(value);
      });

      void listener() {
        skip = true;
        try {
          target.value = getter(source);
        } catch (_) {
          skip = false;
          rethrow;
        }
      }

      source.addListener(listener);

      return () {
        effect.dispose();
        source.removeListener(listener);
      };
    }, (disposer) => disposer());
  }
}

/// Synchronizes external listenables with Jolt state for the current setup scope.
///
/// Use [JoltSetupHookSyncCreator.from] to copy from a listenable into a
/// [Writable], or [JoltSetupHookSyncCreator.bidi] for two-way synchronization.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTextEditingController();
///   final text = useSignal('');
///
///   useSync.bidi(
///     text,
///     controller,
///     getter: (controller) => controller.text,
///     setter: (value) => controller.text = value,
///   );
///
///   return () => TextField(controller: controller);
/// }
/// ```
const useSync = JoltSetupHookSyncCreator._();

class _ChangeNotifierHook<T extends ChangeNotifier> extends SetupHook<T> {
  _ChangeNotifierHook(this.creator);

  final T Function() creator;
  @override
  T build() => creator();

  @override
  void unmount() {
    state.dispose();
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')

/// Creates a [ChangeNotifier] once and disposes it when setup unmounts.
///
/// This is the low-level building block behind the controller hooks in this
/// package. Use it when Flutter already provides a notifier type and no
/// specialized helper exists yet.
///
/// ```dart
/// setup(context, props) {
///   final notifier = useChangeNotifier(() => ValueNotifier(0));
///
///   return () => Text('${notifier.value}');
/// }
/// ```
@defineHook
T useChangeNotifier<T extends ChangeNotifier>(T Function() creator) {
  return useHook(_ChangeNotifierHook(creator));
}
