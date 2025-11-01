import 'dart:async';

import 'package:jolt/jolt.dart';

/// A signal that persists its value to external storage.
///
/// PersistSignal automatically saves its value to external storage whenever
/// it changes and loads the initial value from storage when created. It
/// supports both synchronous and asynchronous read/write operations.
///
/// Example:
/// ```dart
/// final theme = PersistSignal(
///   initialValue: () => 'light',
///   read: () => SharedPreferences.getInstance()
///     .then((prefs) => prefs.getString('theme') ?? 'light'),
///   write: (value) => SharedPreferences.getInstance()
///     .then((prefs) => prefs.setString('theme', value)),
/// );
///
/// theme.value = 'dark'; // Automatically saved to storage
/// ```
class PersistSignal<T> extends Signal<T> {
  /// Creates a persistent signal with the given configuration.
  ///
  /// Parameters:
  /// - [initialValue]: Optional initial value if storage is empty
  /// - [read]: Function to read the value from storage
  /// - [write]: Function to write the value to storage
  /// - [lazy]: Whether to load the value lazily (on first access)
  /// - [writeDelay]: Delay before writing to storage (for debouncing)
  /// - [onDebug]: Optional debug callback
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

  /// Internal version counter for tracking async operations.
  int _version = 0;

  /// Delay before writing to storage (for debouncing).
  final Duration writeDelay;

  /// Whether the signal has been initialized from storage.
  bool hasInitialized = false;

  /// Future for the initial value loading operation.
  Future<void>? _initialValueFuture;

  /// Counter for ongoing write operations.
  int _writeCount = 0;

  /// Completer for waiting until all writes complete.
  Completer<void>? _writeComplete;

  /// Creates a lazy persistent signal that loads its value on first access.
  ///
  /// Parameters:
  /// - [initialValue]: Optional initial value if storage is empty
  /// - [read]: Function to read the value from storage
  /// - [write]: Function to write the value to storage
  ///
  /// Returns: A lazy PersistSignal that loads on first access
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

  /// Waits for all ongoing write operations to complete.
  Future<void> _waitForWrites() async {
    while (_writeCount > 0) {
      _writeComplete ??= Completer<void>();
      await _writeComplete!.future;
      _writeComplete = null;
    }
  }

  /// Starts a write operation.
  void _startWrite() {
    _writeCount++;
    _writeComplete?.complete();
    _writeComplete = null;
  }

  /// Completes a write operation.
  void _finishWrite() {
    _writeCount--;
    if (_writeCount == 0) {
      _writeComplete?.complete();
      _writeComplete = null;
    }
  }

  /// Loads the value from storage asynchronously.
  Future<void> _load() async {
    _initialValueFuture ??= Future(() async {
      // Wait for all ongoing write operations to complete
      await _waitForWrites();

      final version = ++_version;
      final result = await read();
      if (_version == version && !hasInitialized) super.set(result);
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

  /// Gets the value and ensures it's loaded from storage.
  ///
  /// Returns: A Future that completes with the current value
  Future<T> getEnsured() async {
    if (!hasInitialized) await _load();

    return super.get();
  }

  /// Timer for debounced write operations.
  Timer? _timer;

  @override
  void set(T value) {
    super.set(value);
    hasInitialized = true;
    _version++;

    if (writeDelay != Duration.zero) {
      _timer?.cancel();
      _timer = Timer(writeDelay, () async {
        _startWrite();
        try {
          final result = write(value);
          if (result is Future) {
            await result;
          }
        } catch (_) {
          // ignore write error
        } finally {
          _finishWrite();
          _timer = null;
        }
      });
    } else {
      _startWrite();
      final result = write(value);
      if (result is Future) {
        // ignore write error
        result.catchError((_) {}).whenComplete(() => _finishWrite());
      } else {
        _finishWrite();
      }
    }
  }

  /// Sets a value and ensures it's written to storage before completing.
  ///
  /// Parameters:
  /// - [value]: The value to set
  /// - [optimistic]: If true, sets the signal value first, then writes to storage.
  ///   On write failure, rolls back to the previous value (faster UX but may
  ///   require rollback). If false, writes to storage first, only updates signal
  ///   on success (safer but user must wait). Defaults to false.
  ///
  /// Returns: A Future that completes with true if write succeeded, false otherwise
  Future<bool> setEnsured(T value, {bool optimistic = false}) async {
    // Wait for all ongoing write operations to complete
    await _waitForWrites();

    if (optimistic) {
      final previousValue = peek;
      final saveVersion = ++_version;
      super.set(value);
      hasInitialized = true;

      try {
        await _performWrite(value);
        return true;
      } catch (_) {
        // Rollback only if version hasn't changed (no concurrent operations)
        if (_version == saveVersion) {
          super.set(previousValue);
          _version = saveVersion - 1;
        }
        return false;
      }
    } else {
      // Non-optimistic: write first, then update
      try {
        final saveVersion = ++_version;
        await _performWrite(value);
        hasInitialized = true;
        if (_version == saveVersion) super.set(value);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _performWrite(T value) async {
    _startWrite();
    try {
      if (writeDelay != Duration.zero) {
        final completer = Completer<void>();
        _timer?.cancel();
        _timer = Timer(writeDelay, () async {
          try {
            final result = write(value);
            if (result is Future) await result;
            completer.complete();
          } catch (e) {
            completer.completeError(e);
          } finally {
            _timer = null;
          }
        });
        await completer.future;
      } else {
        final result = write(value);
        if (result is Future) await result;
      }
    } finally {
      _finishWrite();
    }
  }

  /// Function to read the value from storage.
  final FutureOr<T> Function() read;

  /// Function to write the value to storage.
  final FutureOr<void> Function(T value) write;

  /// Ensures the signal is initialized and runs the given function.
  ///
  /// Parameters:
  /// - [fn]: Optional function to run after ensuring initialization
  ///
  /// Returns: A Future that completes when the operation is done
  Future<void> ensure(FutureOr<void> Function()? fn) async {
    if (!hasInitialized) await _load();

    await fn?.call();
  }
}
