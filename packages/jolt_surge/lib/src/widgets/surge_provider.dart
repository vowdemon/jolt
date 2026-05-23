import 'package:provider/provider.dart';

import '../surge.dart';

/// A widget that provides a Surge instance to the widget tree.
///
/// SurgeProvider is used to provide a Surge instance to descendant widgets,
/// similar to how `Provider` works. It supports two constructors: `create`
/// and `.value`.
///
/// **Using `create` constructor:**
/// The Surge lifecycle is automatically managed. When the widget is disposed,
/// `surge.dispose()` is automatically called.
///
/// **Using `.value` constructor:**
/// The Surge lifecycle needs to be manually managed. The Surge won't be
/// automatically disposed when the widget is removed.
///
/// ```dart
/// // Using create constructor (automatic lifecycle management)
/// SurgeProvider<CounterSurge>(
///   create: (_) => CounterSurge(), // Automatically disposed on unmount
///   child: SurgeBuilder<CounterSurge, int>(
///     builder: (context, state, surge) => Text('count: $state'),
///   ),
/// );
///
/// // Using .value constructor (manual lifecycle management)
/// final surge = CounterSurge();
///
/// SurgeProvider<CounterSurge>.value(
///   value: surge, // Won't be automatically disposed
///   child: SurgeBuilder<CounterSurge, int>(
///     builder: (context, state, s) => Text('count: $state'),
///   ),
/// );
/// ```
///
/// **Accessing from descendant widgets:**
/// ```dart
/// // Get Surge instance
/// final surge = context.read<CounterSurge>();
///
/// // Trigger state changes
/// ElevatedButton(
///   onPressed: () => surge.increment(),
///   child: const Text('Increment'),
/// );
/// ```
class SurgeProvider<T extends Surge<dynamic>> extends InheritedProvider<T> {
  /// Creates a surge and disposes it when this provider unmounts.
  SurgeProvider({
    super.key,
    required Create<T> create,
    bool lazy = true,
    super.child,
  }) : super(
          create: create,
          dispose: (_, surge) => surge.dispose(),
          lazy: lazy,
        );

  /// Provides an existing surge without disposing it on unmount.
  SurgeProvider.value({
    super.key,
    required super.value,
    bool super.lazy = true,
    super.child,
  }) : super.value();
}

/// Provides multiple [Surge] instances without nesting [SurgeProvider] widgets.
class MultiSurgeProvider extends MultiProvider {
  /// Creates a provider tree from [providers].
  MultiSurgeProvider({
    super.key,
    required List<SurgeProvider> providers,
    required super.child,
  }) : super(providers: providers);
}
