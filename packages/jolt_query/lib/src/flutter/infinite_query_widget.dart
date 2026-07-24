import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show JoltWatcher, Signal;

import '../infinite/client.dart';
import '../infinite/observer_result.dart';
import '../infinite/recipe.dart';
import '../query/client.dart';

/// Builds a widget from the observer owned by an [InfiniteQueryWidget].
///
/// The observer is borrowed for the duration of the callback. The widget owns
/// and disposes it; the query client remains application-owned.
typedef InfiniteQueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  InfiniteQueryObserver<T> observer,
);

/// Observes one client-bound infinite-query target for a Flutter subtree.
///
/// Targets that resolve to the same client retarget one stable observer.
/// Moving to another client disposes the old observer and creates a new one in
/// that client's cache universe.
final class InfiniteQueryWidget<T> extends StatefulWidget {
  /// Creates a widget for one client-bound infinite [query].
  const InfiniteQueryWidget({
    super.key,
    required this.query,
    required this.builder,
  });

  /// The current infinite-query target and its observation client.
  final InfiniteQueryTarget<T> query;

  /// Builds from the borrowed current observer.
  final InfiniteQueryWidgetBuilder<T> builder;

  @override
  State<InfiniteQueryWidget<T>> createState() => _InfiniteQueryWidgetState<T>();
}

final class _InfiniteQueryWidgetState<T> extends State<InfiniteQueryWidget<T>> {
  late final Signal<InfiniteQueryTarget<T>> _query;
  late QueryClient _client;
  late InfiniteQueryObserver<T> _observer;

  @override
  void initState() {
    super.initState();
    _query = Signal<InfiniteQueryTarget<T>>(widget.query);
    _client = widget.query.client;
    _observer = _createObserver();
  }

  InfiniteQueryObserver<T> _createObserver() {
    return _client.watchInfiniteQuery(() => _query.value);
  }

  @override
  void didUpdateWidget(covariant InfiniteQueryWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextClient = widget.query.client;
    if (identical(_client, nextClient)) {
      _query.value = widget.query;
      return;
    }

    _observer.dispose();
    _client = nextClient;
    _query.value = widget.query;
    _observer = _createObserver();
  }

  @override
  Widget build(BuildContext context) {
    return JoltWatcher<InfiniteQueryObserverResult<T>>(
      key: ObjectKey(_observer),
      readable: _observer,
      builder: (context, _) => widget.builder(context, _observer),
    );
  }

  @override
  void dispose() {
    _observer.dispose();
    _query.dispose();
    super.dispose();
  }
}
