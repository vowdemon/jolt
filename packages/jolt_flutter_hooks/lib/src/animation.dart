import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:jolt_flutter/setup.dart';

/// Creates a single ticker provider
///
/// If you need multiple tickers, call this hook multiple times or use [useTickerProvider]
TickerProvider useSingleTickerProvider() {
  final provider = useHook(_SingleTickerProviderHook());

  return provider;
}

class _SingleTickerProviderHook extends SetupHook<TickerProvider>
    implements TickerProvider {
  _SingleTickerProviderHook();

  Ticker? _ticker;
  ValueListenable<bool>? _tickerModeNotifier;

  @override
  Ticker createTicker(TickerCallback onTick) {
    // coverage:ignore-start
    assert(() {
      if (_ticker == null) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          '$runtimeType is a SingleTickerProviderStateMixin but multiple tickers were created.',
        ),
        ErrorDescription(
          'A SingleTickerProviderStateMixin can only be used as a TickerProvider once.',
        ),
        ErrorHint(
          'If a State is used for multiple AnimationController objects, or if it is passed to other '
          'objects and those objects might use it more than one time in total, then instead of '
          'mixing in a SingleTickerProviderStateMixin, use a regular TickerProviderStateMixin.',
        ),
      ]);
    }());
    // coverage:ignore-end
    _ticker = Ticker(
      onTick,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _updateTickerModeNotifier();
    _updateTicker(); // Sets _ticker.mute correctly.
    return _ticker!;
  }

  @override
  void unmount() {
    // coverage:ignore-start
    assert(() {
      if (_ticker == null || !_ticker!.isActive) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('$this was disposed with an active Ticker.'),
        ErrorDescription(
          '$runtimeType created a Ticker via its SingleTickerProviderStateMixin, but at the time '
          'dispose() was called on the mixin, that Ticker was still active. The Ticker must '
          'be disposed before calling super.dispose().',
        ),
        ErrorHint(
          'Tickers used by AnimationControllers '
          'should be disposed by calling dispose() on the AnimationController itself. '
          'Otherwise, the ticker will leak.',
        ),
        _ticker!.describeForError('The offending ticker was'),
      ]);
    }());
    // coverage:ignore-end
    _tickerModeNotifier?.removeListener(_updateTicker);
    _tickerModeNotifier = null;
  }

  // coverage:ignore-start
  @override
  void activate() {
    _updateTickerModeNotifier();
    _updateTicker();
  }
  // coverage:ignore-end

  void _updateTickerModeNotifier() {
    final notifier = TickerMode.getNotifier(context);
    if (notifier == _tickerModeNotifier) return;

    _tickerModeNotifier?.removeListener(_updateTicker);
    _tickerModeNotifier = notifier;
    notifier.addListener(_updateTicker);
  }

  void _updateTicker() {
    _ticker?.muted = !(_tickerModeNotifier?.value ?? true);
  }

  @override
  TickerProvider build() {
    return this;
  }
}

/// Creates a ticker provider that can create multiple tickers
///
/// If you need a single ticker, use [useSingleTickerProvider]
TickerProvider useTickerProvider() {
  return useHook(_TickerProviderHook());
}

class _TickerProviderHook extends SetupHook<_TickerProviderHook>
    implements TickerProvider {
  Set<Ticker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      _updateTickerModeNotifier();
    }
    assert(_tickerModeNotifier != null);
    _tickers ??= <_WidgetTicker>{};
    final _WidgetTicker result = _WidgetTicker(
      onTick,
      this,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    )..muted = !_tickerModeNotifier!.value;
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_WidgetTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  ValueListenable<bool>? _tickerModeNotifier;

  // coverage:ignore-start
  @override
  void activate() {
    // We may have a new TickerMode ancestor, get its Notifier.
    _updateTickerModeNotifier();
    _updateTickers();
  }
  // coverage:ignore-end

  void _updateTickers() {
    if (_tickers != null) {
      final bool muted = !_tickerModeNotifier!.value;
      for (final Ticker ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
  }

  void _updateTickerModeNotifier() {
    final ValueListenable<bool> newNotifier = TickerMode.getNotifier(context);
    if (newNotifier == _tickerModeNotifier) {
      return;
    }
    _tickerModeNotifier?.removeListener(_updateTickers);
    newNotifier.addListener(_updateTickers);
    _tickerModeNotifier = newNotifier;
  }

  @override
  void unmount() {
    // coverage:ignore-start
    assert(() {
      if (_tickers != null) {
        for (final Ticker ticker in _tickers!) {
          if (ticker.isActive) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('$this was disposed with an active Ticker.'),
              ErrorDescription(
                '$runtimeType created a Ticker via its TickerProviderStateMixin, but at the time '
                'dispose() was called on the mixin, that Ticker was still active. All Tickers must '
                'be disposed before calling super.dispose().',
              ),
              ErrorHint(
                'Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.',
              ),
              ticker.describeForError('The offending ticker was'),
            ]);
          }
        }
      }
      return true;
    }());
    // coverage:ignore-end
    _tickerModeNotifier?.removeListener(_updateTickers);
    _tickerModeNotifier = null;
  }

  @override
  _TickerProviderHook build() {
    return this;
  }
}

class _WidgetTicker extends Ticker {
  _WidgetTicker(super.onTick, this._creator, {super.debugLabel});

  final _TickerProviderHook _creator;

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
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
