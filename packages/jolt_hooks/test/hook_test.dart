import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'package:jolt_hooks/jolt_hooks.dart';

void main() {
  group('useSignal', () {
    testWidgets('useSignal: get and set value', (WidgetTester tester) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final state = useSignal(123);

            return GestureDetector(
              onTap: () => state.value++,
              child: JoltBuilder(
                builder: (context) {
                  return Text('$state', textDirection: TextDirection.ltr);
                },
              ),
            );
          },
        ),
      );

      expect(find.text('123'), findsOneWidget);
      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();
      expect(find.text('124'), findsOneWidget);
    });
  });

  group('useComputed', () {
    testWidgets('useComputed: get and update value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(123);
            final computed = useComputed(() => signal.value * 2);
            return GestureDetector(
              onTap: () => signal.value++,
              child: JoltBuilder(
                builder: (context) {
                  return Text('$computed', textDirection: TextDirection.ltr);
                },
              ),
            );
          },
        ),
      );

      expect(find.text('246'), findsOneWidget);
      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();
      expect(find.text('248'), findsOneWidget);
    });
  });

  group('useWritableComputed', () {
    testWidgets('useWritableComputed: get and set value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(10);
            final writableComputed = useWritableComputed(
              () => signal.value * 2,
              (value) => signal.value = value ~/ 2,
            );

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Signal: ${signal.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Computed: ${writableComputed.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => writableComputed.value = 50,
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.blue,
                    child: const Text(
                      'Set to 50',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Signal: 10'), findsOneWidget);
      expect(find.text('Computed: 20'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('Signal: 25'), findsOneWidget);
      expect(find.text('Computed: 50'), findsOneWidget);
    });
  });

  group('useConvertComputed', () {
    testWidgets('useConvertComputed: type conversion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final source = useSignal(123);
            final converted = useConvertComputed(
              source,
              (int value) => 'Number: $value',
              (String value) => int.parse(value.split(': ')[1]),
            );

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Source: ${source.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Converted: ${converted.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => converted.value = 'Number: 999',
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.green,
                    child: const Text(
                      'Set to 999',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Source: 123'), findsOneWidget);
      expect(find.text('Converted: Number: 123'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('Source: 999'), findsOneWidget);
      expect(find.text('Converted: Number: 999'), findsOneWidget);
    });
  });

  group('usePersistSignal', () {
    testWidgets('usePersistSignal: persistence functionality', (
      WidgetTester tester,
    ) async {
      int storedValue = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final persistSignal = usePersistSignal(
              () => 100,
              () async => storedValue,
              (value) async => storedValue = value,
            );

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Value: ${persistSignal.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => persistSignal.value = 200,
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.orange,
                    child: const Text(
                      'Set to 200',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Value: 100'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('Value: 200'), findsOneWidget);
      expect(storedValue, equals(200));
    });
  });

  group('useAsyncSignal', () {
    testWidgets('useAsyncSignal: async state management', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final asyncSignal = useAsyncSignal(
              FutureSource(
                Future.delayed(const Duration(milliseconds: 100), () => 42),
              ),
            );

            return JoltBuilder(
              builder: (context) {
                final state = asyncSignal.value;
                return Text(
                  state.map(
                        loading: () => 'Loading...',
                        success: (data) => 'Data: $data',
                        error: (error, stackTrace) => 'Error: $error',
                      ) ??
                      'Unknown',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Data: 42'), findsOneWidget);
    });
  });

  group('useJoltEffect', () {
    testWidgets('useJoltEffect: side effects', (WidgetTester tester) async {
      int effectCount = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);

            useJoltEffect(() {
              effectCount++;
              // Access signal to create dependency
              signal.value;
            });

            return GestureDetector(
              onTap: () => signal.value++,
              child: JoltBuilder(
                builder: (context) {
                  return Text(
                    'Count: ${signal.value}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            );
          },
        ),
      );

      expect(effectCount, equals(1)); // Effect should run immediately

      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();

      expect(
        effectCount,
        equals(2),
      ); // Effect should run again when signal changes
    });
  });

  group('useJoltWatcher', () {
    testWidgets('useJoltWatcher: watch signal changes', (
      WidgetTester tester,
    ) async {
      int watchCount = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);

            useJoltWatcher(() => signal.value, (value, previousValue) {
              watchCount++;
            });

            return GestureDetector(
              onTap: () => signal.value++,
              child: JoltBuilder(
                builder: (context) {
                  return Text(
                    'Count: ${signal.value}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            );
          },
        ),
      );

      expect(
        watchCount,
        equals(0),
      ); // Watcher should not run immediately by default

      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();

      expect(watchCount, equals(1)); // Watcher should run when signal changes
    });
  });

  group('useJoltStream', () {
    testWidgets('useJoltStream: stream functionality', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);
            final stream = useJoltStream(signal);

            return StreamBuilder<int>(
              stream: stream,
              builder: (context, snapshot) {
                return Text(
                  'Stream: ${snapshot.data ?? 0}',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      expect(find.text('Stream: 0'), findsOneWidget);

      // This test would need more complex setup to test stream updates
      // For now, we just verify the stream is created
    });
  });

  group('useJoltEffectScope', () {
    testWidgets('useJoltEffectScope: effect scope management', (
      WidgetTester tester,
    ) async {
      int scopeEffectCount = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);

            // Create an effect scope
            useJoltEffectScope(fn: (scope) {
              scopeEffectCount++;
              // Access signal within the scope
              signal.value;
            });

            return GestureDetector(
              onTap: () => signal.value++,
              child: JoltBuilder(
                builder: (context) {
                  return Text(
                    'Count: ${signal.value}',
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            );
          },
        ),
      );

      expect(scopeEffectCount, equals(1)); // Scope should be created

      // EffectScope doesn't automatically re-run when dependencies change
      // It only runs once when created
      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();

      expect(scopeEffectCount, equals(1)); // Scope should still be 1
    });
  });

  group('Collection Hooks', () {
    testWidgets('useListSignal: list operations', (WidgetTester tester) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final listSignal = useListSignal([1, 2, 3]);

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'List: ${listSignal.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    listSignal.add(4);
                  },
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.purple,
                    child: const Text(
                      'Add 4',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('List: [1, 2, 3]'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('List: [1, 2, 3, 4]'), findsOneWidget);
    });

    testWidgets('useMapSignal: map operations', (WidgetTester tester) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final mapSignal = useMapSignal({'a': 1, 'b': 2});

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Map: ${mapSignal.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    mapSignal['c'] = 3;
                  },
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.red,
                    child: const Text(
                      'Add c:3',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Map: {a: 1, b: 2}'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('Map: {a: 1, b: 2, c: 3}'), findsOneWidget);
    });

    testWidgets('useSetSignal: set operations', (WidgetTester tester) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final setSignal = useSetSignal({1, 2, 3});

            return Column(
              children: [
                JoltBuilder(
                  builder: (context) {
                    return Text(
                      'Set: ${setSignal.value}',
                      textDirection: TextDirection.ltr,
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    setSignal.add(4);
                  },
                  child: Container(
                    width: 100,
                    height: 50,
                    color: Colors.teal,
                    child: const Text(
                      'Add 4',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Set: {1, 2, 3}'), findsOneWidget);

      await tester.tap(find.byType(Container));
      await tester.pumpAndSettle();

      expect(find.text('Set: {1, 2, 3, 4}'), findsOneWidget);
    });

    testWidgets('useIterableSignal: iterable operations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final iterableSignal = useIterableSignal(
              () => [1, 2, 3].map((x) => x * 2),
            );

            return JoltBuilder(
              builder: (context) {
                return Text(
                  'Iterable: ${iterableSignal.toList()}',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      expect(find.text('Iterable: [2, 4, 6]'), findsOneWidget);
    });
  });

  group('useJoltWidget', () {
    testWidgets('should render with initial values', (tester) async {
      final counter = Signal(0);
      final name = Signal('Flutter');

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              return Text('Count: ${counter.value}, Name: ${name.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Flutter'), findsOneWidget);
    });

    testWidgets('should rebuild when signal changes', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              return Text('Count: ${counter.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(1));
      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('should respond to multiple signal changes', (tester) async {
      final counter = Signal(0);
      final name = Signal('A');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              return Text('Count: ${counter.value}, Name: ${name.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter.value = 10;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 10, Name: A'), findsOneWidget);

      name.value = 'B';
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount + 1));
      expect(find.text('Count: 10, Name: B'), findsOneWidget);
    });

    testWidgets('should respond to computed signal changes', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              return Text('Count: ${counter.value}, Doubled: ${doubled.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 5, Doubled: 10'), findsOneWidget);
    });

    testWidgets('should handle nested useJoltWidget with independent rebuilds',
        (tester) async {
      final outerSignal = Signal('Outer');
      final innerSignal = Signal('Inner');
      int outerBuildCount = 0;
      int innerBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              outerBuildCount++;
              return Column(
                children: [
                  Text('OuterOuter: ${outerSignal.value}'),
                  HookBuilder(builder: (context) {
                    return useJoltWidget(() {
                      innerBuildCount++;
                      return Column(
                        textDirection: TextDirection.ltr,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Outer: ${outerSignal.value}'),
                          Text('Inner: ${innerSignal.value}'),
                        ],
                      );
                    });
                  }),
                ],
              );
            }),
          ),
        ),
      );

      final initialOuterBuildCount = outerBuildCount;
      final initialInnerBuildCount = innerBuildCount;

      expect(outerBuildCount, equals(1));
      expect(innerBuildCount, equals(1));

      outerSignal.value = 'OuterUpdated';
      await tester.pumpAndSettle();

      expect(outerBuildCount, equals(initialOuterBuildCount + 1));
      expect(innerBuildCount, equals(initialInnerBuildCount + 1));

      expect(find.text('Outer: OuterUpdated'), findsOneWidget);

      innerSignal.value = 'InnerUpdated';
      await tester.pumpAndSettle();

      expect(outerBuildCount, equals(initialOuterBuildCount + 1));
      expect(innerBuildCount, equals(initialInnerBuildCount + 2));
      expect(find.text('Inner: InnerUpdated'), findsOneWidget);
    });

    testWidgets(
        'should dispose resources correctly and stop responding after unmount',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              return Text('Count: ${counter.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(buildCount, greaterThan(0));
      final initialBuildCount = buildCount;

      counter.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      final buildCountBeforeUnmount = buildCount;

      counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, equals(buildCountBeforeUnmount));
    });

    testWidgets('should handle batch updates', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              return Text('Count: ${counter.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      batch(() {
        counter.value = 1;
        counter.value = 2;
        counter.value = 3;
      });

      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('should work with keys parameter', (tester) async {
      final counter1 = Signal(0);
      final counter2 = Signal(10);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(
              () {
                buildCount++;
                return Text('Count: ${counter1.value}',
                    textDirection: TextDirection.ltr);
              },
              keys: [1],
            ),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter1.value = 5;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 5'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(
              () {
                buildCount++;
                return Text('Count: ${counter2.value}',
                    textDirection: TextDirection.ltr);
              },
              keys: [2],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
    });

    testWidgets('should rebuild when parent widget changes', (tester) async {
      final counter = Signal(0);
      Widget parent = MaterialApp(
        home: HookBuilder(
          builder: (context) => useJoltWidget(() {
            return Text('Count: ${counter.value}',
                textDirection: TextDirection.ltr);
          }),
        ),
      );

      await tester.pumpWidget(parent);

      expect(find.text('Count: 0'), findsOneWidget);

      parent = MaterialApp(
        theme: ThemeData(primaryColor: Colors.blue),
        home: HookBuilder(
          builder: (context) => useJoltWidget(() {
            return Text('Count: ${counter.value}',
                textDirection: TextDirection.ltr);
          }),
        ),
      );

      await tester.pumpWidget(parent);
      await tester.pumpAndSettle();

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('should handle signal changes in builder', (tester) async {
      final counter = Signal(0);
      final nestedCounter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              if (counter.value == 0) {
                nestedCounter.value = 50;
              }
              return Column(
                textDirection: TextDirection.ltr,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Count: ${counter.value}'),
                  Text('Nested: ${nestedCounter.value}'),
                ],
              );
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Nested: 50'), findsOneWidget);
    });

    testWidgets('should work with ListSignal', (tester) async {
      final listSignal = Signal(ListSignal<int>([1, 2, 3]));

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              return Text('List: ${listSignal.value.join(", ")}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      expect(find.text('List: 1, 2, 3'), findsOneWidget);

      listSignal.value.add(4);
      await tester.pumpAndSettle();

      expect(find.text('List: 1, 2, 3, 4'), findsOneWidget);
    });

    testWidgets('should work with MapSignal', (tester) async {
      final mapSignal = Signal(MapSignal<String, int>({'a': 1, 'b': 2}));

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              return Text(
                  'Map: ${mapSignal.value['a']}, ${mapSignal.value['b']}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      expect(find.text('Map: 1, 2'), findsOneWidget);

      mapSignal.value['c'] = 3;
      await tester.pumpAndSettle();

      expect(find.text('Map: 1, 2'), findsOneWidget);
      expect(mapSignal.value['c'], equals(3));
    });

    testWidgets('should handle external and internal signals', (tester) async {
      final outerSignal = Signal(0);
      late Signal<int> innerSignal;
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(builder: (context) {
            innerSignal = useSignal(0);
            return useJoltWidget(() {
              buildCount++;
              return Text(
                  'Outer: ${outerSignal.value}, Inner: ${innerSignal.value}',
                  textDirection: TextDirection.ltr);
            });
          }),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Outer: 0, Inner: 0'), findsOneWidget);

      outerSignal.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, equals(2));
      expect(find.text('Outer: 1, Inner: 0'), findsOneWidget);

      innerSignal.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, equals(3));
      expect(find.text('Outer: 1, Inner: 1'), findsOneWidget);
    });
  });
}
