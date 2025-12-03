/// Re-exports the core Jolt reactive system for Flutter integration.
///
/// This file provides access to the fundamental Jolt reactive primitives
/// including effects, batching, and the reactive system core. These are
/// the building blocks that power the Flutter-specific widgets and signals.
library;

export 'package:jolt/core.dart';
export 'package:jolt_flutter/src/effect/flutter_effect.dart'
    show FlutterEffectImpl;
