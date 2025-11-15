import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart' as jolt;

/// A widget that rebuilds only when a specific selector function's result changes.
///
/// [JoltSelector] provides fine-grained control over when rebuilds occur by
/// watching a selector function. The widget only rebuilds when the selector's
/// return value changes, making it more efficient than [JoltBuilder] for
/// scenarios where you only need to react to specific derived values.
///
/// The [selector] function receives the previous selected value (or `null` on first run)
/// and returns the new value to watch. Rebuilds occur only when the returned value
/// changes (using equality comparison).
///
/// ## When to Use
///
/// Use [JoltSelector] when you need to:
/// - Select a specific value from a complex object
/// - Filter or transform reactive data before rebuilding
/// - Avoid unnecessary rebuilds when unrelated parts of a signal change
///
/// For general reactive UI needs, [JoltBuilder] is simpler and recommended.
///
/// ## Parameters
///
/// - [builder]: Function that builds the widget tree. Receives the context and
///   the current selected value.
/// - [selector]: Function that computes the value to watch for changes. Receives
///   the previous selected value (or `null` on first run) and returns the new value.
///
/// ## Example
///
/// ```dart
/// final user = Signal(User(name: 'John', age: 30));
///
/// // Only rebuilds when the user's name changes, not age
/// JoltSelector(
///   selector: (prev) => user.value.name,
///   builder: (context, name) => Text('Hello $name'),
/// )
/// ```
///
/// With multiple signals:
///
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// JoltSelector(
///   selector: (prev) => '${firstName.value} ${lastName.value}',
///   builder: (context, fullName) => Text('Hello $fullName'),
/// )
/// ```
class JoltSelector<T> extends Widget {
  const JoltSelector({
    super.key,
    required this.builder,
    required this.selector,
  });

  /// Function that builds the widget tree.
  ///
  /// This builder receives the context and the currently selected value.
  /// The selected value is the result of the last [selector] execution.
  final Widget Function(BuildContext context, T state) builder;

  /// Function that computes the value to watch for changes.
  ///
  /// This selector runs in a reactive scope, automatically tracking any signals
  /// accessed within it. The widget rebuilds only when the returned value changes
  /// (using equality comparison).
  ///
  /// The function receives the previous selected value (or `null` on first run),
  /// which can be useful for comparison or initialization logic.
  ///
  /// ## Example
  ///
  /// ```dart
  /// JoltSelector(
  ///   selector: (prev) {
  ///     // Can use previous value for comparison
  ///     final current = computeValue();
  ///     if (prev != null && prev == current) {
  ///       return prev; // Return same instance to prevent rebuild
  ///     }
  ///     return current;
  ///   },
  ///   builder: (context, value) => Text('$value'),
  /// )
  /// ```
  final T Function(T? prevState) selector;

  @override
  JoltSelectorElement<T> createElement() => JoltSelectorElement(this);
}

/// Element for [JoltSelector] that manages selective rebuilds.
///
/// This element creates an [EffectScope] to track dependencies in the selector
/// function and only triggers rebuilds when the selected value actually changes.
class JoltSelectorElement<T> extends ComponentElement {
  JoltSelectorElement(JoltSelector<T> super.widget);

  @override
  JoltSelector<T> get widget => super.widget as JoltSelector<T>;

  jolt.Effect? _effect;

  T? _state;
  bool _isFirstBuildEffect = true;

  @override
  void mount(Element? parent, Object? newSlot) {
    _effect = jolt.Effect(() {
      final oldState = _state;
      _state = widget.selector(_state);

      if (!_isFirstBuildEffect) {
        if (oldState != _state) {
          if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
            SchedulerBinding.instance.endOfFrame.then((_) {
              if (dirty) return;
              markNeedsBuild();
            });
          } else {
            if (dirty) return;
            markNeedsBuild();
          }
        }
      } else {
        _isFirstBuildEffect = false;
      }
    });

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
