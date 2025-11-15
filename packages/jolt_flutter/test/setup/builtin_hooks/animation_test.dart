import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';

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
          final vsync = useSingleTickerProvider();
          controller = useAnimationController(
            vsync: vsync,
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
  });
}
