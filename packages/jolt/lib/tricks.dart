/// Useful features built on top of Jolt.
///
/// This library provides commonly used utilities and extensions that
/// enhance the core Jolt reactive system with practical functionality.
///
/// ## Features
///
/// - **ConvertComputed**: Type-converting computed signals
/// - **PersistSignal**: Signals that automatically persist to storage
///
/// ## Usage
///
/// ```dart
/// import 'package:jolt/tricks.dart';
///
/// // Type-converting signal
/// final count = Signal(0);
/// final textCount = ConvertComputed(
///   count,
///   decode: (int value) => value.toString(),
///   encode: (String value) => int.parse(value),
/// );
///
/// // Persistent signal
/// final theme = PersistSignal(
///   read: () => SharedPreferences.getInstance()
///     .then((prefs) => prefs.getString('theme') ?? 'light'),
///   write: (value) => SharedPreferences.getInstance()
///     .then((prefs) => prefs.setString('theme', value)),
/// );
/// ```
library;

export "src/tricks/convert_computed.dart";
export "src/tricks/persist_signal.dart";
