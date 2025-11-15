/// Core reactive system APIs for advanced usage.
///
/// This library exposes the low-level reactive system APIs including
/// reactive nodes, dependency tracking, and the global reactive system.
/// These APIs are typically used by framework implementers or for
/// advanced reactive programming scenarios.
///
/// ## Usage
///
/// ```dart
/// import 'package:jolt/core.dart';
///
/// // Manually trigger propagation algorithm
/// flush(); // Execute all queued effects
///
/// // Work with reactive nodes directly
/// final node = ReactiveNode(flags: ReactiveFlags.mutable);
/// link(dependency, subscriber, version);
/// ```
library;

export "src/core/debug.dart" show JoltDebug, JoltDebugFn;
export "src/core/reactive.dart";
export "src/jolt/shared.dart" show JFinalizer;
