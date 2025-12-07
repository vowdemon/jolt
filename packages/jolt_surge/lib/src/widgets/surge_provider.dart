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
/// Example:
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
  /// Creates a SurgeProvider with automatic lifecycle management.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [create]: Function that creates the Surge instance
  /// - [lazy]: Whether to create the Surge lazily (on first access).
  ///   Defaults to true
  /// - [child]: The child widget tree
  ///
  /// The Surge instance will be automatically disposed when this widget
  /// is removed from the tree.
  ///
  /// Example:
  /// ```dart
  /// SurgeProvider<CounterSurge>(
  ///   create: (_) => CounterSurge(),
  ///   lazy: true, // Create on first access
  ///   child: MyApp(),
  /// );
  /// ```
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

  /// Creates a SurgeProvider with manual lifecycle management.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [value]: The Surge instance to provide
  /// - [lazy]: Whether to provide the Surge lazily (on first access).
  ///   Defaults to true
  /// - [child]: The child widget tree
  ///
  /// The Surge instance will NOT be automatically disposed when this widget
  /// is removed from the tree. You must manually call `dispose()` on the Surge.
  ///
  /// Use this constructor when you need to share a Surge instance across
  /// multiple widget trees or manage its lifecycle manually.
  ///
  /// Example:
  /// ```dart
  /// final surge = CounterSurge();
  ///
  /// SurgeProvider<CounterSurge>.value(
  ///   value: surge,
  ///   child: MyApp(),
  /// );
  ///
  /// // Later, manually dispose:
  /// surge.dispose();
  /// ```
  SurgeProvider.value({
    super.key,
    required super.value,
    bool super.lazy = true,
    super.child,
  }) : super.value();
}

/// {@template surge_multiple_provider}
/// A convenience widget that provides multiple Surge instances to the widget tree.
///
/// MultiSurgeProvider is a utility widget that combines multiple [SurgeProvider]
/// widgets into a single widget, making it easier to provide multiple Surge instances
/// without deeply nesting providers.
///
/// See also:
/// - [SurgeProvider] for providing a single Surge instance
/// {@endtemplate}
class MultiSurgeProvider extends MultiProvider {
  /// {@macro surge_multiple_provider}
  MultiSurgeProvider({
    super.key,
    required List<SurgeProvider> providers,
    required super.child,
  }) : super(providers: providers);
}
