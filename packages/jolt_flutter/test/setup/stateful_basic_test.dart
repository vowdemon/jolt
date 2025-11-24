import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

void main() {
  group('SetupMixin Basic Functionality', () {
    testWidgets('create setup only once', (tester) async {
      int setupCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context, props) {
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
        home: _TestStatefulWidget(setup: (context, props) {
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
        home: _TestStatefulWidget(setup: (context, props) {
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
        home: _TestStatefulWidget(setup: (context, props) {
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
            home: _TestStatefulWidget(setup: (context, props) {
              onDidUpdateWidget(() => updateCount++);
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

      final theme = ThemeData.dark().toSignal();

      await tester.pumpWidget(JoltBuilder(builder: (context) {
        return MaterialApp(
          theme: theme.value,
          home: Builder(builder: (context) {
            return _TestStatefulWidget(setup: (context, props) {
              onDidUpdateWidget(() => updateCount++);
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
      final toTestWidget = _TestStatefulWidget(setup: (context, props) {
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

      final testWidget = _TestStatefulWidget(setup: (context, props) {
        onActivated(() => activated = true);
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();
      // Note: activate() is protected in StatefulWidget, so we can only verify
      // that the callback is registered. The actual activation happens during
      // widget lifecycle management by Flutter framework.
      expect(activated, isFalse);
    });

    testWidgets('onDeactivated lifecycle', (tester) async {
      bool deactivated = false;

      final testWidget = _TestStatefulWidget(setup: (context, props) {
        onDeactivated(() => deactivated = true);
        return () => const Text('Test');
      });

      await tester.pumpWidget(MaterialApp(
        home: testWidget,
      ));
      await tester.pumpAndSettle();
      expect(deactivated, isFalse);

      // Deactivation happens when widget is removed from tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(deactivated, isTrue);
    });

    testWidgets('onActivated and onDeactivated lifecycle together',
        (tester) async {
      int activatedCount = 0;
      int deactivatedCount = 0;

      final testWidget = _TestStatefulWidget(setup: (context, props) {
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

      // Deactivation happens when widget is removed from tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(deactivatedCount, 1);
    });

    testWidgets('useContext retrieves correctly', (tester) async {
      BuildContext? captured;

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context, props) {
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
        home: _TestStatefulWidget(setup: (context, props) {
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
        home: _PropsStatefulWidget(title: 'Initial', count: 0),
      ));

      expect(find.text('Title: Initial'), findsOneWidget);
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: _PropsStatefulWidget(title: 'Updated', count: 100),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Title: Updated'), findsOneWidget);
      expect(find.text('Count: 100'), findsOneWidget);
    });

    testWidgets('useProps multiple updates', (tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(MaterialApp(
          home: _PropsStatefulWidget(title: 'Round ${i + 1}', count: i + 1),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Title: Round ${i + 1}'), findsOneWidget);
        expect(find.text('Count: ${i + 1}'), findsOneWidget);
      }
    });

    testWidgets('multiple lifecycle callbacks', (tester) async {
      final mounted = <int>[], unmounted = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context, props) {
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

    testWidgets('context.props provides access to widget', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: _ContextPropsStatefulWidget(message: 'Hello', value: 42),
      ));

      expect(find.text('Message: Hello'), findsOneWidget);
      expect(find.text('Value: 42'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(
        home: _ContextPropsStatefulWidget(message: 'World', value: 100),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Message: World'), findsOneWidget);
      expect(find.text('Value: 100'), findsOneWidget);
    });
  });
}

// Helper widget for testing SetupMixin
class _TestStatefulWidget extends StatefulWidget {
  final WidgetFunction<_TestStatefulWidget> Function(
      BuildContext, _TestStatefulWidget) setup;

  const _TestStatefulWidget({required this.setup});

  @override
  State<_TestStatefulWidget> createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<_TestStatefulWidget>
    with SetupMixin<_TestStatefulWidget> {
  @override
  setup(context) => widget.setup(context, props);
}

// Helper widget for testing useProps reactive behavior
class _PropsStatefulWidget extends StatefulWidget {
  final String title;
  final int count;

  const _PropsStatefulWidget({required this.title, required this.count});

  @override
  State<_PropsStatefulWidget> createState() => _PropsStatefulWidgetState();
}

class _PropsStatefulWidgetState extends State<_PropsStatefulWidget>
    with SetupMixin<_PropsStatefulWidget> {
  @override
  setup(context) {
    return () => Column(children: [
          Text('Title: ${props.title}'),
          Text('Count: ${props.count}'),
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

class _ContextPropsStatefulWidget extends StatefulWidget {
  final String message;
  final int value;

  const _ContextPropsStatefulWidget({
    required this.message,
    required this.value,
  });

  @override
  State<_ContextPropsStatefulWidget> createState() =>
      _ContextPropsStatefulWidgetState();
}

class _ContextPropsStatefulWidgetState
    extends State<_ContextPropsStatefulWidget>
    with SetupMixin<_ContextPropsStatefulWidget> {
  @override
  setup(context) {
    return () => Column(children: [
          Text('Message: ${props.message}'),
          Text('Value: ${props.value}'),
        ]);
  }
}
