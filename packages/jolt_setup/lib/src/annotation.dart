import 'package:meta/meta_meta.dart';

/// Annotation used to mark hook functions.
///
/// This annotation is used by the lint rule to identify hook functions
/// and validate their usage. Functions marked with this annotation must
/// be called within the proper context (e.g., inside a SetupWidget's
/// setup function).
///
/// Example:
/// ```dart
/// @defineHook
/// Signal<T> useSignal<T>(T value) {
///   return useAutoDispose(() => Signal(value));
/// }
/// ```
@Target({TargetKind.function, TargetKind.method, TargetKind.topLevelVariable})
class DefineHook {
  const DefineHook();
}

/// Constant instance of [DefineHook] annotation.
///
/// Use this constant to annotate hook functions:
/// ```dart
/// @defineHook
/// void myHook() { ... }
/// ```
const defineHook = DefineHook();
