import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show JoltWatcher, Signal;

import '../query/client.dart';
import '../query/observer.dart';
import '../query/observer_result.dart';
import '../query/recipe.dart';

/// Builds a widget from the client-owned observer for [QueryWidget.query].
///
/// The observer is borrowed for the duration of the callback. [QueryWidget]
/// owns it and disposes it when the widget is removed or moves to another
/// query client.
typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryObserver<T> observer,
);

/// Observes one client-bound query target for a Flutter subtree.
///
/// Query updates that keep the same client retarget one stable observer.
/// Moving to a target owned by another client disposes the old observer and
/// creates a new one. The widget never owns or disposes either client.
///
/// The complete [QueryObserver.value] is observed, so every visible result
/// transition rebuilds [builder]. The builder itself is not an implicit
/// reactive scope for unrelated Jolt values.
final class QueryWidget<T> extends StatefulWidget {
  /// Creates a widget for one client-bound [query].
  const QueryWidget({
    super.key,
    required this.query,
    required this.builder,
  });

  /// The current query target and the client that owns its observation.
  final QueryTarget<T> query;

  /// Builds from the borrowed current observer.
  final QueryWidgetBuilder<T> builder;

  @override
  State<QueryWidget<T>> createState() => _QueryWidgetState<T>();
}

final class _QueryWidgetState<T> extends State<QueryWidget<T>> {
  late final Signal<QueryTarget<T>> _query;
  late QueryClient _client;
  late QueryObserver<T> _observer;

  @override
  void initState() {
    super.initState();
    _query = Signal<QueryTarget<T>>(widget.query);
    _client = widget.query.client;
    _observer = _createObserver();
  }

  QueryObserver<T> _createObserver() {
    return _client.watchQuery(() => _query.value);
  }

  @override
  void didUpdateWidget(covariant QueryWidget<T> oldWidget) {
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
    return JoltWatcher<QueryObserverResult<T>>(
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
