import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('useSingleTickerProvider', () {
    testWidgets('creates provider', (tester) async {
      TickerProvider? provider;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          provider = useSingleTickerProvider();
          return () => const Text('Test');
        }),
      ));

      expect(provider, isNotNull);
      expect(provider, isA<TickerProvider>());
    });

    testWidgets('disposes correctly', (tester) async {
      Ticker? ticker;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final provider = useSingleTickerProvider();
          ticker = provider.createTicker((_) {});
          return () => const Text('Test');
        }),
      ));

      expect(ticker!.isActive, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Ticker should be cleaned up
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple instances work correctly', (tester) async {
      AnimationController? controller1;
      AnimationController? controller2;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync1 = useSingleTickerProvider();
          final vsync2 = useSingleTickerProvider();

          controller1 = useAnimationController(
            vsync: vsync1,
            duration: const Duration(milliseconds: 100),
          );

          controller2 = useAnimationController(
            vsync: vsync2,
            duration: const Duration(milliseconds: 200),
          );

          return () => Text('Test');
        }),
      ));

      expect(controller1, isNotNull);
      expect(controller2, isNotNull);
      expect(controller1!.duration, const Duration(milliseconds: 100));
      expect(controller2!.duration, const Duration(milliseconds: 200));

      // Both should be cleaned up correctly on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates on dependency change', (tester) async {
      Ticker? ticker;

      final toTestWidget = SetupBuilder(setup: (context) {
        // Access InheritedWidget to trigger dependency tracking
        CounterInherited.of(context);
        final provider = useSingleTickerProvider();
        ticker = provider.createTicker((_) {});
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 1,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state - ticker should not be muted
      expect(ticker, isNotNull);
      expect(ticker!.muted, isFalse);

      // Change InheritedWidget value to trigger onChangedDependencies
      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 2,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // _update() should have been called, ticker mode should be updated
      expect(ticker, isNotNull);
      expect(ticker!.muted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates ticker mode on TickerMode change', (tester) async {
      Ticker? ticker;
      bool? initialMuted;

      final toTestWidget = SetupBuilder(setup: (context) {
        final provider = useSingleTickerProvider();
        if (ticker == null) {
          ticker = provider.createTicker((_) {});
          initialMuted = ticker!.muted;
        }
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: TickerMode(
          enabled: true,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(initialMuted, isFalse);
      expect(ticker!.muted, isFalse);

      // Change TickerMode to disabled - this should trigger _update()
      await tester.pumpWidget(MaterialApp(
        home: TickerMode(
          enabled: false,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // _update() should have been called, ticker should be muted when TickerMode is disabled
      expect(ticker, isNotNull);
      expect(ticker!.muted, isTrue);
    });

    testWidgets('_update called on multiple dependency changes',
        (tester) async {
      Ticker? ticker;

      final toTestWidget = SetupBuilder(setup: (context) {
        CounterInherited.of(context);
        final provider = useSingleTickerProvider();
        ticker ??= provider.createTicker((_) {});
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 1,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Change dependency multiple times
      for (var i = 2; i <= 4; i++) {
        await tester.pumpWidget(MaterialApp(
          home: CounterInherited(
            value: i,
            child: toTestWidget,
          ),
        ));
        await tester.pumpAndSettle();
      }

      // _update() should have been called on each dependency change
      // Ticker should still work correctly
      expect(ticker, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('useAnimationController', () {
    testWidgets('creates controller', (tester) async {
      AnimationController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useAnimationController(
            duration: const Duration(seconds: 1),
          );
          return () => const Text('Test');
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.duration, const Duration(seconds: 1));
    });

    testWidgets('with parameters', (tester) async {
      AnimationController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useSingleTickerProvider();
          controller = useAnimationController(
            vsync: vsync,
            duration: const Duration(seconds: 2),
            lowerBound: 0.5,
            upperBound: 1.5,
            value: 1.0,
          );
          return () => Text('Value: ${controller!.value}');
        }),
      ));

      expect(controller!.value, 1.0);
      expect(controller!.lowerBound, 0.5);
      expect(controller!.upperBound, 1.5);
    });

    testWidgets('auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useSingleTickerProvider();
          useAnimationController(
            vsync: vsync,
            duration: const Duration(seconds: 1),
          );
          return () => const Text('Test');
        }),
      ));

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Should have no exception (controller auto-disposed)
      expect(tester.takeException(), isNull);
    });

    testWidgets('reactive rendering', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useSingleTickerProvider();
          final controller = useAnimationController(
            vsync: vsync,
            duration: const Duration(milliseconds: 100),
          );

          return () => AnimatedBuilder(
                animation: controller,
                builder: (context, child) => Text('${controller.isAnimating}'),
              );
        }),
      ));

      expect(find.text('false'), findsOneWidget);
    });
  });

  group('useTickerProvider', () {
    testWidgets('creates provider', (tester) async {
      TickerProvider? provider;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          provider = useTickerProvider();
          return () => const Text('Test');
        }),
      ));

      expect(provider, isNotNull);
      expect(provider, isA<TickerProvider>());
    });

    testWidgets('can create multiple tickers', (tester) async {
      Ticker? ticker1;
      Ticker? ticker2;
      Ticker? ticker3;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final provider = useTickerProvider();
          ticker1 = provider.createTicker((_) {});
          ticker2 = provider.createTicker((_) {});
          ticker3 = provider.createTicker((_) {});
          return () => const Text('Test');
        }),
      ));

      expect(ticker1, isNotNull);
      expect(ticker2, isNotNull);
      expect(ticker3, isNotNull);
      expect(ticker1!.isActive, isFalse);
      expect(ticker2!.isActive, isFalse);
      expect(ticker3!.isActive, isFalse);
    });

    testWidgets('disposes correctly', (tester) async {
      Ticker? ticker;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final provider = useTickerProvider();
          ticker = provider.createTicker((_) {});
          return () => const Text('Test');
        }),
      ));

      expect(ticker!.isActive, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Ticker should be cleaned up
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes multiple tickers correctly', (tester) async {
      Ticker? ticker1;
      Ticker? ticker2;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final provider = useTickerProvider();
          ticker1 = provider.createTicker((_) {});
          ticker2 = provider.createTicker((_) {});
          return () => const Text('Test');
        }),
      ));

      expect(ticker1!.isActive, isFalse);
      expect(ticker2!.isActive, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Both tickers should be cleaned up
      expect(tester.takeException(), isNull);
    });

    testWidgets('works with multiple animation controllers', (tester) async {
      AnimationController? controller1;
      AnimationController? controller2;
      AnimationController? controller3;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useTickerProvider();
          controller1 = useAnimationController(
            vsync: vsync,
            duration: const Duration(milliseconds: 100),
          );
          controller2 = useAnimationController(
            vsync: vsync,
            duration: const Duration(milliseconds: 200),
          );
          controller3 = useAnimationController(
            vsync: vsync,
            duration: const Duration(milliseconds: 300),
          );
          return () => Text('Test');
        }),
      ));

      expect(controller1, isNotNull);
      expect(controller2, isNotNull);
      expect(controller3, isNotNull);
      expect(controller1!.duration, const Duration(milliseconds: 100));
      expect(controller2!.duration, const Duration(milliseconds: 200));
      expect(controller3!.duration, const Duration(milliseconds: 300));

      // All should be cleaned up correctly on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates ticker mode on TickerMode change', (tester) async {
      Ticker? ticker1;
      Ticker? ticker2;
      bool? initialMuted1;
      bool? initialMuted2;

      final toTestWidget = SetupBuilder(setup: (context) {
        final provider = useTickerProvider();
        if (ticker1 == null) {
          ticker1 = provider.createTicker((_) {});
          ticker2 = provider.createTicker((_) {});
          initialMuted1 = ticker1!.muted;
          initialMuted2 = ticker2!.muted;
        }
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: TickerMode(
          enabled: true,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(initialMuted1, isFalse);
      expect(initialMuted2, isFalse);
      expect(ticker1!.muted, isFalse);
      expect(ticker2!.muted, isFalse);

      // Change TickerMode to disabled - this should trigger _updateTickers()
      await tester.pumpWidget(MaterialApp(
        home: TickerMode(
          enabled: false,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // _updateTickers() should have been called, all tickers should be muted when TickerMode is disabled
      expect(ticker1, isNotNull);
      expect(ticker2, isNotNull);
      expect(ticker1!.muted, isTrue);
      expect(ticker2!.muted, isTrue);
    });

    testWidgets('updates on dependency change', (tester) async {
      Ticker? ticker1;
      Ticker? ticker2;

      final toTestWidget = SetupBuilder(setup: (context) {
        // Access InheritedWidget to trigger dependency tracking
        CounterInherited.of(context);
        final provider = useTickerProvider();
        ticker1 ??= provider.createTicker((_) {});
        ticker2 ??= provider.createTicker((_) {});
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 1,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state - tickers should not be muted
      expect(ticker1, isNotNull);
      expect(ticker2, isNotNull);
      expect(ticker1!.muted, isFalse);
      expect(ticker2!.muted, isFalse);

      // Change InheritedWidget value to trigger didChangeDependencies
      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 2,
          child: toTestWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Tickers should still work correctly
      expect(ticker1, isNotNull);
      expect(ticker2, isNotNull);
      expect(ticker1!.muted, isFalse);
      expect(ticker2!.muted, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

// Helper widget for testing dependency changes
class CounterInherited extends InheritedWidget {
  final int value;
  const CounterInherited({
    super.key,
    required this.value,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant CounterInherited oldWidget) {
    return oldWidget.value != value;
  }

  static CounterInherited of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CounterInherited>()!;
  }
}
