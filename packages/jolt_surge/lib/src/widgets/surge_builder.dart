import '../surge.dart';
import 'surge_consumer.dart';

/// A convenience widget that builds UI based on Surge state changes.
///
/// SurgeBuilder is a simplified version of [SurgeConsumer] that only provides
/// the `builder` functionality. It automatically rebuilds the widget when the
/// Surge state changes, with optional conditional rebuilding control.
///
/// Example:
/// ```dart
/// SurgeBuilder<CounterSurge, int>(
///   builder: (context, state, surge) => Text('count: $state'),
///   buildWhen: (prev, next, s) => next.isEven, // Optional: only rebuild when even
/// );
/// ```
///
/// See also:
/// - [SurgeConsumer] for both builder and listener functionality
/// - [SurgeListener] for listener-only functionality
/// - [SurgeSelector] for fine-grained rebuild control with selector
class SurgeBuilder<T extends Surge<S>, S> extends SurgeConsumer<T, S> {
  /// Creates a SurgeBuilder widget.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///
  /// The builder function receives the context, current state, and Surge instance.
  /// It is called whenever the state changes (and buildWhen returns true).
  ///
  /// Example:
  /// ```dart
  /// SurgeBuilder<CounterSurge, int>(
  ///   builder: (context, state, surge) => Text('Count: $state'),
  ///   buildWhen: (prev, next, s) => next.isEven, // Only rebuild when even
  /// );
  /// ```
  const SurgeBuilder(
      {super.key, required super.builder, super.surge, super.buildWhen});
}
