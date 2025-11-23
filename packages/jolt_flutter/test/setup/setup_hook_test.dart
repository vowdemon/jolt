import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';

/// A test hook that tracks all lifecycle method calls
class _TestLifecycleHook extends SetupHook<String> {
  _TestLifecycleHook(this.tracker);

  final _LifecycleTracker tracker;

  @override
  String build() => 'initial';

  @override
  void mount() {
    tracker.mountCount++;
    tracker.mountOrder.add('mount');
  }

  @override
  void unmount() {
    tracker.unmountCount++;
    tracker.unmountOrder.add('unmount');
  }

  @override
  void didUpdateWidget() {
    tracker.updateCount++;
    tracker.updateOrder.add('update');
  }

  @override
  void reassemble() {
    tracker.reassembleCount++;
    tracker.reassembleOrder.add('reassemble');
  }

  @override
  void didChangeDependencies() {
    tracker.dependenciesChangeCount++;
    tracker.dependenciesChangeOrder.add('dependenciesChange');
  }

  @override
  void activated() {
    tracker.activatedCount++;
    tracker.activatedOrder.add('activated');
  }

  @override
  void deactivated() {
    tracker.deactivatedCount++;
    tracker.deactivatedOrder.add('deactivated');
  }
}

/// Tracks lifecycle method calls for testing
class _LifecycleTracker {
  int mountCount = 0;
  int unmountCount = 0;
  int updateCount = 0;
  int reassembleCount = 0;
  int dependenciesChangeCount = 0;
  int activatedCount = 0;
  int deactivatedCount = 0;

  final List<String> mountOrder = [];
  final List<String> unmountOrder = [];
  final List<String> updateOrder = [];
  final List<String> reassembleOrder = [];
  final List<String> dependenciesChangeOrder = [];
  final List<String> activatedOrder = [];
  final List<String> deactivatedOrder = [];

  void reset() {
    mountCount = 0;
    unmountCount = 0;
    updateCount = 0;
    reassembleCount = 0;
    dependenciesChangeCount = 0;
    activatedCount = 0;
    deactivatedCount = 0;
    mountOrder.clear();
    unmountOrder.clear();
    updateOrder.clear();
    reassembleOrder.clear();
    dependenciesChangeOrder.clear();
    activatedOrder.clear();
    deactivatedOrder.clear();
  }
}

void main() {
  group('SetupHook Lifecycle', () {
    testWidgets('mount is called on first build', (tester) async {
      final tracker = _LifecycleTracker();

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestLifecycleHook(tracker));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.mountOrder, ['mount']);
      expect(tracker.unmountCount, 0);
      expect(tracker.updateCount, 0);
      expect(tracker.activatedCount, 0);
      expect(tracker.deactivatedCount, 0);
    });

    testWidgets('unmount is called when widget is removed', (tester) async {
      final tracker = _LifecycleTracker();

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestLifecycleHook(tracker));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.unmountCount, 0);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.unmountCount, 1);
      expect(tracker.unmountOrder, ['unmount']);
    });

    testWidgets('update is called when widget is updated', (tester) async {
      final tracker = _LifecycleTracker();

      Widget buildWidget(String title) => MaterialApp(
            home: SetupBuilder(setup: (context) {
              useHook(_TestLifecycleHook(tracker));
              return () => Text(title);
            }),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.updateCount, 0);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.updateCount, 1);
      expect(tracker.updateOrder, ['update']);
    });

    testWidgets('dependenciesChange is called when dependencies change',
        (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        _TestInherited.of(context);
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 1,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.dependenciesChangeCount, 0);

      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 2,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.dependenciesChangeCount, 1);
      expect(tracker.dependenciesChangeOrder, ['dependenciesChange']);
    });

    testWidgets('activated is called when widget is activated', (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.activatedCount, 0);

      // Get the element and manually call activate
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        element.activate();
        expect(tracker.activatedCount, 1);
        expect(tracker.activatedOrder, ['activated']);
      }
    });

    testWidgets('deactivated is called when widget is deactivated',
        (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();

      expect(tracker.mountCount, 1);
      expect(tracker.deactivatedCount, 0);

      // Get the element and manually call deactivate
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        element.deactivate();
        expect(tracker.deactivatedCount, 1);
        expect(tracker.deactivatedOrder, ['deactivated']);
      }
    });

    testWidgets('activated and deactivated can be called multiple times',
        (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();

      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        // Test deactivate
        element.deactivate();
        expect(tracker.deactivatedCount, 1);
        expect(tracker.activatedCount, 0);

        // Test activate
        element.activate();
        expect(tracker.activatedCount, 1);
        expect(tracker.deactivatedCount, 1);

        // Test deactivate again
        element.deactivate();
        expect(tracker.deactivatedCount, 2);
        expect(tracker.activatedCount, 1);

        // Test activate again
        element.activate();
        expect(tracker.activatedCount, 2);
        expect(tracker.deactivatedCount, 2);

        expect(tracker.activatedOrder, ['activated', 'activated']);
        expect(tracker.deactivatedOrder, ['deactivated', 'deactivated']);
      }
    });

    testWidgets('all lifecycle methods are called in correct order',
        (tester) async {
      final tracker = _LifecycleTracker();

      final testWidget = SetupBuilder(setup: (context) {
        _TestInherited.of(context);
        useHook(_TestLifecycleHook(tracker));
        return () => const Text('Test');
      });

      // Mount
      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 1,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Update
      await tester.pumpWidget(MaterialApp(
        home: _TestInherited(
          value: 2,
          child: testWidget,
        ),
      ));
      await tester.pumpAndSettle();

      // Get element for manual lifecycle calls
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        // Dependencies change
        element.didChangeDependencies();

        // Deactivate
        element.deactivate();

        // Activate
        element.activate();

        // Unmount
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Verify order
        expect(tracker.mountOrder, ['mount']);
        expect(tracker.updateOrder, ['update']);
        expect(tracker.dependenciesChangeOrder.length, greaterThan(0));
        expect(tracker.deactivatedOrder, ['deactivated']);
        expect(tracker.activatedOrder, ['activated']);
        expect(tracker.unmountOrder, ['unmount']);
      }
    });

    testWidgets('multiple hooks are called in order', (tester) async {
      final tracker1 = _LifecycleTracker();
      final tracker2 = _LifecycleTracker();
      final tracker3 = _LifecycleTracker();

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestLifecycleHook(tracker1));
          useHook(_TestLifecycleHook(tracker2));
          useHook(_TestLifecycleHook(tracker3));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(tracker1.mountCount, 1);
      expect(tracker2.mountCount, 1);
      expect(tracker3.mountCount, 1);

      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        element.activate();
        element.deactivate();

        expect(tracker1.activatedCount, 1);
        expect(tracker2.activatedCount, 1);
        expect(tracker3.activatedCount, 1);
        expect(tracker1.deactivatedCount, 1);
        expect(tracker2.deactivatedCount, 1);
        expect(tracker3.deactivatedCount, 1);
      }

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Unmount should be called in reverse order
      expect(tracker1.unmountCount, 1);
      expect(tracker2.unmountCount, 1);
      expect(tracker3.unmountCount, 1);
    });

    testWidgets('hook state persists across rebuilds', (tester) async {
      final tracker = _LifecycleTracker();
      String? capturedState;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final hook = useHook(_TestLifecycleHook(tracker));
          capturedState = hook;
          return () => Text('State: $hook');
        }),
      ));
      await tester.pumpAndSettle();

      final firstState = capturedState;

      // Rebuild
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final hook = useHook(_TestLifecycleHook(tracker));
          capturedState = hook;
          return () => Text('State: $hook');
        }),
      ));
      await tester.pumpAndSettle();

      // State should be the same (hook is reused)
      expect(capturedState, firstState);
      expect(tracker.mountCount, 1); // Only mounted once
      expect(tracker.updateCount, 1); // Updated once
    });

    testWidgets('hook context is available', (tester) async {
      BuildContext? capturedContext;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useHook(_TestContextHook((ctx) {
            capturedContext = ctx;
          }));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(capturedContext, isNotNull);
      expect(capturedContext, isA<BuildContext>());
    });
  });
}

/// A test hook that captures context
class _TestContextHook extends SetupHook<String> {
  _TestContextHook(this.onContext);

  final void Function(BuildContext) onContext;

  @override
  String build() {
    onContext(context);
    return 'test';
  }
}

/// Helper InheritedWidget for testing dependencies change
class _TestInherited extends InheritedWidget {
  final int value;

  const _TestInherited({
    required this.value,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _TestInherited oldWidget) {
    return oldWidget.value != value;
  }

  static _TestInherited of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TestInherited>()!;
  }
}
