import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('Animation Hooks', () {
    testWidgets('useSingleTickerProvider creates provider', (tester) async {
      TickerProvider? provider;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          provider = useSingleTickerProvider();
          return (context) => const Text('Test');
        }),
      ));

      expect(provider, isNotNull);
      expect(provider, isA<TickerProvider>());
    });

    testWidgets('useSingleTickerProvider disposes correctly', (tester) async {
      Ticker? ticker;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final provider = useSingleTickerProvider();
          ticker = provider.createTicker((_) {});
          return (context) => const Text('Test');
        }),
      ));

      expect(ticker!.isActive, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Ticker should be cleaned up
      expect(tester.takeException(), isNull);
    });

    testWidgets('useAnimationController creates controller', (tester) async {
      AnimationController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useAnimationController(
            duration: const Duration(seconds: 1),
          );
          return (context) => const Text('Test');
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.duration, const Duration(seconds: 1));
    });

    testWidgets('useAnimationController with parameters', (tester) async {
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
          return (context) => Text('Value: ${controller!.value}');
        }),
      ));

      expect(controller!.value, 1.0);
      expect(controller!.lowerBound, 0.5);
      expect(controller!.upperBound, 1.5);
    });

    testWidgets('useAnimationController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useSingleTickerProvider();
          useAnimationController(
            vsync: vsync,
            duration: const Duration(seconds: 1),
          );
          return (context) => const Text('Test');
        }),
      ));

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Should have no exception (controller auto-disposed)
      expect(tester.takeException(), isNull);
    });

    testWidgets('useAnimationController reactive rendering', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final vsync = useSingleTickerProvider();
          final controller = useAnimationController(
            vsync: vsync,
            duration: const Duration(milliseconds: 100),
          );

          return (context) => AnimatedBuilder(
                animation: controller,
                builder: (context, child) => Text('${controller.isAnimating}'),
              );
        }),
      ));

      expect(find.text('false'), findsOneWidget);
    });

    testWidgets('multiple useSingleTickerProvider work correctly',
        (tester) async {
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

          return (context) => Text('Test');
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

    testWidgets('useSingleTickerProvider updates on dependency change',
        (tester) async {
      Ticker? ticker;

      final toTestWidget = SetupBuilder(setup: (context) {
        // Access InheritedWidget to trigger dependency tracking
        CounterInherited.of(context);
        final provider = useSingleTickerProvider();
        ticker = provider.createTicker((_) {});
        return (context) => const Text('Test');
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

    testWidgets(
        'useSingleTickerProvider updates ticker mode on TickerMode change',
        (tester) async {
      Ticker? ticker;
      bool? initialMuted;

      final toTestWidget = SetupBuilder(setup: (context) {
        final provider = useSingleTickerProvider();
        if (ticker == null) {
          ticker = provider.createTicker((_) {});
          initialMuted = ticker!.muted;
        }
        return (context) => const Text('Test');
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

    testWidgets(
        'useSingleTickerProvider _update called on multiple dependency changes',
        (tester) async {
      Ticker? ticker;

      final toTestWidget = SetupBuilder(setup: (context) {
        CounterInherited.of(context);
        final provider = useSingleTickerProvider();
        ticker ??= provider.createTicker((_) {});
        return (context) => const Text('Test');
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
