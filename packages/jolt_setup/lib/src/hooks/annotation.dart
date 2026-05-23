import 'package:meta/meta_meta.dart';

import 'package:jolt_setup/jolt_setup.dart';

/// Annotation that marks a function, method, or constant as a setup hook.
///
/// Tooling can use this annotation to recognize APIs that must be called while
/// a [SetupContext] is active.
@Target({TargetKind.function, TargetKind.method, TargetKind.topLevelVariable})
class DefineHook {
  /// Creates a hook marker annotation.
  const DefineHook();
}

/// The shared [DefineHook] annotation instance.
const defineHook = DefineHook();
