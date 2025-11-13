import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';

void main() {
  group('JoltSetupWidget Basic Functionality', () {
    testWidgets('creates and renders', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          return (context) => Column(children: const [
                Text('Title: Test'),
                Text('Count: 42'),
              ]);
        }),
      ));

      expect(find.text('Title: Test'), findsOneWidget);
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('onMounted lifecycle', (tester) async {
      bool mounted = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          onMounted(() => mounted = true);
          return (context) => const Text('Test');
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
          return (context) => const Text('Test');
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

      Widget buildWidget(String title) => MaterialApp(
            home: SetupBuilder(setup: (context) {
              onUpdated(() => updateCount++);
              return (context) => Text(title);
            }),
          );

      await tester.pumpWidget(buildWidget('Initial'));
      await tester.pumpAndSettle();
      expect(updateCount, 0);

      await tester.pumpWidget(buildWidget('Updated'));
      await tester.pumpAndSettle();
      expect(updateCount, 1);
    });

    testWidgets('useContext retrieves correctly', (tester) async {
      BuildContext? captured;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          captured = useContext();
          return (context) => const Text('Test');
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
          return (context) => const Text('Test');
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
          return (context) => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();
      expect(mounted, [1, 2, 3]);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(unmounted, [1, 2, 3]);
    });
  });
}

// Helper widget for testing useProps reactive behavior
class _PropsWidget extends JoltSetupWidget {
  final String title;
  final int count;
  const _PropsWidget({required this.title, required this.count});

  @override
  Widget Function(BuildContext context) setup(BuildContext context) {
    final props = useProps();
    return (context) => Column(children: [
          Text('Title: ${props.value.title}'),
          Text('Count: ${props.value.count}'),
        ]);
  }
}
