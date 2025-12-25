import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart' as reactive;
import 'package:jolt_flutter/core.dart';

import '../effect/flutter_effect.dart';

/// A widget that automatically rebuilds when a Readable value changes.
///
/// [JoltWatchBuilder] tracks a single [Readable] value and rebuilds the widget
/// whenever that value changes. The widget uses [FlutterEffect] to manage
/// reactive dependencies and trigger rebuilds.
///
/// ## Usage
///
/// The widget tracks the [readable] value during build. When the value changes,
/// the widget automatically rebuilds with the new value passed to the [builder].
///
/// ## Parameters
///
/// - [readable]: The Readable value to track
/// - [builder]: Function that builds a widget from the current value and context
///
/// ## Example
///
/// ```dart
/// final counter = Signal(0);
///
/// JoltWatchBuilder<int>(
///   readable: counter,
///   builder: (context, value) => Text('Count: $value'),
/// )
/// ```
class JoltWatchBuilder<T> extends StatelessWidget {
  const JoltWatchBuilder(
      {super.key, required this.readable, required this.builder});

  /// The Readable value to track for changes.
  final Readable<T> readable;

  /// Function that builds a widget from the current value.
  ///
  /// Parameters:
  /// - [context]: The build context
  /// - [value]: The current value from [readable]
  ///
  /// Returns: A widget built from the current value
  final Widget Function(BuildContext context, T value) builder;

  /// Factory constructor for creating a builder without context parameter.
  ///
  /// Parameters:
  /// - [readable]: The Readable value to track
  /// - [builder]: Function that builds a widget from the current value only
  ///
  /// Returns: A JoltWatchBuilder instance
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// counter.watch((value) => Text('Count: $value'))
  /// ```
  factory JoltWatchBuilder.value(
      {required Readable<T> readable,
      required Widget Function(T value) builder}) {
    return JoltWatchBuilder(
        readable: readable, builder: (context, value) => builder(value));
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  Widget build(
    BuildContext context,
  ) =>
      builder(context, readable.peek);

  @override
  JoltWatchBuilderElement createElement() => JoltWatchBuilderElement(this);
}

/// Element for [JoltWatchBuilder] that manages reactive rebuilds.
///
/// This element creates a [FlutterEffect] to track the [readable] value
/// and automatically triggers rebuilds when it changes. The effect is
/// created lazily on mount and disposed on unmount.
class JoltWatchBuilderElement extends StatelessElement {
  /// Creates an element for the given widget.
  JoltWatchBuilderElement(JoltWatchBuilder super.widget);

  @override
  JoltWatchBuilder get widget => super.widget as JoltWatchBuilder;

  /// The FlutterEffect that tracks the readable value and triggers rebuilds.
  FlutterEffect? _effect;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = FlutterEffect.lazy(markNeedsBuild);

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
    final prevSub = reactive.setActiveSub(_effect as ReactiveNode);
    try {
      widget.readable.value;
    } finally {
      reactive.setActiveSub(prevSub);
    }

    return widget.build(this);
  }
}
