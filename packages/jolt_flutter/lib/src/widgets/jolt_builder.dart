import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';

import '../effect/post_frame_effect.dart';

/// A [StatelessWidget] that rebuilds when reactive values read in [builder] change.
///
/// During each build, [builder] runs inside a reactive scope. Any [Readable]
/// accessed there becomes a dependency. When a dependency changes,
/// [PostFrameEffect] schedules a rebuild at the end of the current frame, so
/// multiple updates in one frame coalesce into a single rebuild.
///
/// For explicit dependencies only, use [JoltBuilder.manual].
///
/// ```dart
/// final counter = Signal(0);
///
/// JoltBuilder(
///   builder: (context) => Text('${counter.value}'),
/// )
/// ```
class JoltBuilder extends StatelessWidget {
  /// Creates a builder that tracks reactive reads inside [builder].
  const JoltBuilder({super.key, required this.builder});

  /// Creates a builder that rebuilds only when a [Readable] in [deps] changes.
  ///
  /// Reactive values read inside [builder] are not tracked. Use this when the
  /// build function must read signals for display without subscribing to them,
  /// or when dependencies should be declared explicitly.
  const factory JoltBuilder.manual({
    Key? key,
    required Widget Function(BuildContext context) builder,
    List<Readable> deps,
  }) = _JoltBuilderManual;

  /// Builds the widget subtree; reactive reads here establish dependencies.
  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) => builder(context);

  @override
  StatelessElement createElement() => _JoltBuilderElement(this);
}

class _JoltBuilderElement extends StatelessElement {
  _JoltBuilderElement(JoltBuilder super.widget);

  @override
  JoltBuilder get widget => super.widget as JoltBuilder;

  PostFrameEffect? _effect;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = PostFrameEffect(markNeedsBuild,
        lazy: true, debug: const JoltDebugOption.type('JoltBuilder'));

    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _effect?.dispose();
    _effect = null;

    super.unmount();
  }

  @override
  Widget build() {
    final prevSub = setActiveSub((_effect as EffectImpl).raw);
    try {
      return widget.build(this);
    } finally {
      setActiveSub(prevSub);
    }
  }
}

class _JoltBuilderManual extends StatelessWidget implements JoltBuilder {
  const _JoltBuilderManual(
      {super.key, required this.builder, this.deps = const []});

  @override
  final Widget Function(BuildContext context) builder;
  final List<Readable> deps;

  @override
  Widget build(BuildContext context) => builder(context);

  @override
  StatelessElement createElement() => _JoltBuilderManualElement(this);
}

class _JoltBuilderManualElement extends StatelessElement {
  _JoltBuilderManualElement(_JoltBuilderManual super.widget);

  @override
  _JoltBuilderManual get widget => super.widget as _JoltBuilderManual;

  PostFrameEffect? _effect;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = PostFrameEffect(markNeedsBuild,
        debug: const JoltDebugOption.type('JoltBuilder'));

    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _effect?.dispose();
    _effect = null;
    super.unmount();
  }

  @override
  Widget build() {
    final prevSub = setActiveSub((_effect as EffectImpl).raw);
    try {
      for (final dep in widget.deps) {
        dep.value;
      }
    } finally {
      setActiveSub(prevSub);
    }
    return widget.build(this);
  }
}
