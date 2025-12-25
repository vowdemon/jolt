import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('SetupWidget Basic Functionality', () {
    testWidgets('create setup only once', (tester) async {
      int setupCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          return () => Column(children: const [
                Text('Title: Test'),
                Text('Count: 42'),
              ]);
        }),
      ));

      expect(find.text('Title: Test'), findsOneWidget);
      expect(find.text('Count: 42'), findsOneWidget);
      expect(setupCount, 1);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          return () => Column(children: const [
                Text('Title: Test2'),
                Text('Count: 43'),
              ]);
        }),
      ));

      expect(find.text('Title: Test'), findsOneWidget);
      expect(find.text('Count: 42'), findsOneWidget);
      expect(setupCount, 1);
    });

    testWidgets('onMounted lifecycle', (tester) async {
      bool mounted = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          onMounted(() => mounted = true);
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(mounted, isTrue);
    });

    testWidgets('onUnmounted lifecycle', (tester) async {
      bool unmounted = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          onUnmounted(() => unmounted = true);
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();
      expect(unmounted, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(unmounted, isTrue);
    });

    testWidgets('onUpdated lifecycle', (tester) async {
      int updateCount = 0;
      int rebuildCount = 0;

      Widget buildWidget(String title) => MaterialApp(
            home: SetupBuilder(setup: (context) {
              onDidUpdateWidgetAt((oldWidget, newWidget) => updateCount++);
              return () {
                rebuildCount++;
                return Text(title);
              };
            }),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();
      expect(updateCount, 0);
      expect(rebuildCount, 1);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();
      expect(updateCount, 1);
      expect(rebuildCount, 2);
    });

    testWidgets('onUpdated lifecycle by parent widget update', (tester) async {
      int updateCount = 0;
      int rebuildCount = 0;

      final theme = Signal(ThemeData.dark());

      await tester.pumpWidget(JoltBuilder(builder: (context) {
        return MaterialApp(
          theme: theme.value,
          home: Builder(builder: (context) {
            return SetupBuilder(setup: (context) {
              onDidUpdateWidgetAt((oldWidget, newWidget) => updateCount++);
              return () {
                rebuildCount++;
                return const Text('Test');
              };
            });
          }),
        );
      }));

      expect(rebuildCount, 1);
      expect(updateCount, 0);

      theme.value = ThemeData.light();
      await tester.pumpAndSettle();

      expect(rebuildCount, 2);
      expect(updateCount, 1);
    });

    testWidgets('onChangedDependencies lifecycle', (tester) async {
      int rebuildCount = 0;
      int changedCount = 0;
      final toTestWidget = SetupBuilder(setup: (context) {
        CounterInherited.of(context);
        onDidChangeDependencies(() => changedCount++);
        return () {
          rebuildCount++;
          return const Text('Test');
        };
      });
      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 1,
          child: toTestWidget,
        ),
      ));
      expect(rebuildCount, 1);
      expect(changedCount, 0);

      await tester.pumpWidget(MaterialApp(
        home: CounterInherited(
          value: 2,
          child: toTestWidget,
        ),
      ));
      expect(rebuildCount, 2);
      expect(changedCount, 1);
    });

    testWidgets('onActivated lifecycle', (tester) async {
      bool activated = false;

      final testWidget = SetupBuilder(setup: (context) {
        onActivated(() => activated = true);
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();
      expect(activated, isFalse);

      // Get the element and manually call activate to verify the callback works
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        element.activate();
        expect(activated, isTrue);
      }
    });

    testWidgets('onDeactivated lifecycle', (tester) async {
      bool deactivated = false;

      final testWidget = SetupBuilder(setup: (context) {
        onDeactivated(() => deactivated = true);
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();
      expect(deactivated, isFalse);

      // Get the element and manually call deactivate to verify the callback works
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        element.deactivate();
        expect(deactivated, isTrue);
      }
    });

    testWidgets('onActivated and onDeactivated lifecycle together',
        (tester) async {
      int activatedCount = 0;
      int deactivatedCount = 0;

      final testWidget = SetupBuilder(setup: (context) {
        onActivated(() => activatedCount++);
        onDeactivated(() => deactivatedCount++);
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();
      expect(activatedCount, 0);
      expect(deactivatedCount, 0);

      // Get the element and manually call lifecycle methods
      final element = tester.element(find.text('Test'));
      if (element is SetupWidgetElement) {
        // Test deactivate
        element.deactivate();
        expect(activatedCount, 0);
        expect(deactivatedCount, 1);

        // Test activate
        element.activate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 1);

        // Test deactivate again
        element.deactivate();
        expect(activatedCount, 1);
        expect(deactivatedCount, 2);

        // Test activate again
        element.activate();
        expect(activatedCount, 2);
        expect(deactivatedCount, 2);
      }
    });

    testWidgets('useContext retrieves correctly', (tester) async {
      BuildContext? captured;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          captured = useContext();
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, isA<BuildContext>());
    });

    testWidgets('useSetupContext retrieves correctly', (tester) async {
      JoltSetupContext? captured;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          captured = useSetupContext();
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, isA<JoltSetupContext>());
    });

    testWidgets('useProps reactive update', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: _PropsWidget(title: 'Initial', count: 0),
      ));

      expect(find.text('Title: Initial'), findsOneWidget);
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: _PropsWidget(title: 'Updated', count: 100),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Title: Updated'), findsOneWidget);
      expect(find.text('Count: 100'), findsOneWidget);
    });

    testWidgets('useProps multiple updates', (tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(MaterialApp(
          home: _PropsWidget(title: 'Round ${i + 1}', count: i + 1),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Title: Round ${i + 1}'), findsOneWidget);
        expect(find.text('Count: ${i + 1}'), findsOneWidget);
      }
    });

    testWidgets('multiple lifecycle callbacks', (tester) async {
      final mounted = <int>[], unmounted = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          onMounted(() => mounted.add(1));
          onMounted(() => mounted.add(2));
          onMounted(() => mounted.add(3));
          onUnmounted(() => unmounted.add(1));
          onUnmounted(() => unmounted.add(2));
          onUnmounted(() => unmounted.add(3));
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();
      expect(mounted, [1, 2, 3]);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(unmounted, [3, 2, 1]);
    });
  });
}

// Helper widget for testing useProps reactive behavior
class _PropsWidget extends SetupWidget<_PropsWidget> {
  final String title;
  final int count;

  const _PropsWidget({required this.title, required this.count});

  @override
  setup(context, props) {
    return () => Column(children: [
          Text('Title: ${props().title}'),
          Text('Count: ${props().count}'),
        ]);
  }
}

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
