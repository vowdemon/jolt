import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';

import '../effect/post_frame_effect.dart';

/// A widget that rebuilds only when a selected value changes.
///
/// The [selector] runs in a reactive scope on mount and whenever dependencies
/// change. The widget rebuilds only when the new result is not equal (`!=`) to
/// the previous one. On the first run, a change does not schedule an extra
/// rebuild. When the widget is updated, the selected value is cleared, the
/// selector runs again, and the subtree is force-rebuilt.
///
/// Prefer [JoltBuilder] when the whole subtree should track every reactive read.
///
/// ```dart
/// final user = Signal(User(name: 'Ada', age: 30));
///
/// JoltSelector(
///   selector: (_) => user.value.name,
///   builder: (context, name) => Text('Hello $name'),
/// )
/// ```
class JoltSelector<T> extends Widget {
  /// Creates a selector-driven reactive widget.
  const JoltSelector(
      {super.key, required this.builder, required this.selector});

  /// Builds the subtree from the latest value produced by [selector].
  final Widget Function(BuildContext context, T state) builder;

  /// Computes the value to compare across updates.
  ///
  /// Receives the previous result, or `null` on the first run. Return a value
  /// equal to the previous one (by `!=`) to skip a rebuild.
  final T Function(T? prevState) selector;

  @override
  ComponentElement createElement() => _JoltSelectorElement(this);
}

class _JoltSelectorElement<T> extends ComponentElement {
  _JoltSelectorElement(JoltSelector<T> super.widget);

  @override
  JoltSelector<T> get widget => super.widget as JoltSelector<T>;

  PostFrameEffect? _effect;

  T? _state;
  bool _isFirstBuildEffect = true;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = PostFrameEffect(() {
      final oldState = _state;
      _state = widget.selector(_state);

      if (!_isFirstBuildEffect) {
        if (oldState != _state) {
          markNeedsBuild();
        }
      } else {
        _isFirstBuildEffect = false;
      }
    }, detach: true, debug: const JoltDebugOption.type('JoltSelector'));

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
    return widget.builder(this, _state as T);
  }

  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _state = null;
    _effect?.run();
    rebuild(force: true);
  }
}
