import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';

import '../effect/flutter_effect.dart';

/// A widget that rebuilds when a single [Readable] changes.
///
/// Tracks [readable] during build and passes its current value to [builder].
/// Use [JoltBuilder] when multiple reactive sources should be discovered
/// automatically inside one build function.
///
/// ```dart
/// final counter = Signal(0);
///
/// JoltWatcher(
///   readable: counter,
///   builder: (context, value) => Text('$value'),
/// )
/// ```
class JoltWatcher<T> extends StatelessWidget {
  /// Creates a watcher for [readable].
  const JoltWatcher({super.key, required this.readable, required this.builder});

  /// The reactive source to track.
  final Readable<T> readable;

  /// Builds the subtree from the current value of [readable].
  final Widget Function(BuildContext context, T value) builder;

  /// Creates a watcher whose [builder] receives only the value.
  factory JoltWatcher.value({
    required Readable<T> readable,
    required Widget Function(T value) builder,
  }) {
    return JoltWatcher(
        readable: readable, builder: (context, value) => builder(value));
  }

  @override
  Widget build(BuildContext context) => builder(context, readable.peek);

  @override
  StatelessElement createElement() => _JoltWatcherElement(this);
}

/// Adds [JoltWatcher.value] as a shorthand on [Readable].
extension JoltFlutterWatchExtension<T> on Readable<T> {
  /// Returns a widget that rebuilds when this readable changes.
  Widget watch(Widget Function(T value) builder) {
    return JoltWatcher<T>.value(readable: this, builder: builder);
  }
}

class _JoltWatcherElement extends StatelessElement {
  _JoltWatcherElement(JoltWatcher super.widget);

  @override
  JoltWatcher get widget => super.widget as JoltWatcher;

  FlutterEffect? _effect;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = FlutterEffect(markNeedsBuild,
        lazy: true,
        detach: true,
        debug: const JoltDebugOption.type('JoltWatcher'));

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
      widget.readable.value;
    } finally {
      setActiveSub(prevSub);
    }

    return widget.build(this);
  }
}
