import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart' as reactive;
import 'package:jolt/jolt.dart' as jolt;
import 'package:shared_interfaces/shared_interfaces.dart';

import '../shared.dart';
import 'jolt_state.dart';

/// A widget that provides reactive resource management with lifecycle callbacks.
///
/// [JoltProvider] allows you to create and manage resources that can implement the
/// [JoltState] interface, providing automatic lifecycle management with [onMount]
/// and [onUnmount] callbacks.
///
/// The provided resource is accessible both directly via the [builder] function's
/// parameter and through [BuildContext] using [of] or [maybeOf] static methods.
/// This makes it easy to access resources from descendant widgets without prop drilling.
///
/// ## Resource Provision
///
/// Resources can be provided in two ways:
/// - **Using [create]**: A function that creates the resource when the widget mounts.
///   The provider manages the resource's lifecycle and will call [onUnmount] and
///   dispose the resource when it's no longer needed.
/// - **Using [value]**: A pre-existing resource instance. When using [value], the
///   provider does not manage the resource's lifecycle (no [onUnmount] or dispose
///   is called by the provider). The resource should be managed externally.
///
/// You must provide either [create] or [value], but not both.
///
/// ## Lifecycle Management
///
/// When using [create], if the resource implements [JoltState], lifecycle callbacks
/// are automatically invoked:
/// - [onMount] is called after the resource is created and the widget is mounted
/// - [onUnmount] is called when the widget is unmounted or when a new resource
///   replaces the old one
///
/// When using [value], the provider does not manage the resource's lifecycle at all:
/// - No [onMount] is called
/// - No [onUnmount] is called
/// - The resource is not disposed by the provider
/// The resource should be managed externally.
///
/// ## Resource Updates
///
/// When the [create] function changes, the provider checks if a new resource should
/// be created. If the new resource is identical to the old one (e.g., const instances),
/// no recreation occurs. Otherwise, the old resource's [onUnmount] is called (if it
/// was created via [create]), and the new resource's [onMount] is called (if it was
/// created via [create]).
///
/// When the [value] changes, the provider simply updates the provided resource without
/// calling lifecycle callbacks or disposing the old resource.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree using the provided resource.
///   The resource is passed as the second parameter and is also accessible via
///   [JoltProvider.of] or [JoltProvider.maybeOf] in descendant widgets.
/// - [create]: Optional function to create the resource when the widget mounts.
///   If provided, the provider manages the resource's lifecycle. Cannot be used
///   together with [value].
/// - [value]: Optional pre-existing resource instance. If provided, the provider
///   does not manage the resource's lifecycle. Cannot be used together with [create].
///
/// ## Example
///
/// Using [create] to create and manage a resource:
///
/// ```dart
/// class MyStore extends JoltState {
///   final counter = Signal(0);
///
///   @override
///   void onMount(BuildContext context) {
///     print('Store mounted');
///   }
///
///   @override
///   void onUnmount(BuildContext context) {
///     print('Store unmounted');
///   }
/// }
///
/// JoltProvider<MyStore>(
///   create: (context) => MyStore(),
///   builder: (context, store) => Text('${store.counter.value}'),
/// )
/// ```
///
/// Using [value] to provide an externally managed resource:
///
/// ```dart
/// // Singleton store managed elsewhere
/// final globalStore = MyStore();
///
/// JoltProvider<MyStore>(
///   value: globalStore,
///   builder: (context, store) => Text('${store.counter.value}'),
/// )
/// ```
///
/// Accessing the resource from a descendant widget:
///
/// ```dart
/// Builder(
///   builder: (context) {
///     final store = JoltProvider.of<MyStore>(context);
///     return Text('Count: ${store.counter.value}');
///   },
/// )
/// ```
class JoltProvider<T> extends Widget {
  const JoltProvider(
      {super.key, required this.builder, this.create, this.value})
      : assert(create != null || value != null,
            'create or value must be provided'),
        assert(!(create != null && value != null),
            'create and value cannot be provided together');

  /// Function that builds the widget tree using the provided resource.
  ///
  /// The resource is provided both as a parameter and through the widget tree
  /// via [InheritedWidget], allowing access from descendant widgets using
  /// [of] or [maybeOf].
  final Widget Function(BuildContext context, T state) builder;

  /// Optional function to create the resource when the widget mounts.
  ///
  /// When provided, the provider manages the resource's lifecycle:
  /// - Calls [onMount] after creation if the resource implements [JoltState]
  /// - Calls [onUnmount] and disposes the resource when unmounted or replaced
  ///
  /// The function receives the build context and should return the resource instance.
  /// Cannot be used together with [value].
  final T Function(BuildContext context)? create;

  /// Optional pre-existing resource instance to provide.
  ///
  /// When provided, the provider does not manage the resource's lifecycle at all:
  /// - Does not call [onMount]
  /// - Does not call [onUnmount]
  /// - Does not dispose the resource
  /// - Does not call any lifecycle callbacks
  ///
  /// Use this when you want to provide an externally managed resource, such as
  /// a singleton or a resource managed by another provider.
  /// Cannot be used together with [create].
  final T? value;

  @override
  JoltProviderElement<T> createElement() => JoltProviderElement(this);

  /// Obtains the provided resource of type [T] from the widget tree.
  ///
  /// This method searches up the widget tree for a [JoltProvider] of type [T]
  /// and returns its provided resource.
  ///
  /// ## Throws
  ///
  /// Throws an exception if no [JoltProvider] of type [T] is found in the widget tree.
  /// Use [maybeOf] if the provider may not exist.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final store = JoltProvider.of<MyStore>(context);
  /// ```
  static T of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_JoltProviderData<T>>()!
        .data;
  }

  /// Obtains the provided resource of type [T] from the widget tree, if available.
  ///
  /// This method searches up the widget tree for a [JoltProvider] of type [T]
  /// and returns its provided resource. Returns `null` if no provider is found.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final store = JoltProvider.maybeOf<MyStore>(context);
  /// if (store != null) {
  ///   // Use the store
  /// }
  /// ```
  static T? maybeOf<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_JoltProviderData<T>>()
        ?.data;
  }
}

/// Element for [JoltProvider] that manages the reactive lifecycle.
///
/// This element handles resource creation, lifecycle callbacks, and provides
/// the resource to descendant widgets via [InheritedWidget].
class JoltProviderElement<T> extends ComponentElement
    with JoltCommonEffectBuilder {
  JoltProviderElement(JoltProvider<T> super.widget);

  @override
  JoltProvider<T> get widget => super.widget as JoltProvider<T>;

  jolt.EffectScope? _scope;
  jolt.Effect? _effect;

  T? _store;

  @override
  void mount(Element? parent, Object? newSlot) {
    _scope = jolt.EffectScope()
      ..run(() {
        // Use create function if provided, otherwise use value
        _store = widget.create?.call(this) ?? widget.value;
        _effect = jolt.Effect(joltBuildTriggerEffect, immediately: false);
      });

    super.mount(parent, newSlot);
  }

  bool _isFirstBuild = true;

  @override
  void performRebuild() {
    if (_isFirstBuild) {
      _isFirstBuild = false;
      if (_store is JoltState && widget.create != null) {
        _scope!.run(() {
          (_store as JoltState).onMount(this);
        });
      }
    }

    super.performRebuild();
  }

  @override
  void unmount() {
    // Only handle lifecycle for resources created via create function
    // Resources provided via value are not managed by the provider
    if (widget.create != null && _store != null) {
      if (_store is JoltState) {
        _scope!.run(() {
          (_store as JoltState).onUnmount(this);
        });
      }
      if (_store is Disposable) {
        (_store as Disposable).dispose();
      }
    }
    // Note: Resources provided via value are not disposed or unmounted
    // They should be managed externally
    _effect?.dispose();
    _effect = null;
    _scope?.dispose();
    _scope = null;
    _store = null;

    super.unmount();
  }

  @override
  Widget build() {
    if (_store == null) {
      // Resource not provided yet (should not happen with proper create/value),
      // return empty widget
      return const SizedBox.shrink();
    }

    final store = _store as T;
    late Widget child;

    final prevSub = reactive.setActiveSub(_effect);
    try {
      child = widget.builder(this, store);
    } finally {
      reactive.setActiveSub(prevSub);
    }

    return _JoltProviderData(
      data: store,
      child: child,
    );
  }

  @override
  void update(JoltProvider newWidget) {
    final oldWidget = widget;
    final oldStore = _store;
    final oldCreate = widget.create;
    final oldValue = widget.value;

    super.update(newWidget);
    assert(widget == newWidget);

    final newCreate = newWidget.create;
    final newValue = newWidget.value;

    final createChanged = !identical(oldWidget.create, newWidget.create);
    final valueChanged = !identical(oldValue, newValue);

    // Handle switching between create and value modes
    final switchingToCreate = oldCreate == null && newCreate != null;
    final switchingToValue = oldCreate != null && newCreate == null;

    // Handle changes to create function or switching from value to create
    if (createChanged || switchingToCreate) {
      T? newStore;
      if (newWidget.create != null) {
        _scope!.run(() {
          newStore = newWidget.create!.call(this) as T?;
        });
      }

      final storeChanged = !identical(oldStore, newStore);

      if (storeChanged) {
        // Cleanup old resource if it was created via create function
        if (oldCreate != null) {
          if (oldStore is JoltState) {
            _scope!.run(() {
              (oldStore as JoltState).onUnmount(this);
            });
          }
          if (oldStore is Disposable) {
            (oldStore as Disposable).dispose();
          }
        }

        _store = newStore;

        // Call onMount for new resource if it was created via create function
        if (newCreate != null && _store is JoltState) {
          _scope!.run(() {
            (_store as JoltState).onMount(this);
          });
        }
      }
    }

    // Handle changes to value parameter or switching from create to value
    if ((valueChanged || switchingToValue) && newCreate == null) {
      // Cleanup old resource if switching from create to value
      // (switchingToValue implies oldCreate != null)
      if (switchingToValue && oldStore != null) {
        if (oldStore is JoltState) {
          _scope!.run(() {
            (oldStore as JoltState).onUnmount(this);
          });
        }
        if (oldStore is Disposable) {
          (oldStore as Disposable).dispose();
        }
      }
      // Simply update the value, no lifecycle management for externally provided resources
      _store = newValue;
    }

    rebuild(force: true);
  }
}

class _JoltProviderData<T> extends InheritedWidget {
  const _JoltProviderData({required super.child, required this.data});

  final T data;

  @override
  bool updateShouldNotify(_JoltProviderData old) => old.data != data;
}
