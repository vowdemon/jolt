import 'package:flutter/widgets.dart';

/// Base class for objects that need lifecycle management in [JoltProvider].
///
/// Classes extending [JoltState] receive mount and unmount notifications
/// when used with [JoltProvider], allowing for proper resource management
/// and cleanup. Both callbacks have default empty implementations, so you
/// only need to override the ones you need.
///
/// ## Lifecycle
///
/// - [onMount] is called after the resource is created and the widget is mounted
/// - [onUnmount] is called when the widget is unmounted or when a new resource
///   is created to replace this one
///
/// ## Example
///
/// ```dart
/// class MyStore extends JoltState {
///   final counter = Signal(0);
///   Timer? _timer;
///
///   @override
///   void onMount(BuildContext context) {
///     super.onMount(context);
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       counter.value++;
///     });
///   }
///
///   @override
///   void onUnmount(BuildContext context) {
///     super.onUnmount(context);
///     _timer?.cancel();
///     _timer = null;
///   }
/// }
/// ```
///
/// Resources that don't need lifecycle management don't need to extend [JoltState]:
///
/// ```dart
/// class SimpleStore {
///   final counter = Signal(0);
/// }
/// ```
abstract class JoltState {
  /// Called when the resource is mounted to the widget tree.
  ///
  /// This method is invoked after the resource is created and the [JoltProvider]
  /// widget is mounted. Use this to:
  /// - Initialize resources (timers, subscriptions, etc.)
  /// - Start background processes
  /// - Set up listeners or observers
  ///
  /// The [context] parameter provides access to the widget tree context.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// void onMount(BuildContext context) {
  ///   super.onMount(context);
  ///   _subscription = someStream.listen(_handleEvent);
  /// }
  /// ```
  void onMount(BuildContext context) {}

  /// Called when the resource is unmounted from the widget tree.
  ///
  /// This method is invoked when:
  /// - The [JoltProvider] widget is unmounted
  /// - A new resource is created to replace this one (in [update])
  ///
  /// Use this to:
  /// - Clean up resources (cancel timers, dispose subscriptions, etc.)
  /// - Stop background processes
  /// - Remove listeners or observers
  ///
  /// The [context] parameter provides access to the widget tree context.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// void onUnmount(BuildContext context) {
  ///   super.onUnmount(context);
  ///   _subscription?.cancel();
  ///   _timer?.cancel();
  /// }
  /// ```
  void onUnmount(BuildContext context) {}
}
