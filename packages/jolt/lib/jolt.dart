/// Jolt - A reactive system for Dart and Flutter.
///
/// ## Documentation
///
/// [Official Documentation](https://jolt.vowdemon.com)
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:jolt/jolt.dart';
///
/// void main() {
///   // Create reactive state
///   final count = Signal(0);
///   final doubled = Computed(() => count.value * 2);
///
///   // React to changes
///   Effect(() {
///     print('Count: ${count.value}, Doubled: ${doubled.value}');
///   });
///
///   count.value = 5; // Prints: "Count: 5, Doubled: 10"
/// }
/// ```
library;

export "src/public.dart" hide ConvertComputed, PersistSignal;
