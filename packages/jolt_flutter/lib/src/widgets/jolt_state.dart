import 'package:flutter/widgets.dart';

/// Interface for objects that need lifecycle management in [JoltResource].
///
/// Classes implementing [JoltState] can receive mount and unmount notifications
/// when used with [JoltResource], allowing for proper resource management
/// and cleanup.
///
/// ## Example
///
/// ```dart
/// class MyStore implements Jolt {
///   final counter = Signal(0);
///   Timer? _timer;
///
///   @override
///   void onMount(BuildContext context) {
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       counter.value++;
///     });
///   }
///
///   @override
///   void onUnmount(BuildContext context) {
///     _timer?.cancel();
///   }
/// }
/// ```
abstract interface class JoltState {
  JoltState(this.context);

  final BuildContext context;

  /// Called when the resource is mounted to the widget tree.
  ///
  /// Use this method to initialize resources, start timers, or set up
  /// subscriptions that should be active while the widget is mounted.
  void onMount();

  /// Called when the resource is unmounted from the widget tree.
  ///
  /// Use this method to clean up resources, cancel timers, or dispose
  /// of subscriptions to prevent memory leaks.
  void onUnmount();
}
