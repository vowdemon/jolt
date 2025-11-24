import 'package:flutter/widgets.dart';

import '../surge.dart';
import 'surge_consumer.dart';

/// A convenience widget that listens to Surge state changes for side effects.
///
/// SurgeListener is a simplified version of [SurgeConsumer] that only provides
/// the `listener` functionality. It's designed for handling side effects like
/// showing SnackBars, sending analytics events, or navigating without rebuilding UI.
///
/// Unlike [SurgeBuilder], this widget doesn't rebuild its child. It simply
/// passes through the child widget and executes the listener when state changes.
///
/// Example:
/// ```dart
/// SurgeListener<CounterSurge, int>(
///   listenWhen: (prev, next, s) => next > prev, // Only listen when increasing
///   listener: (context, state, surge) {
///     // Only handle side effects, doesn't build UI
///     print('Count increased to: $state');
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Count is now: $state')),
///     );
///   },
///   child: const SizedBox.shrink(),
/// );
/// ```
///
/// See also:
/// - [SurgeConsumer] for both builder and listener functionality
/// - [SurgeBuilder] for builder-only functionality
/// - [SurgeSelector] for fine-grained rebuild control with selector
class SurgeListener<T extends Surge<S>, S> extends SurgeConsumer<T, S> {
  /// Creates a SurgeListener widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in callbacks. Use this when you need to access the Surge instance
  /// in your listener or listenWhen functions.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [child]: The child widget to display (not rebuilt)
  /// - [listener]: The listener function for handling side effects.
  ///   Receives `(context, state, surge)` parameters.
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to execute, false to skip. Defaults to always executing.
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  ///
  /// The listener function is called whenever the state changes and [listenWhen]
  /// returns true. It is executed within an [untracked] context to avoid creating
  /// reactive dependencies.
  ///
  /// Example:
  /// ```dart
  /// SurgeListener<CounterSurge, int>.full(
  ///   listenWhen: (prev, next, s) => next > prev, // Only when increasing
  ///   listener: (context, state, surge) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text('Count increased to: $state')),
  ///     );
  ///   },
  ///   child: const SizedBox.shrink(),
  /// );
  /// ```
  SurgeListener.full(
      {super.key,
      required Widget child,
      required super.listener,
      super.listenWhen,
      super.surge})
      : super.full(builder: (context, _, __) => child);

  /// Creates a SurgeListener widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocListener`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The listener and listenWhen functions do not receive the Surge instance,
  /// matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [child]: The child widget to display (not rebuilt)
  /// - [listener]: The listener function for handling side effects.
  ///   Receives `(context, state)` parameters (no Surge instance).
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to execute, false to skip. Defaults to always executing.
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  ///
  /// The listener function is called whenever the state changes and [listenWhen]
  /// returns true. It is executed within an [untracked] context to avoid creating
  /// reactive dependencies.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocListener)
  /// SurgeListener<CounterSurge, int>(
  ///   listenWhen: (prev, next) => next > prev, // Only when increasing
  ///   listener: (context, state) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text('Count increased to: $state')),
  ///     );
  ///   },
  ///   child: const SizedBox.shrink(),
  /// );
  /// ```
  ///
  /// See also:
  /// - [SurgeListener.full] for access to the Surge instance in callbacks
  factory SurgeListener({
    Key? key,
    required Widget child,
    required void Function(BuildContext context, S state) listener,
    bool Function(S prevState, S newState)? listenWhen,
    T? surge,
  }) =>
      SurgeListener.full(
        key: key,
        listener: (context, state, _) => listener(context, state),
        listenWhen: listenWhen != null
            ? (prevState, newState, _) => listenWhen(prevState, newState)
            : null,
        surge: surge,
        child: child,
      );
}
