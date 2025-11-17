import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:jolt_flutter/setup.dart';

/// Creates a single ticker provider
///
/// If you need multiple tickers, call this hook multiple times
TickerProvider useSingleTickerProvider() {
  final context = useContext();
  final provider = useHook(() => _SingleTickerProvider(context));

  onMounted(provider._init);
  onChangedDependencies(provider._update);
  onUnmounted(provider._dispose);

  return provider;
}

class _SingleTickerProvider implements TickerProvider {
  _SingleTickerProvider(this._context);

  final BuildContext _context;
  Ticker? _ticker;
  ValueListenable<bool>? _tickerModeNotifier;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(_ticker == null,
        'useSingleTickerProvider can only create one Ticker. If you need multiple tickers, call this hook multiple times.');

    _ticker = Ticker(onTick, debugLabel: 'created by $_context');
    _updateTickerMode();
    return _ticker!;
  }

  void _init() => _updateTickerMode();

  void _update() => _updateTickerMode();

  void _dispose() {
    assert(_ticker == null || !_ticker!.isActive,
        'Ticker is still active. Please dispose AnimationController first.');

    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    _tickerModeNotifier = null;
    _ticker = null;
  }

  void _updateTickerMode() {
    final notifier = TickerMode.getNotifier(_context);
    if (notifier == _tickerModeNotifier) return;

    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    _tickerModeNotifier = notifier;
    notifier.addListener(_onTickerModeChanged);

    _onTickerModeChanged();
  }

  void _onTickerModeChanged() {
    _ticker?.muted = !(_tickerModeNotifier?.value ?? true);
  }
}

/// Creates an animation controller
///
/// The controller will be automatically disposed when the component is unmounted
AnimationController useAnimationController({
  TickerProvider? vsync,
  double? value,
  Duration? duration,
  Duration? reverseDuration,
  double lowerBound = 0.0,
  double upperBound = 1.0,
  AnimationBehavior animationBehavior = AnimationBehavior.normal,
}) {
  final controller = useHook(() => AnimationController(
        vsync: vsync ?? useSingleTickerProvider(),
        value: value,
        duration: duration,
        reverseDuration: reverseDuration,
        lowerBound: lowerBound,
        upperBound: upperBound,
        animationBehavior: animationBehavior,
      ));

  onUnmounted(controller.dispose);

  return controller;
}
