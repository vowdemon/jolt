import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../query.dart';
import '../query_client.dart';
import '../query_key.dart';
import '../query_options.dart';
import '../query_state.dart';

/// Provides access to a [QueryClient] lower in the widget tree.
class QueryClientProvider extends InheritedWidget {
  const QueryClientProvider({
    super.key,
    required this.client,
    required super.child,
  });

  final QueryClient client;

  static QueryClient of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    assert(inherited != null, 'No QueryClientProvider found in context');
    return inherited!.client;
  }

  @override
  bool updateShouldNotify(covariant QueryClientProvider oldWidget) =>
      oldWidget.client != client;
}

/// Declarative widget for consuming a query inside Flutter.
class QueryBuilder<T> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.client,
    this.enabled = true,
    this.staleTime,
    this.gcTime,
    this.initialData,
    this.placeholderData,
  });

  final QueryKey queryKey;
  final QueryFn<T> queryFn;
  final Widget Function(BuildContext context, QueryState<T> state) builder;
  final QueryClient? client;
  final bool enabled;
  final Duration? staleTime;
  final Duration? gcTime;
  final T? initialData;
  final T? placeholderData;

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  QueryClient? _client;
  Query<T>? _query;
  bool _observing = false;

  QueryClient _resolveClient(BuildContext context) {
    return widget.client ?? QueryClientProvider.of(context);
  }

  QueryOptions<T> _buildOptions(QueryClient client) {
    return QueryOptions<T>(
      queryKey: widget.queryKey,
      queryFn: widget.queryFn,
      staleTime: widget.staleTime,
      gcTime: widget.gcTime,
      enabled: widget.enabled,
      initialData: widget.initialData,
      placeholderData: widget.placeholderData,
    ).withDefaults(
      defaultStaleTime: client.defaultStaleTime,
      defaultGcTime: client.defaultGcTime,
    );
  }

  void _attachObserver(Query<T> query) {
    if (_observing && _query == query) return;
    _query?.removeObserver();
    _query = query;
    _query!.addObserver();
    _observing = true;
  }

  void _detachObserver() {
    if (_observing && _query != null) {
      _query!.removeObserver();
    }
    _observing = false;
  }

  void _setup(BuildContext context) {
    final newClient = _resolveClient(context);
    final options = _buildOptions(newClient);
    final query = newClient.ensureQuery(options);

    final clientChanged = _client != newClient;
    final keyChanged = _query?.options.queryKey != query.options.queryKey;

    if (clientChanged || keyChanged) {
      _detachObserver();
    }

    _client = newClient;
    _attachObserver(query);
  }

  @override
  void dispose() {
    _detachObserver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _setup(context);
    final query = _query!;

    return JoltBuilder(
      builder: (_) {
        final state = query.state.value;
        return widget.builder(context, state);
      },
    );
  }
}
