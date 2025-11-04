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
/// ## Usage
///
/// Any signal, computed value, or reactive collection accessed within the [builder]
/// will be automatically tracked. When these reactive values change, the widget
/// rebuilds to reflect the new state.
///
/// Multiple signals accessed in the same builder will trigger a single rebuild
/// when any of them change. Batch updates are handled automatically, ensuring
/// only one rebuild occurs per frame.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree and can access signals.
///   This builder runs in a reactive scope, automatically tracking dependencies.
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
class JoltBuilder extends StatelessWidget {
  const JoltBuilder({super.key, required this.builder});

  /// Function that builds the widget tree and can access reactive signals.
  ///
  /// Any signal, computed value, or reactive collection accessed within this
  /// builder will be automatically tracked, and the widget will rebuild when
  /// any of them change.
  final Widget Function(BuildContext context) builder;
  @override
  Widget build(
    BuildContext context,
  ) =>
      builder(context);

  @override
  JoltBuilderElement createElement() => JoltBuilderElement(this);
}

/// Element for [JoltBuilder] that manages reactive rebuilds.
///
/// This element creates an [EffectScope] to track dependencies and automatically
/// triggers rebuilds when tracked signals change.
class JoltBuilderElement extends StatelessElement {
  JoltBuilderElement(JoltBuilder super.widget);

  @override
  JoltBuilder get widget => super.widget as JoltBuilder;
  Widget? _lastBuiltWidget;

  jolt.Effect? _effect;
  jolt.EffectScope? _scope;

  @override
  void mount(Element? parent, Object? newSlot) {
    _lastBuiltWidget = null;
    _scope = jolt.EffectScope()
      ..run(() {
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
  void update(StatelessWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _lastBuiltWidget = null;
    rebuild(force: true);
  }
}
