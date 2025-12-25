import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/extension.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Listens to application lifecycle state changes
///
/// Returns a reactive Signal representing the current application lifecycle state
ReadonlySignal<AppLifecycleState?> useAppLifecycleState({
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

  final AppLifecycleState? initialState;
  final void Function(AppLifecycleState state)? onChange;

  @override
  void mount() {
    WidgetsBinding.instance.addObserver(this);
    state.value = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void unmount() {
    WidgetsBinding.instance.removeObserver(this);
  }

  // coverage:ignore-start
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state.value = state;
    onChange?.call(state);
  }
  // coverage:ignore-end

  @override
  Signal<AppLifecycleState?> build() {
    return Signal<AppLifecycleState?>(
        initialState ?? WidgetsBinding.instance.lifecycleState);
  }
}
