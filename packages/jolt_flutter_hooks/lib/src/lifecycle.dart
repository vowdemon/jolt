import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

/// Listens to application lifecycle state changes
///
/// Returns a reactive Signal representing the current application lifecycle state
ReadonlySignal<AppLifecycleState?> useAppLifecycleState([
  AppLifecycleState? initialState,
]) {
  final observer = useHook(() => _AppLifecycleObserver(
        initialState ?? WidgetsBinding.instance.lifecycleState,
      ));

  onMounted(observer.attach);
  onUnmounted(observer.dispose);

  return observer.state;
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(AppLifecycleState? initialState)
      : _state = Signal<AppLifecycleState?>(initialState);

  final Signal<AppLifecycleState?> _state;
  bool _isAttached = false;

  ReadonlySignal<AppLifecycleState?> get state => _state.readonly();

  void attach() {
    if (_isAttached) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _isAttached = true;

    final lifecycleState = binding.lifecycleState;
    // coverage:ignore-start
    if (lifecycleState != null) {
      _state.value = lifecycleState;
    }
    // coverage:ignore-end
  }

  void dispose() {
    if (_isAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _isAttached = false;
    }
    _state.dispose();
  }

  // coverage:ignore-start
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state.value = state;
  }
  // coverage:ignore-end
}
