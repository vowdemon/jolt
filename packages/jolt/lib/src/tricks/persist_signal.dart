import 'dart:async';

import 'package:jolt/jolt.dart';

class PersistSignal<T> extends Signal<T> {
  PersistSignal(
      {T Function()? initialValue,
      required this.read,
      required this.write,
      bool lazy = false,
      this.writeDelay = Duration.zero,
      super.onDebug})
      : super(initialValue != null ? initialValue() : null) {
    if (!lazy) {
      _load();
    }
  }

  int _version = 0;
  final Duration writeDelay;
  bool hasInitialized = false;

  Future<void>? _initialValueFuture;

  factory PersistSignal.lazy({
    T Function()? initialValue,
    required FutureOr<T> Function() read,
    required FutureOr<void> Function(T value) write,
  }) =>
      PersistSignal<T>(
        initialValue: initialValue,
        read: read,
        write: write,
        lazy: true,
      );

  Future<void> _load() async {
    _initialValueFuture ??= Future(() async {
      final version = ++_version;
      final result = await read();
      if (_version == version) super.set(result);
      hasInitialized = true;
      return;
    });

    return _initialValueFuture;
  }

  @override
  T get() {
    if (!hasInitialized) _load();

    return super.get();
  }

  Future<T> getEnsured() async {
    if (!hasInitialized) await _load();

    return super.get();
  }

  Timer? _timer;

  @override
  void set(T value) {
    super.set(value);
    hasInitialized = true;
    _version++;

    if (writeDelay != Duration.zero) {
      _timer?.cancel();
      _timer = Timer(writeDelay, () async {
        try {
          await write(value);
        } catch (e, s) {
          Zone.current.handleUncaughtError(e, s);
        } finally {
          _timer = null;
        }
      });
    } else {
      write(value);
    }
  }

  final FutureOr<T> Function() read;
  final FutureOr<void> Function(T value) write;

  Future<void> ensure(FutureOr<void> Function()? fn) async {
    if (!hasInitialized) await _load();

    await fn?.call();
  }
}
