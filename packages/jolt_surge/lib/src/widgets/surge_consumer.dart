import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../surge.dart';
import 'surge_listener.dart';
import 'surge_builder.dart';

/// Combines [SurgeBuilder] and [SurgeListener] in one widget.
///
/// Use [builder] for UI, [listener] for side effects, and [buildWhen] /
/// [listenWhen] to filter each channel independently. When [surge] is omitted,
/// the nearest [SurgeProvider] is used.
///
/// ```dart
/// SurgeConsumer<CounterSurge, int>(
///   buildWhen: (previous, current, _) => current.isEven,
///   listenWhen: (previous, current, _) => current > previous,
///   builder: (context, state, surge) => Text('Count: $state'),
///   listener: (context, state, surge) {
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Count is now: $state')),
///     );
///   },
/// );
/// ```
///
/// See also: [SurgeBuilder], [SurgeListener], and [SurgeSelector].
class SurgeConsumer<T extends Surge<S>, S> extends StatelessWidget {
  /// Creates a consumer that receives the [Surge] instance in callbacks.
  ///
  /// [buildWhen] and [listenWhen] are tracked by default unless wrapped in
  /// [untracked].
  const SurgeConsumer.full({
    super.key,
    required this.builder,
    this.listener,
    this.buildWhen,
    this.listenWhen,
    this.surge,
  });

  /// Creates a Cubit-style consumer without exposing the [Surge] in callbacks.
  ///
  /// See [SurgeConsumer.full] when callbacks need the surge instance.
  factory SurgeConsumer({
    Key? key,
    required Widget Function(BuildContext context, S state) builder,
    void Function(BuildContext context, S state)? listener,
    T? surge,
    bool Function(S prevState, S newState)? buildWhen,
    bool Function(S prevState, S newState)? listenWhen,
  }) =>
      SurgeConsumer.full(
        key: key,
        builder: (context, state, _) => builder(context, state),
        listener: listener != null
            ? (context, state, _) => listener(context, state)
            : null,
        surge: surge,
        buildWhen: buildWhen != null
            ? (prevState, newState, _) => buildWhen(prevState, newState)
            : null,
        listenWhen: listenWhen != null
            ? (prevState, newState, _) => listenWhen(prevState, newState)
            : null,
      );

  /// Builds UI from the current [state] and [surge].
  final Widget Function(BuildContext context, S state, T surge) builder;

  /// Runs side effects in an [untracked] context when [listenWhen] allows it.
  final void Function(BuildContext context, S state, T surge)? listener;

  /// Whether to rebuild for a given state transition.
  final bool Function(S prevState, S newState, T surge)? buildWhen;

  /// Whether to run [listener] for a given state transition.
  final bool Function(S prevState, S newState, T surge)? listenWhen;

  /// The surge to observe, or `null` to read from [SurgeProvider].
  final T? surge;

  @override
  Widget build(BuildContext context) {
    return SurgeListener.full(
      listener: listener,
      listenWhen: listenWhen,
      surge: surge,
      child: SurgeBuilder.full(
          builder: builder, buildWhen: buildWhen, surge: surge),
    );
  }
}
