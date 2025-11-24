import 'package:flutter/widgets.dart';

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
  /// Creates a SurgeBuilder widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in callbacks. Use this when you need to access the Surge instance
  /// in your builder or buildWhen functions.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state, surge)` parameters.
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///
  /// Example:
  /// ```dart
  /// SurgeBuilder<CounterSurge, int>.full(
  ///   builder: (context, state, surge) => Text('Count: ${surge.state}'),
  ///   buildWhen: (prev, next, s) => next.isEven, // Only rebuild when even
  /// );
  /// ```
  const SurgeBuilder.full(
      {super.key, required super.builder, super.surge, super.buildWhen})
      : super.full();

  /// Creates a SurgeBuilder widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocBuilder`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The builder and buildWhen functions do not receive the Surge instance,
  /// matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state)` parameters (no Surge instance).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocBuilder)
  /// SurgeBuilder<CounterSurge, int>(
  ///   builder: (context, state) => Text('Count: $state'),
  ///   buildWhen: (prev, next) => next.isEven, // Only rebuild when even
  /// );
  /// ```
  ///
  /// See also:
  /// - [SurgeBuilder.full] for access to the Surge instance in callbacks
  factory SurgeBuilder({
    Key? key,
    required Widget Function(BuildContext context, S state) builder,
    T? surge,
    bool Function(S prevState, S newState)? buildWhen,
  }) =>
      SurgeBuilder.full(
        key: key,
        builder: (context, state, _) => builder(context, state),
        surge: surge,
        buildWhen: buildWhen != null
            ? (prevState, newState, _) => buildWhen(prevState, newState)
            : null,
      );
}
