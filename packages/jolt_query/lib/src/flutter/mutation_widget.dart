import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show JoltWatcher;

import '../mutation/client_extension.dart';
import '../mutation/observer_result.dart';
import '../mutation/recipe.dart';
import '../query/client.dart';

/// Builds a widget from the observer owned by a [MutationWidget].
///
/// The observer is borrowed for the duration of the callback. The widget owns
/// and disposes it; the selected query client remains application-owned.
typedef MutationWidgetBuilder<V, D, R> = Widget Function(
  BuildContext context,
  MutationObserver<V, D, R> observer,
);

/// Presents a mutation's latest explicit submission in a Flutter subtree.
///
/// Mounting this widget never executes [mutation]. Rebuilding with the same
/// client updates the retained observer's recipe; equal nullable mutation keys
/// preserve presentation, while a changed key resets it to idle.
final class MutationWidget<V, D, R> extends StatefulWidget {
  /// Creates a mutation observer widget.
  const MutationWidget({
    super.key,
    this.client,
    required this.mutation,
    required this.builder,
  });

  /// The client that owns submitted mutations.
  ///
  /// When omitted, [QueryClient.defaultClient] is resolved at mount.
  final QueryClient? client;

  /// The recipe used by future explicit observer submissions.
  final Mutation<V, D, R> mutation;

  /// Builds from the borrowed current observer.
  final MutationWidgetBuilder<V, D, R> builder;

  @override
  State<MutationWidget<V, D, R>> createState() =>
      _MutationWidgetState<V, D, R>();
}

final class _MutationWidgetState<V, D, R>
    extends State<MutationWidget<V, D, R>> {
  late QueryClient _client;
  late MutationObserver<V, D, R> _observer;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? QueryClient.defaultClient;
    _observer = _client.observeMutation(widget.mutation);
  }

  @override
  void didUpdateWidget(covariant MutationWidget<V, D, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextClient = widget.client ?? QueryClient.defaultClient;
    if (identical(_client, nextClient)) {
      _observer.updateMutation(widget.mutation);
      return;
    }

    _observer.dispose();
    _client = nextClient;
    _observer = _client.observeMutation(widget.mutation);
  }

  @override
  Widget build(BuildContext context) {
    return JoltWatcher<MutationObserverResult<V, D, R>>(
      key: ObjectKey(_observer),
      readable: _observer,
      builder: (context, _) => widget.builder(context, _observer),
    );
  }

  @override
  void dispose() {
    _observer.dispose();
    super.dispose();
  }
}
