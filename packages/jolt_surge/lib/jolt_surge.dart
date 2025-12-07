/// A lightweight state management library for Flutter based on Jolt Signals.
///
/// Jolt Surge is inspired by the [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit)
/// pattern from the [BLoC](https://bloclibrary.dev/) library. It provides a
/// signal-based state management solution that combines Jolt's reactive signal
/// system with Flutter's state management capabilities.
///
/// ## Documentation
///
/// [Official Documentation](https://jolt.vowdemon.com)
///
/// **Main Components:**
/// - [Surge]: The state container class that manages state reactively
/// - [SurgeProvider]: Provides Surge instances to the widget tree
/// - [SurgeConsumer]: Unified widget for both building UI and handling side effects
/// - [SurgeBuilder]: Convenient widget for building UI based on state
/// - [SurgeListener]: Convenient widget for handling side effects only
/// - [SurgeSelector]: Fine-grained rebuild control using selector functions
///
/// **Example:**
/// ```dart
/// import 'package:jolt_surge/jolt_surge.dart';
///
/// // Create a Surge
/// class CounterSurge extends Surge<int> {
///   CounterSurge() : super(0);
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
/// }
///
/// // Use in Flutter
/// SurgeProvider<CounterSurge>(
///   create: (_) => CounterSurge(),
///   child: SurgeBuilder<CounterSurge, int>(
///     builder: (context, state, surge) => Text('Count: $state'),
///   ),
/// );
/// ```
///
/// This design maintains the predictability and simplicity of the Cubit pattern
/// while leveraging the reactive capabilities of Jolt Signals, enabling you to
/// build efficient and maintainable state management solutions in Flutter.
library;

export 'src/surge.dart';

export 'src/widgets/surge_provider.dart';
export 'src/widgets/surge_consumer.dart';
export 'src/widgets/surge_builder.dart';
export 'src/widgets/surge_listener.dart';
export 'src/widgets/surge_selector.dart';
