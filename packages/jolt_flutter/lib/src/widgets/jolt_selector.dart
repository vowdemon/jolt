import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

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
    return (widget).build(this);
  }

  @override
  void update(JoltSelector newWidget) {
    super.update(newWidget);

    assert(widget == newWidget);
    rebuild(force: true);
  }
}
