import 'package:jolt/src/jolt/base.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

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
      try {
        final result = disposer();
        if (result is Future) {
          result.ignore();
        }
      } catch (_) {
        // ignore dispose error
      }
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
    assert(() {
      if (target is ReadableNode) {
        return !target.isDisposed;
      }
      if (target is EffectNode) {
        return !target.isDisposed;
      }
      return true;
    }(), "Jolt value is disposed");

    var disposers = joltAttachments[target];
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
  static Set<Disposer> getJoltAttachments(Object target) =>
      joltAttachments[target] ?? {};

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
