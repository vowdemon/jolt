import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

/// A widget that provides reactive resource management with lifecycle callbacks.
///
/// [JoltResource] allows you to create and manage resources that implement the [Jolt]
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
  final Widget Function(BuildContext context, T jolt) builder;

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
      if (_store is Jolt) {
        (_store as Jolt).onMount(this);
      }
    });
  }

  @override
  void unmount() {
    if (_store is Jolt) {
      (_store as Jolt).onUnmount(this);
    }

    _scope?.dispose();
    _scope = null;
    _store = null;
    _effect = null;

    _lastBuiltWidget = null;

    super.unmount();
  }

  void _effectFn() {
    _lastBuiltWidget =
        _scope?.run((scope) => (widget).build(this, _store), false);

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

/// A widget that automatically rebuilds when any signal accessed in its builder changes.
///
/// [JoltBuilder] creates a reactive scope where any signal access is tracked.
/// When tracked signals change, the widget automatically rebuilds with the new values.
///
/// This is the primary widget for creating reactive UIs with Jolt signals.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree and can access signals
///
/// ## Example
///
/// ```dart
/// final counter = Signal(0);
/// final name = Signal('Flutter');
///
/// JoltBuilder(
///   builder: (context) => Column(
///     children: [
///       Text('Hello ${name.value}'),
///       Text('Count: ${counter.value}'),
///       ElevatedButton(
///         onPressed: () => counter.value++,
///         child: Text('Increment'),
///       ),
///     ],
///   ),
/// )
/// ```
class JoltBuilder extends Widget {
  const JoltBuilder({super.key, required this.builder});

  /// Function that builds the widget tree and can access reactive signals.
  final Widget Function(
    BuildContext context,
  ) builder;

  /// Builds the widget in a reactive scope.
  ///
  /// ## Parameters
  ///
  /// - [context]: The build context
  ///
  /// ## Returns
  ///
  /// The widget built by the [builder] function
  Widget build(
    BuildContext context,
  ) =>
      builder(context);

  @override
  JoltBuilderElement createElement() => JoltBuilderElement(this);
}

/// Element for [JoltBuilder] that manages reactive rebuilds.
class JoltBuilderElement extends ComponentElement {
  JoltBuilderElement(JoltBuilder super.widget);

  @override
  JoltBuilder get widget => super.widget as JoltBuilder;
  Widget? _lastBuiltWidget;

  jolt.Effect? _effect;
  jolt.EffectScope? _scope;

  @override
  void mount(Element? parent, Object? newSlot) {
    _lastBuiltWidget = null;
    _scope = jolt.EffectScope((scope) {
      _effect = jolt.Effect(_effectFn, immediately: false);
    });

    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _effect?.dispose();
    _effect = null;

    _lastBuiltWidget = null;
    super.unmount();

    _scope?.dispose();
    _scope = null;
  }

  void _effectFn() {
    _lastBuiltWidget = _scope?.run((_) => widget.build(this), false);

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
  void update(JoltBuilder newWidget) {
    super.update(newWidget);

    assert(widget == newWidget);
    _lastBuiltWidget = null;
    rebuild(force: true);
  }
}

/// A widget that rebuilds only when a specific selector function's result changes.
///
/// [JoltSelector] provides fine-grained control over when rebuilds occur by
/// watching a selector function. The widget only rebuilds when the selector's
/// return value changes, making it more efficient than [JoltBuilder] for
/// specific use cases.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree
/// - [selector]: Function that returns a value to watch for changes
///
/// ## Example
///
/// ```dart
/// final user = Signal(User(name: 'John', age: 30));
///
/// // Only rebuilds when the user's name changes, not age
/// JoltSelector(
///   selector: () => user.value.name,
///   builder: (context) => Text('Hello ${user.value.name}'),
/// )
/// ```
class JoltSelector extends Widget {
  const JoltSelector({
    super.key,
    required this.builder,
    required this.selector,
  });

  /// Function that builds the widget tree.
  final Widget Function(BuildContext context) builder;

  /// Function that returns a value to watch for changes.
  final Object? Function() selector;

  /// Builds the widget.
  ///
  /// ## Parameters
  ///
  /// - [context]: The build context
  ///
  /// ## Returns
  ///
  /// The widget built by the [builder] function
  Widget build(BuildContext context) => builder(context);

  @override
  JoltSelectorElement createElement() => JoltSelectorElement(this);
}

/// Element for [JoltSelector] that manages selective rebuilds.
class JoltSelectorElement extends ComponentElement {
  JoltSelectorElement(JoltSelector super.widget);

  @override
  JoltSelector get widget => super.widget as JoltSelector;

  jolt.Watcher<Object?>? _watcher;
  jolt.EffectScope? _scope;

  @override
  void mount(Element? parent, Object? newSlot) {
    _watcher = jolt.Watcher(widget.selector, (_, __) => markNeedsBuild());

    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _watcher?.dispose();
    _watcher = null;

    super.unmount();

    _scope?.dispose();
    _scope = null;
  }

  @override
  Widget build() {
    return _scope!.run((scope) => widget.build(this), false);
  }

  @override
  void update(JoltSelector newWidget) {
    super.update(newWidget);

    assert(widget == newWidget);
    rebuild(force: true);
  }
}

/// Interface for objects that need lifecycle management in [JoltResource].
///
/// Classes implementing [Jolt] can receive mount and unmount notifications
/// when used with [JoltResource], allowing for proper resource management
/// and cleanup.
///
/// ## Example
///
/// ```dart
/// class MyStore implements Jolt {
///   final counter = Signal(0);
///   Timer? _timer;
///
///   @override
///   void onMount(BuildContext context) {
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       counter.value++;
///     });
///   }
///
///   @override
///   void onUnmount(BuildContext context) {
///     _timer?.cancel();
///   }
/// }
/// ```
abstract interface class Jolt {
  Jolt();

  /// Called when the resource is mounted to the widget tree.
  ///
  /// Use this method to initialize resources, start timers, or set up
  /// subscriptions that should be active while the widget is mounted.
  ///
  /// ## Parameters
  ///
  /// - [context]: The build context where the resource is mounted
  void onMount(BuildContext context);

  /// Called when the resource is unmounted from the widget tree.
  ///
  /// Use this method to clean up resources, cancel timers, or dispose
  /// of subscriptions to prevent memory leaks.
  ///
  /// ## Parameters
  ///
  /// - [context]: The build context where the resource was mounted
  void onUnmount(BuildContext context);
}
