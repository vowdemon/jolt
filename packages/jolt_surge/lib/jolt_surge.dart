/// Signal-based state management for Flutter inspired by Cubit.
///
/// Provides imperative state containers and provider/builder widgets for wiring
/// surge state into the widget tree.
///
/// ```dart
/// class CounterSurge extends Surge<int> {
///   CounterSurge() : super(0);
///
///   void increment() => emit(state + 1);
/// }
///
/// SurgeProvider<CounterSurge>(
///   create: (_) => CounterSurge(),
///   child: SurgeBuilder<CounterSurge, int>(
///     builder: (context, state, surge) => Text('Count: $state'),
///   ),
/// );
/// ```
library;

export 'src/surge.dart';

export 'src/widgets/surge_provider.dart';
export 'src/widgets/surge_consumer.dart';
export 'src/widgets/surge_builder.dart';
export 'src/widgets/surge_listener.dart';
export 'src/widgets/surge_selector.dart';
export 'src/observer.dart';
export 'src/shared.dart';
