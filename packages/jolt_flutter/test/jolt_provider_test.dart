import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

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

// Disposable store without JoltState
class _DisposableStore implements Disposable {
  final counter = Signal(0);
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    counter.dispose();
  }
}

// Store that implements both JoltState and Disposable
class _DisposableJoltStateStore extends JoltState implements Disposable {
  _DisposableJoltStateStore(this.context);

  final BuildContext context;

  final counter = Signal(0);
  bool mounted = false;
  bool unmounted = false;
  bool disposed = false;

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

  @override
  void dispose() {
    disposed = true;
    counter.dispose();
  }
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

    testWidgets(
        'should ignore create function change when value is already initialized',
        (tester) async {
      _TestStore? store1;
      _TestStore? store2;
      final key = GlobalKey();

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          key: key,
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
      expect(store1!.unmounted, isFalse);

      // Change create function but use same key (same element)
      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          key: key,
          create: (context) {
            store2 = _TestStore(context);
            return store2!;
          },
          builder: (context, s) => Text('Count: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Store1 should still be used (not recreated) because value was already initialized
      expect(store1!.unmounted, isFalse);
      expect(store2, isNull); // New create function should not be called
      expect(find.text('Count: 0'), findsOneWidget);

      store1!.counter.dispose();
    });

    testWidgets('should work with value parameter', (tester) async {
      _TestStore? store;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              store = _TestStore(context);
              // Reset states
              store!.mounted = false;
              store!.unmounted = false;
              return JoltProvider<_TestStore>(
                value: store!,
                builder: (context, s) => Text('Count: ${s.counter.value}'),
              );
            },
          ),
        ),
      );

      // Should not call onMount when using value
      expect(store!.mounted, isFalse);
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(store!.mounted, isFalse);
      expect(store!.unmounted, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Should not call onUnmount when using value
      expect(store!.unmounted, isFalse);
      store!.counter.dispose();
    });

    testWidgets('should not call lifecycle for value parameter',
        (tester) async {
      final store = _SimpleStore();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltProvider<_SimpleStore>(
            value: store,
            builder: (context, s) => Text('Count: ${s.counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      store.counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Store should still work (not disposed)
      store.counter.value = 10;
      expect(store.counter.value, equals(10));
      store.counter.dispose();
    });

    testWidgets('should switch from create to value', (tester) async {
      _TestStore? createdStore;
      _TestStore? valueStore;

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            createdStore = _TestStore(context);
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.mounted, isTrue);
      expect(createdStore!.unmounted, isFalse);

      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _TestStore(context);
            valueStore!.mounted = false;
            valueStore!.unmounted = false;
            return JoltProvider<_TestStore>(
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be unmounted and disposed
      expect(createdStore!.unmounted, isTrue);
      // Value store should not have lifecycle called
      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      createdStore!.counter.dispose();
      valueStore!.counter.dispose();
    });

    testWidgets('should switch from value to new value', (tester) async {
      _TestStore? valueStore1;
      _TestStore? valueStore2;

      Widget widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore1 = _TestStore(context);
            valueStore1!.mounted = false;
            valueStore1!.unmounted = false;
            return JoltProvider<_TestStore>(
              value: valueStore1!,
              builder: (context, s) => Text('Value1: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(valueStore1!.mounted, isFalse);
      expect(valueStore1!.unmounted, isFalse);
      expect(find.text('Value1: 0'), findsOneWidget);

      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore2 = _TestStore(context);
            valueStore2!.mounted = false;
            valueStore2!.unmounted = false;
            return JoltProvider<_TestStore>(
              value: valueStore2!,
              builder: (context, s) => Text('Value2: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Old value store should not have lifecycle called
      expect(valueStore1!.mounted, isFalse);
      expect(valueStore1!.unmounted, isFalse);
      // New value store should not have lifecycle called
      expect(valueStore2!.mounted, isFalse);
      expect(valueStore2!.unmounted, isFalse);
      expect(find.text('Value2: 0'), findsOneWidget);

      valueStore1!.counter.dispose();
      valueStore2!.counter.dispose();
    });

    testWidgets('should switch from value to create', (tester) async {
      _TestStore? valueStore;
      _TestStore? createdStore;

      Widget widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _TestStore(context);
            valueStore!.mounted = false;
            valueStore!.unmounted = false;
            return JoltProvider<_TestStore>(
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            createdStore = _TestStore(context);
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Value store should not have lifecycle called (not managed by provider)
      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      // Created store should be mounted
      expect(createdStore, isNotNull);
      expect(createdStore!.mounted, isTrue);
      expect(createdStore!.unmounted, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      valueStore!.counter.dispose();
      createdStore!.counter.dispose();
    });

    testWidgets('should handle value parameter with JoltState but no lifecycle',
        (tester) async {
      _TestStore? store;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              store = _TestStore(context);
              store!.mounted = false;
              store!.unmounted = false;
              return JoltProvider<_TestStore>(
                value: store!,
                builder: (context, s) => Text('Count: ${s.counter.value}'),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(store!.mounted, isFalse);
      expect(store!.unmounted, isFalse);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Still should not call lifecycle
      expect(store!.mounted, isFalse);
      expect(store!.unmounted, isFalse);
      store!.counter.dispose();
    });

    testWidgets(
        'should dispose old Disposable resource when switching from create to value',
        (tester) async {
      _DisposableStore? createdStore;
      _DisposableStore? valueStore;

      Widget widget = MaterialApp(
        home: JoltProvider<_DisposableStore>(
          create: (context) {
            createdStore = _DisposableStore();
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.disposed, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _DisposableStore();
            return JoltProvider<_DisposableStore>(
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be disposed when switching from create to value
      expect(createdStore!.disposed, isTrue);
      // Value store should not be disposed
      expect(valueStore!.disposed, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      valueStore!.counter.dispose();
    });

    testWidgets(
        'should dispose old JoltState resource when switching from create to value',
        (tester) async {
      _TestStore? createdStore;
      _TestStore? valueStore;

      Widget widget = MaterialApp(
        home: JoltProvider<_TestStore>(
          create: (context) {
            createdStore = _TestStore(context);
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.mounted, isTrue);
      expect(createdStore!.unmounted, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _TestStore(context);
            valueStore!.mounted = false;
            valueStore!.unmounted = false;
            return JoltProvider<_TestStore>(
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be unmounted when switching from create to value
      expect(createdStore!.unmounted, isTrue);
      // Value store should not have lifecycle called
      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      createdStore!.counter.dispose();
      valueStore!.counter.dispose();
    });

    testWidgets(
        'should dispose old DisposableJoltState resource when switching from create to value',
        (tester) async {
      _DisposableJoltStateStore? createdStore;
      _DisposableJoltStateStore? valueStore;

      Widget widget = MaterialApp(
        home: JoltProvider<_DisposableJoltStateStore>(
          create: (context) {
            createdStore = _DisposableJoltStateStore(context);
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.mounted, isTrue);
      expect(createdStore!.unmounted, isFalse);
      expect(createdStore!.disposed, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _DisposableJoltStateStore(context);
            valueStore!.mounted = false;
            valueStore!.unmounted = false;
            valueStore!.disposed = false;
            return JoltProvider<_DisposableJoltStateStore>(
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be unmounted and disposed when switching from create to value
      expect(createdStore!.unmounted, isTrue);
      expect(createdStore!.disposed, isTrue);
      // Value store should not have lifecycle called
      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      expect(valueStore!.disposed, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      valueStore!.counter.dispose();
    });

    testWidgets(
        'should cleanup old resource when switching from create to value in update method',
        (tester) async {
      _DisposableJoltStateStore? createdStore;
      _DisposableJoltStateStore? valueStore;
      final key = GlobalKey();

      // Use the same widget key to ensure update() is called
      Widget widget = MaterialApp(
        home: JoltProvider<_DisposableJoltStateStore>(
          key: key,
          create: (context) {
            createdStore = _DisposableJoltStateStore(context);
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.mounted, isTrue);
      expect(createdStore!.unmounted, isFalse);
      expect(createdStore!.disposed, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      // Update the same widget instance by changing from create to value
      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _DisposableJoltStateStore(context);
            valueStore!.mounted = false;
            valueStore!.unmounted = false;
            valueStore!.disposed = false;
            return JoltProvider<_DisposableJoltStateStore>(
              key: key,
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be unmounted and disposed when switching from create to value
      // This tests the specific code path in update() method: if (switchingToValue && oldStore != null)
      expect(createdStore!.unmounted, isTrue);
      expect(createdStore!.disposed, isTrue);
      // Value store should not have lifecycle called
      expect(valueStore!.mounted, isFalse);
      expect(valueStore!.unmounted, isFalse);
      expect(valueStore!.disposed, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      valueStore!.counter.dispose();
    });

    testWidgets(
        'should cleanup old Disposable resource when switching from create to value in update method',
        (tester) async {
      _DisposableStore? createdStore;
      _DisposableStore? valueStore;
      final key = GlobalKey();

      // Use the same widget key to ensure update() is called
      Widget widget = MaterialApp(
        home: JoltProvider<_DisposableStore>(
          key: key,
          create: (context) {
            createdStore = _DisposableStore();
            return createdStore!;
          },
          builder: (context, s) => Text('Created: ${s.counter.value}'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(createdStore, isNotNull);
      expect(createdStore!.disposed, isFalse);
      expect(find.text('Created: 0'), findsOneWidget);

      // Update the same widget instance by changing from create to value
      widget = MaterialApp(
        home: Builder(
          builder: (context) {
            valueStore = _DisposableStore();
            return JoltProvider<_DisposableStore>(
              key: key,
              value: valueStore!,
              builder: (context, s) => Text('Value: ${s.counter.value}'),
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Created store should be disposed when switching from create to value
      // This tests the specific code path in update() method: if (switchingToValue && oldStore != null)
      expect(createdStore!.disposed, isTrue);
      // Value store should not be disposed
      expect(valueStore!.disposed, isFalse);
      expect(find.text('Value: 0'), findsOneWidget);

      valueStore!.counter.dispose();
    });
  });
}
