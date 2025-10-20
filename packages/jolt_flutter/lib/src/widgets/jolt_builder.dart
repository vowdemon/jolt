import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

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
    _lastBuiltWidget = widget.build(this);

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
