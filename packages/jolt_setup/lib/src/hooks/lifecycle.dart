import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../setup/framework.dart';
import 'annotation.dart';

/// Tracks the application's current [AppLifecycleState].
///
/// The returned readable updates when Flutter reports lifecycle changes. Use
/// [onChange] for imperative reactions and the returned signal for reactive UI
/// or effects.
///
/// ```dart
/// setup(context, props) {
///   final lifecycle = useAppLifecycleState();
///
///   return () => Text('${lifecycle.value}');
/// }
/// ```
@defineHook
Readonly<AppLifecycleState?> useAppLifecycleState({
  AppLifecycleState? initialState,
  void Function(AppLifecycleState state)? onChange,
}) {
  final observer = useHook(
      _AppLifecycleObserver(initialState: initialState, onChange: onChange));

  return observer.readonly();
}

class _AppLifecycleObserver extends SetupHook<Signal<AppLifecycleState?>>
    with WidgetsBindingObserver {
  _AppLifecycleObserver({this.initialState, this.onChange});

  late AppLifecycleState? initialState;
  late void Function(AppLifecycleState state)? onChange;

  @override
  void mount() {
    WidgetsBinding.instance.addObserver(this);
    state.value = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void unmount() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state.value = state;
    onChange?.call(state);
  }

  @override
  Signal<AppLifecycleState?> build() {
    return Signal<AppLifecycleState?>(
        initialState ?? WidgetsBinding.instance.lifecycleState);
  }

  @override
  void reassemble(covariant _AppLifecycleObserver newHook) {
    onChange = newHook.onChange;
  }
}
