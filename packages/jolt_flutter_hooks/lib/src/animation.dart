import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:jolt_flutter/setup.dart';

/// Creates a single ticker provider
///
/// If you need multiple tickers, call this hook multiple times
TickerProvider useSingleTickerProvider() {
  final provider = useHook(_SingleTickerProvider());

  return provider;
}

class _SingleTickerProvider extends SetupHook<TickerProvider>
    implements TickerProvider {
  _SingleTickerProvider();

  Ticker? _ticker;
  ValueListenable<bool>? _tickerModeNotifier;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(_ticker == null,
        'useSingleTickerProvider can only create one Ticker. If you need multiple tickers, call this hook multiple times.');

    _ticker = Ticker(onTick, debugLabel: 'created by $context');
    _updateTickerMode();
    return _ticker!;
  }

  @override
  void mount() => _updateTickerMode();

  @override
  void didChangeDependencies() => _updateTickerMode();

  @override
  void unmount() {
    assert(_ticker == null || !_ticker!.isActive,
        'Ticker is still active. Please dispose AnimationController first.');

    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    _tickerModeNotifier = null;
    _ticker = null;
  }

  void _updateTickerMode() {
    final notifier = TickerMode.getNotifier(context);
    if (notifier == _tickerModeNotifier) return;

    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    _tickerModeNotifier = notifier;
    notifier.addListener(_onTickerModeChanged);

    _onTickerModeChanged();
  }

  void _onTickerModeChanged() {
    _ticker?.muted = !(_tickerModeNotifier?.value ?? true);
  }

  @override
  TickerProvider build() {
    return this;
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
  final vsyncProvider = vsync ?? useSingleTickerProvider();
  final controller = useMemoized(
      () => AnimationController(
            vsync: vsyncProvider,
            value: value,
            duration: duration,
            reverseDuration: reverseDuration,
            lowerBound: lowerBound,
            upperBound: upperBound,
            animationBehavior: animationBehavior,
          ),
      (controller) => controller.dispose());

  return controller;
}
