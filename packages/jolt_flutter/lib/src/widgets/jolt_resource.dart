import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

import 'jolt_state.dart';

/// A widget that provides reactive resource management with lifecycle callbacks.
///
/// [JoltResource] allows you to create and manage resources that implement the [JoltState]
/// interface, providing automatic lifecycle management with [onMount] and [onUnmount]
/// callbacks.
///
/// You can either provide a pre-created resource via [value] or create one dynamically
/// via [create]. The [builder] function receives the resource and builds the widget tree.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget using the provided resource
/// - [create]: Optional function to create the resource when the widget mounts
/// - [value]: Optional pre-created resource to use
///
/// ## Example
///
/// ```dart
/// class MyStore implements Jolt {
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
/// JoltResource<MyStore>(
///   create: (context) => MyStore(),
///   builder: (context, store) => Text('${store.counter.value}'),
/// )
/// ```
class JoltResource<T> extends Widget {
  const JoltResource(
      {super.key, required this.builder, this.create, this.value})
      : assert(create == null || value == null,
            'create and value cannot be provided together');

  /// Function that builds the widget tree using the provided resource.
  final Widget Function(BuildContext context, T state) builder;

  /// Optional function to create the resource when the widget mounts.
  final T Function(BuildContext context)? create;

  /// Optional pre-created resource to use instead of creating one.
  final T? value;

  /// Builds the widget using the provided resource.
  ///
  /// ## Parameters
  ///
  /// - [context]: The build context
  /// - [store]: The resource instance
  ///
  /// ## Returns
  ///
  /// The widget built by the [builder] function
  Widget build(BuildContext context, T store) => builder(context, store);

  @override
  JoltResourceElement<T> createElement() => JoltResourceElement(this);

  /// Creates a simple [JoltResource] that only provides a builder function.
  ///
  /// This factory constructor is useful when you don't need resource management
  /// but want to use the reactive capabilities.
  ///
  /// ## Parameters
  ///
  /// - [key]: Optional widget key
  /// - [builder]: Function that builds the widget tree
  ///
  /// ## Returns
  ///
  /// A [JoltResource] instance with no resource management
  ///
  /// ## Example
  ///
  /// ```dart
  /// JoltResource.builder(
  ///   builder: (context) => Text('Hello World'),
  /// )
  /// ```
  factory JoltResource.builder({
    Key? key,
    required WidgetBuilder builder,
  }) {
    return JoltResource(
      key: key,
      builder: (context, _) => builder(context),
    );
  }
}

/// Element for [JoltResource] that manages the reactive lifecycle.
class JoltResourceElement<T> extends ComponentElement {
  JoltResourceElement(JoltResource super.widget);

  @override
  JoltResource get widget => super.widget as JoltResource;
  Widget? _lastBuiltWidget;

  jolt.Effect? _effect;
  jolt.EffectScope? _scope;

  T? _store;

  @override
  void mount(Element? parent, Object? newSlot) {
    _lastBuiltWidget = null;
    _scope = jolt.EffectScope((scope) {
      _store = widget.value ??
          widget.create?.call(
            this,
          ) as T?;
      _effect = jolt.Effect(_effectFn, immediately: false);
    });

    super.mount(parent, newSlot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_store is JoltState) {
        (_store as JoltState).onMount();
      }
    });
  }

  @override
  void unmount() {
    if (_store is JoltState) {
      (_store as JoltState).onUnmount();
    }

    _scope?.dispose();
    _scope = null;
    _store = null;
    _effect = null;

    _lastBuiltWidget = null;

    super.unmount();
  }

  void _effectFn() {
    _lastBuiltWidget = (widget).build(this, _store);

    if (switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.idle => true,
      SchedulerPhase.postFrameCallbacks => true,
      _ => false,
    }) {
      markNeedsBuild();
    } else {
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (_effect?.isDisposed ?? true) return;
        markNeedsBuild();
      });
    }
  }

  @override
  Widget build() {
    if (_lastBuiltWidget == null) {
      _effect!.run();
    }

    return _lastBuiltWidget!;
  }

  @override
  void update(JoltResource newWidget) {
    super.update(newWidget);

    assert(widget == newWidget);
    _lastBuiltWidget = null;
    rebuild(force: true);
  }
}
