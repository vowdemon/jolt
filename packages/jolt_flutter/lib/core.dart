/// Re-exports the core Jolt reactive system for Flutter integration.
///
/// This file provides access to the fundamental Jolt reactive primitives
/// including effects, batching, and the reactive system core. These are
/// the building blocks that power the Flutter-specific widgets and signals.
///
/// ## Core Features
///
/// - Effect system for reactive side effects
/// - Batch operations for performance optimization
/// - Reactive system lifecycle management
/// - Signal dependency tracking
///
/// ## Example
///
/// ```dart
/// import 'package:jolt_flutter/core.dart';
///
/// final counter = Signal(0);
///
/// // Create an effect that runs when counter changes
/// Effect(() {
///   print('Counter is now: ${counter.value}');
/// });
///
/// // Batch multiple updates for better performance
/// batch(() {
///   counter.value = 1;
///   counter.value = 2;
///   counter.value = 3;
/// }); // Effect only runs once with final value
/// ```
library;

export 'package:jolt/core.dart';
