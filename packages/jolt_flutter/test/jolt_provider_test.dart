import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

// Test store class
class _TestStore extends JoltState {
  _TestStore(this.context);

  final BuildContext context;

  final counter = Signal(0);
  bool mounted = false;
  bool unmounted = false;

  @override
  void onMount(BuildContext context) {
    super.onMount(context);
    mounted = true;
  }

  @override
  void onUnmount(BuildContext context) {
    super.onUnmount(context);
    unmounted = true;
  }
}

// Simple store without JoltState
class _SimpleStore {
  final counter = Signal(0);
}

// Const store
class _ConstStore {
  final String value;

  const _ConstStore(this.value);
}

void main() {
  group('JoltProvider Tests', () {
    testWidgets('should render with initial store value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => _SimpleStore()..counter.value = 5,
            builder: (context, store) => Text('Count: ${store.counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('should call onMount after mount', (tester) async {
      _TestStore? store;
      BuildContext? mountContext;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_TestStore>(
            create: (context) {
              store = _TestStore(context);
              mountContext = context;
              return store!;
            },
            builder: (context, s) => Text('Count: ${s.counter.value}'),
          ),
        ),
      );

      expect(store, isNotNull);
      expect(store!.mounted, isTrue);

      await tester.pumpAndSettle();

      expect(store!.mounted, isTrue);
      expect(store!.unmounted, isFalse);
      expect(store!.context, equals(mountContext));
    });

    testWidgets('should call onUnmount when unmounted', (tester) async {
      _TestStore? store;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_TestStore>(
            create: (context) {
              store = _TestStore(context);
              return store!;
            },
            builder: (context, s) => Text('Count: ${s.counter.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(store!.mounted, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(store!.unmounted, isTrue);
      store!.counter.dispose();
    });

    testWidgets('should provide store via context.of<T>()', (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) => Builder(
              builder: (context) {
                final provided = JoltProvider.of<_SimpleStore>(context);
                expect(identical(provided, store), isTrue);
                return Text('Count: ${provided.counter.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should provide store to descendant widgets', (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) => Column(
              children: [
                Text('Provider: ${s.counter.value}'),
                Builder(
                  builder: (context) {
                    final provided = JoltProvider.of<_SimpleStore>(context);
                    return Text('Child: ${provided.counter.value}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Provider: 0'), findsOneWidget);
      expect(find.text('Child: 0'), findsOneWidget);
    });

    testWidgets('should work with maybeOf', (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) => Builder(
              builder: (context) {
                final provided = JoltProvider.maybeOf<_SimpleStore>(context);
                expect(provided, isNotNull);
                expect(identical(provided, store), isTrue);
                return Text('Count: ${provided!.counter.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('maybeOf should return null when not found', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final provided = JoltProvider.maybeOf<_SimpleStore>(context);
              expect(provided, isNull);
              return const Text('No Provider');
            },
          ),
        ),
      );

      expect(find.text('No Provider'), findsOneWidget);
    });

    testWidgets('should recreate store when create function changes',
        (tester) async {
      _TestStore? store1;
      _TestStore? store2;

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            store1 = _TestStore(context);
            return store1!;
          },
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(store1, isNotNull);
      expect(store1!.mounted, isTrue);

      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            store2 = _TestStore(context);
            return store2!;
          },
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(store1!.unmounted, isTrue);
      expect(store2, isNotNull);
      expect(store2!.mounted, isTrue);
      expect(store2!.unmounted, isFalse);

      store1!.counter.dispose();
      store2!.counter.dispose();
    });

    testWidgets('should not recreate store for const instances',
        (tester) async {
      const constStore = _ConstStore('value');

      Widget widget = MaterialApp(
        home: JoltProvider<_ConstStore>(
          create: (context) => constStore,
          builder: (context, s) => Text('Value: ${s.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Value: value'), findsOneWidget);

      widget = MaterialApp(
        home: JoltProvider<_ConstStore>(
          create: (context) => constStore,
          builder: (context, s) => Text('Value: ${s.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Value: value'), findsOneWidget);
    });

    testWidgets(
        'should dispose resources correctly and stop responding after unmount',
        (tester) async {
      _TestStore? store;
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_TestStore>(
            create: (context) {
              store = _TestStore(context);
              return store!;
            },
            builder: (context, s) {
              buildCount++;
              return Text('Count: ${s.counter.value}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(buildCount, greaterThan(0));
      final initialBuildCount = buildCount;

      store!.counter.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(store!.unmounted, isTrue);
      final buildCountBeforeUnmount = buildCount;

      store!.counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, equals(buildCountBeforeUnmount));

      store!.counter.dispose();
    });

    testWidgets('should handle nested JoltProvider', (tester) async {
      final outerStore = _SimpleStore();
      final innerStore = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => outerStore,
            builder: (context, outer) => JoltProvider<_SimpleStore>(
              create: (context) => innerStore,
              builder: (context, inner) => Builder(
                builder: (context) {
                  final providedOuter = JoltProvider.of<_SimpleStore>(context);
                  expect(identical(providedOuter, inner), isTrue);
                  return Column(
                    children: [
                      Text('Outer: ${outer.counter.value}'),
                      Text('Inner: ${inner.counter.value}'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Outer: 0'), findsOneWidget);
      expect(find.text('Inner: 0'), findsOneWidget);
    });

    testWidgets('should work with JoltBuilder', (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) => JoltBuilder(
              builder: (context) {
                final provided = JoltProvider.of<_SimpleStore>(context);
                return Text('Count: ${provided.counter.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      store.counter.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
    });

    testWidgets('should rebuild when store signal changes', (tester) async {
      final store = _SimpleStore();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) {
              buildCount++;
              return Text('Count: ${s.counter.value}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;
      expect(find.text('Count: 0'), findsOneWidget);

      store.counter.value = 5;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('should handle batch updates', (tester) async {
      final store = _SimpleStore();
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) {
              buildCount++;
              return Text('Count: ${s.counter.value}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      batch(() {
        store.counter.value = 1;
        store.counter.value = 2;
        store.counter.value = 3;
      });

      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('should rebuild when any signal in store changes',
        (tester) async {
      final store = _SimpleStore();
      final name = Signal('A');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            create: (context) => store,
            builder: (context, s) {
              buildCount++;
              return Text('Count: ${s.counter.value}, Name: $name');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      store.counter.value = 10;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 10, Name: A'), findsOneWidget);

      name.value = 'B';
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount + 1));
      expect(find.text('Count: 10, Name: B'), findsOneWidget);

      name.dispose();
    });

    testWidgets('should rebuild when widget updates', (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            key: const Key('provider1'),
            create: (context) => store,
            builder: (context, s) => Text('Count: ${s.counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            key: const Key('provider2'),
            create: (context) => store,
            builder: (context, s) => Text('New Count: ${s.counter.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Count: 0'), findsOneWidget);
    });

    testWidgets(
        'should not recreate store when create function reference unchanged',
        (tester) async {
      _TestStore? store;
      _TestStore createFn(BuildContext context) {
        store = _TestStore(context);
        return store!;
      }

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: createFn,
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      final firstStore = store;
      expect(firstStore, isNotNull);
      expect(firstStore!.mounted, isTrue);

      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: createFn,
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(identical(store, firstStore), isTrue);
      expect(store!.unmounted, isFalse);

      store!.counter.dispose();
    });

    testWidgets('should create store when create changes from null to value',
        (tester) async {
      _TestStore? store;

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: null,
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Count: 0'), findsNothing);

      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            store = _TestStore(context);
            return store!;
          },
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(store, isNotNull);
      expect(store!.mounted, isTrue);
      expect(find.text('Count: 0'), findsOneWidget);

      store!.counter.dispose();
    });

    testWidgets('should handle store when create changes from value to null',
        (tester) async {
      _TestStore? store;

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            store = _TestStore(context);
            return store!;
          },
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(store, isNotNull);
      expect(store!.mounted, isTrue);
      expect(find.text('Count: 0'), findsOneWidget);

      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: null,
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(store!.unmounted, isTrue);
      expect(find.text('Count: 0'), findsNothing);

      store!.counter.dispose();
    });
  });
}
