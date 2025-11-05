import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'base.dart';
import 'effect.dart';

/// A finalizer utility for managing disposers attached to Jolt objects.
///
/// JFinalizer provides a mechanism to attach cleanup functions (disposers)
/// to objects that will be automatically executed when the object is garbage
/// collected. This is useful for managing resources that need cleanup but
/// don't have explicit disposal mechanisms.
///
/// Example:
/// ```dart
/// final signal = Signal(0);
/// final subscription = stream.listen((data) {});
///
/// JFinalizer.attachToJoltAttachments(signal, () => subscription.cancel());
/// // subscription will be cancelled when signal is garbage collected
/// ```
abstract final class JFinalizer {
  // coverage:ignore-start
  static final joltFinalizer = Finalizer<Set<Disposer>>((disposers) {
    for (final disposer in disposers) {
      disposer();
    }
  });
  // coverage:ignore-end

  static final joltAttachments = Expando<Set<Disposer>>();

  /// Attaches a disposer to a Jolt object for automatic cleanup.
  ///
  /// Parameters:
  /// - [target]: The object to attach the disposer to
  /// - [disposer]: The cleanup function to execute when the object is disposed
  ///
  /// Returns: A function that can be called to remove the disposer before disposal
  ///
  /// The disposer will be automatically executed when the target object is
  /// garbage collected or when [disposeObject] is called.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  /// final cancel = JFinalizer.attachToJoltAttachments(
  ///   signal,
  ///   () => subscription.cancel(),
  /// );
  /// // Later, if needed:
  /// cancel(); // Manually remove the disposer
  /// ```
  static Disposer attachToJoltAttachments(Object target, Disposer disposer) {
    assert(
        (target is JReadonlyValue || target is JEffect)
            ? !((target as dynamic).isDisposed)
            : true,
        'Jolt value is disposed');

    Set<Disposer>? disposers = joltAttachments[target];
    if (disposers == null) {
      joltAttachments[target] = disposers = {};
      joltFinalizer.attach(target, disposers);
    }

    disposers.add(disposer);
    return () {
      disposers!.remove(disposer);
    };
  }

  /// Detaches a disposer from a Jolt object.
  ///
  /// Parameters:
  /// - [target]: The object to detach the disposer from
  /// - [disposer]: The cleanup function to remove
  ///
  /// This method removes the disposer from the target object's attachment list.
  /// The disposer will no longer be executed when the object is disposed.
  ///
  /// Example:
  /// ```dart
  /// final cancel = JFinalizer.attachToJoltAttachments(signal, disposer);
  /// // Later:
  /// JFinalizer.detachFromJoltAttachments(signal, disposer);
  /// // Or simply:
  /// cancel();
  /// ```
  static void detachFromJoltAttachments(Object target, Disposer disposer) {
    final disposers = joltAttachments[target];
    if (disposers != null) {
      disposers.remove(disposer);
    }
  }

  /// Gets all disposers attached to the given object.
  ///
  /// Parameters:
  /// - [target]: The object to get disposers for
  ///
  /// Returns: A set of all disposers attached to the object, or an empty set if none
  ///
  /// This method is primarily intended for testing purposes.
  ///
  /// Example:
  /// ```dart
  /// final disposers = JFinalizer.getJoltAttachments(signal);
  /// expect(disposers.length, equals(1));
  /// ```
  @visibleForTesting
  static Set<Disposer> getJoltAttachments(Object target) {
    return joltAttachments[target] ?? {};
  }

  /// Disposes an object and executes all attached disposers.
  ///
  /// Parameters:
  /// - [target]: The object to dispose
  ///
  /// This method executes all disposers attached to the target object and
  /// removes them from the attachment list. After calling this method,
  /// the object's attachments are cleared.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  /// JFinalizer.attachToJoltAttachments(signal, () => subscription.cancel());
  ///
  /// // Later, manually dispose:
  /// JFinalizer.disposeObject(signal);
  /// // subscription.cancel() will be called
  /// ```
  static void disposeObject(Object target) {
    final originalDisposers = joltAttachments[target];
    if (originalDisposers == null) return;
    joltAttachments[target] = null;

    final disposers = {...originalDisposers};

    for (final disposer in disposers) {
      disposer();
    }
    joltFinalizer.detach(originalDisposers);
    disposers.clear();
  }
}

final streamHolders = Expando<StreamHolder<Object?>>();

/// Internal class for holding stream controller and watcher for reactive values.
///
/// StreamHolder manages the lifecycle of a broadcast stream controller and
/// its associated watcher for converting reactive values to streams.
@internal
class StreamHolder<T> implements Disposable {
  /// Creates a stream holder with the given callbacks.
  ///
  /// Parameters:
  /// - [onListen]: Optional callback called when the stream is first listened to
  /// - [onCancel]: Optional callback called when the stream subscription is cancelled
  ///
  /// This constructor creates a broadcast stream controller that will be used
  /// to emit values from reactive values to stream subscribers.
  StreamHolder({
    void Function()? onListen,
    void Function()? onCancel,
  }) : sc = StreamController<T>.broadcast(
          onListen: onListen,
          onCancel: onCancel,
        );

  /// The broadcast stream controller for this holder.
  ///
  /// This controller is used to emit values to stream subscribers.
  final StreamController<T> sc;

  /// The watcher that monitors the reactive value for changes.
  ///
  /// This watcher is set when the stream is first listened to and is used
  /// to track changes in the reactive value and emit them to stream subscribers.
  Watcher? watcher;

  /// The broadcast stream that emits values when the reactive value changes.
  ///
  /// Returns: A broadcast stream that can be listened to by multiple subscribers
  Stream<T> get stream => sc.stream;

  /// The sink for adding values to the stream.
  ///
  /// Returns: A stream sink that can be used to manually add values to the stream
  StreamSink<T> get sink => sc.sink;

  /// Sets the watcher that monitors the reactive value for changes.
  ///
  /// Parameters:
  /// - [watcher]: The watcher to set
  ///
  /// This method is called when the stream is first listened to to set up
  /// automatic value emission when the reactive value changes.
  void setWatcher(Watcher watcher) {
    this.watcher = watcher;
  }

  /// Clears the watcher and disposes it.
  ///
  /// This method disposes the current watcher (if any) and sets it to null.
  /// This is typically called when the stream subscription is cancelled.
  void clearWatcher() {
    watcher?.dispose();
    watcher = null;
  }

  /// Disposes this stream holder and cleans up resources.
  ///
  /// This method clears the watcher and closes the stream controller,
  /// preventing further values from being emitted.
  @override
  void dispose() {
    clearWatcher();
    sc.close();
  }
}

/// Gets the stream holder for the given reactive value.
///
/// Parameters:
/// - [value]: The reactive value to get the stream holder for
///
/// Returns: The stream holder for the value, or null if no stream holder exists
///
/// This function is primarily intended for internal use and testing purposes.
/// It retrieves the stream holder that manages the stream conversion for a
/// reactive value.
///
/// Example:
/// ```dart
/// final signal = Signal(0);
/// final stream = signal.stream; // Creates a stream holder
/// final holder = getStreamHolder(signal);
/// expect(holder, isNotNull);
/// ```
@internal
@visibleForTesting
StreamHolder<T>? getStreamHolder<T>(JReadonlyValue<T> value) {
  return streamHolders[value] as StreamHolder<T>?;
}
