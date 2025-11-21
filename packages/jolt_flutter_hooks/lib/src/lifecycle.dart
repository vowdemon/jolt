import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

/// Listens to application lifecycle state changes
///
/// Returns a reactive Signal representing the current application lifecycle state
ReadonlySignal<AppLifecycleState?> useAppLifecycleState([
  AppLifecycleState? initialState,
]) {
  final observer = useHook(_AppLifecycleObserver());

  return observer.readonly();
}

class _AppLifecycleObserver extends SetupHook<Signal<AppLifecycleState?>>
    with WidgetsBindingObserver {
  _AppLifecycleObserver();

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
  }
  // coverage:ignore-end

  @override
  Signal<AppLifecycleState?> createState() {
    return Signal<AppLifecycleState?>(WidgetsBinding.instance.lifecycleState);
  }
}
