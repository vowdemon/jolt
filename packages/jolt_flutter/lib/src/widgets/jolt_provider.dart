import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

import 'jolt_builder.dart';
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
/// ## Resource Creation
///
/// Resources are created using the [create] function when the widget mounts. If
/// [create] is `null`, no resource will be created and [builder] will not be called.
///
/// ## Lifecycle Management
///
/// If the resource implements [JoltState], lifecycle callbacks are automatically
/// invoked:
/// - [onMount] is called after the resource is created and the widget is mounted
/// - [onUnmount] is called when the widget is unmounted
///
/// ## Resource Updates
///
/// When the [create] function changes, the provider checks if a new resource should
/// be created. If the new resource is identical to the old one (e.g., const instances),
/// no recreation occurs. Otherwise, the old resource's [onUnmount] is called, and
/// the new resource's [onMount] is called.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree using the provided resource.
///   The resource is passed as the second parameter and is also accessible via
///   [JoltProvider.of] or [JoltProvider.maybeOf] in descendant widgets.
/// - [create]: Optional function to create the resource when the widget mounts.
///   If `null`, no resource is created.
///
/// ## Example
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
  const JoltProvider({
    super.key,
    required this.builder,
    this.create,
  });

  /// Function that builds the widget tree using the provided resource.
  ///
  /// The resource is provided both as a parameter and through the widget tree
  /// via [InheritedWidget], allowing access from descendant widgets using
  /// [of] or [maybeOf].
  final Widget Function(BuildContext context, T state) builder;

  /// Optional function to create the resource when the widget mounts.
  ///
  /// If `null`, no resource is created and [builder] will not be called.
  /// The function receives the build context and should return the resource instance.
  final T Function(BuildContext context)? create;

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
class JoltProviderElement<T> extends ComponentElement {
  JoltProviderElement(JoltProvider<T> super.widget);

  @override
  JoltProvider<T> get widget => super.widget as JoltProvider<T>;

  jolt.EffectScope? _scope;

  T? _store;

  @override
  void mount(Element? parent, Object? newSlot) {
    _scope = jolt.EffectScope()
      ..run(() {
        _store = widget.create?.call(
          this,
        );
      });

    super.mount(parent, newSlot);

    if (_store is JoltState) {
      _scope!.run(() {
        (_store as JoltState).onMount(this);
      });
    }
  }

  @override
  void unmount() {
    if (_store is JoltState) {
      _scope!.run(() {
        (_store as JoltState).onUnmount(this);
      });
    }
    _scope?.dispose();
    _scope = null;
    _store = null;

    super.unmount();
  }

  @override
  Widget build() {
    if (_store == null) {
      // Store not created yet, return empty widget
      return const SizedBox.shrink();
    }

    final store = _store as T;
    return _JoltProviderData(
      data: store,
      child: JoltBuilder(
        builder: (BuildContext context) {
          // Store is available via closure or via JoltProvider.of<T>(context)
          return widget.builder(context, store);
        },
      ),
    );
  }

  @override
  void update(JoltProvider newWidget) {
    final oldWidget = widget;
    final oldStore = _store;

    super.update(newWidget);
    assert(widget == newWidget);

    final createChanged = !identical(oldWidget.create, newWidget.create);

    if (createChanged) {
      T? newStore;
      if (newWidget.create != null) {
        _scope!.run(() {
          newStore = newWidget.create!.call(this) as T?;
        });
      }

      final storeChanged = !identical(oldStore, newStore);

      if (storeChanged) {
        if (oldStore is JoltState) {
          _scope!.run(() {
            (oldStore as JoltState).onUnmount(this);
          });
        }

        _store = newStore;

        if (_store is JoltState) {
          _scope!.run(() {
            (_store as JoltState).onMount(this);
          });
        }
      }
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
