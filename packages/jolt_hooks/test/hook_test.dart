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

    testWidgets('useSignal.lazy: creates signal without initial value',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final state = useSignal.lazy<String?>();

            return JoltBuilder(
              builder: (context) {
                return Text(
                  'Value: ${state.value ?? 'null'}',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);
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
            final writableComputed = useComputed.writable(
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

  group('useAsyncSignal', () {
    testWidgets('useAsyncSignal: async state management', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final asyncSignal = useSignal.async(
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
      await tester.pumpAndSettle();

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

    testWidgets(
        'useJoltEffect: with lazy=false runs immediately and on changes',
        (WidgetTester tester) async {
      int effectCount = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);

            useJoltEffect(() {
              effectCount++;
              signal.value;
            }, lazy: false);

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

      expect(effectCount, equals(1)); // Runs immediately when lazy=false

      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();

      expect(effectCount, equals(2)); // Runs again when dependency changes
    });

    testWidgets('useJoltEffect.lazy: does not run automatically',
        (WidgetTester tester) async {
      int effectCount = 0;
      late Effect effect;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(0);

            effect = useJoltEffect.lazy(() {
              effectCount++;
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

      expect(
          effectCount, equals(0)); // Does not run automatically when lazy=true

      // Signal changes but effect doesn't run automatically
      await tester.tap(find.byType(Text));
      await tester.pumpAndSettle();

      expect(effectCount, equals(0)); // Still doesn't run automatically

      // Manually run the effect
      effect.run();
      await tester.pumpAndSettle();

      expect(effectCount, equals(1)); // Runs when manually triggered
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

            useWatcher(() => signal.value, (value, previousValue) {
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

    testWidgets('useWatcher.immediately: executes immediately', (
      WidgetTester tester,
    ) async {
      int watchCount = 0;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(1);

            useWatcher.immediately(() => signal.value, (value, previousValue) {
              watchCount++;
            });

            return JoltBuilder(
              builder: (context) {
                return Text(
                  'Count: ${signal.value}',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(watchCount, greaterThanOrEqualTo(1)); // Should execute immediately
    });

    testWidgets('useWatcher.once: executes only once', (
      WidgetTester tester,
    ) async {
      int watchCount = 0;
      late Signal<int> signal;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            signal = useSignal(1);

            useWatcher.once(() => signal.value, (value, previousValue) {
              watchCount++;
            });

            return JoltBuilder(
              builder: (context) {
                return Text(
                  'Count: ${signal.value}',
                  textDirection: TextDirection.ltr,
                );
              },
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      signal.value = 2;
      await tester.pumpAndSettle();

      expect(watchCount, lessThanOrEqualTo(1)); // Should execute at most once
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
            useEffectScope(fn: (scope) {
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
            final listSignal = useSignal.list([1, 2, 3]);

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
            final mapSignal = useSignal.map({'a': 1, 'b': 2});

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
            final setSignal = useSignal.set({1, 2, 3});

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
            final iterableSignal = useSignal.iterable(
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

    testWidgets('should rebuild when modifying tracked signal in builder',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              // Read signal first to track it, then modify it
              final currentValue = counter.value;
              if (buildCount == 1 && currentValue == 0) {
                counter.value = 1;
              }
              return Text('Count: ${counter.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      await tester.pumpAndSettle();

      // Should have rebuilt automatically after signal change
      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 1'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle modifying multiple signals in builder',
        (tester) async {
      final counter = Signal(0);
      final name = Signal('A');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) => useJoltWidget(() {
              buildCount++;
              // Read signals first to track them, then modify them
              // ignore: unused_local_variable
              final currentCount = counter.value;
              // ignore: unused_local_variable
              final currentName = name.value;
              if (buildCount == 1) {
                counter.value = 10;
                name.value = 'B';
              }
              return Text('Count: ${counter.value}, Name: ${name.value}',
                  textDirection: TextDirection.ltr);
            }),
          ),
        ),
      );

      final initialBuildCount = buildCount;

      await tester.pumpAndSettle();

      // Should rebuild once after all signal changes (batched)
      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 10, Name: B'), findsOneWidget);

      counter.dispose();
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

    testWidgets('should rebuild when useState changes in useJoltWidget',
        (tester) async {
      int buildCount = 0;
      late ValueNotifier<int> countNotifier;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(builder: (context) {
            final count = useState(0);
            countNotifier = count;

            return useJoltWidget(() {
              buildCount++;
              // Access useState value directly in useJoltWidget
              // Note: useJoltWidget can only track Jolt reactive values,
              // so it won't automatically track useState changes
              // The widget will rebuild when parent HookBuilder rebuilds
              return Text('Count: ${count.value}',
                  textDirection: TextDirection.ltr);
            });
          }),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Count: 0'), findsOneWidget);

      // Change useState value
      countNotifier.value = 5;
      await tester.pumpAndSettle();

      // The widget will rebuild because HookBuilder rebuilds when useState changes
      // but useJoltWidget itself doesn't track useState directly
      expect(find.text('Count: 5'), findsOneWidget);

      // Change again
      countNotifier.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
    });

    testWidgets(
        'should rebuild when useState changes via external trigger in useJoltWidget',
        (tester) async {
      int buildCount = 0;
      late ValueNotifier<int> countNotifier;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(builder: (context) {
            final count = useState(0);
            countNotifier = count;

            return Column(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                useJoltWidget(() {
                  buildCount++;
                  // Access useState value directly in useJoltWidget
                  return Text('Count: ${count.value}',
                      textDirection: TextDirection.ltr);
                }),
                ElevatedButton(
                  onPressed: () => countNotifier.value++,
                  child: const Text('Increment'),
                ),
              ],
            );
          }),
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('Count: 0'), findsOneWidget);

      // Tap the button to increment the counter
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // The widget will rebuild because HookBuilder rebuilds when useState changes
      // but useJoltWidget itself doesn't track useState directly
      expect(buildCount, greaterThan(1));
      expect(find.text('Count: 1'), findsOneWidget);

      // Tap again
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(2));
      expect(find.text('Count: 2'), findsOneWidget);
    });
  });

  group('Hook disposal', () {
    testWidgets('useSignal is disposed on unmount', (tester) async {
      late Signal<int> signal;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            signal = useSignal(1);
            return Text('Value: ${signal.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Value: 1'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(signal.isDisposed, isTrue);
    });

    testWidgets('useSignal.lazy is disposed on unmount', (tester) async {
      late Signal<String?> signal;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            signal = useSignal.lazy<String?>();
            return Text('Value: ${signal.value ?? 'null'}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(signal.isDisposed, isTrue);
    });

    testWidgets('useSignal.list is disposed on unmount', (tester) async {
      late ListSignal<int> list;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            list = useSignal.list([1, 2, 3]);
            return Text('Length: ${list.value.length}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(list.isDisposed, isTrue);
    });

    testWidgets('useSignal.map is disposed on unmount', (tester) async {
      late MapSignal<String, String> map;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            map = useSignal.map({'key': 'value'});
            return Text('Value: ${map.value['key']}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(map.isDisposed, isTrue);
    });

    testWidgets('useSignal.set is disposed on unmount', (tester) async {
      late SetSignal<int> set;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            set = useSignal.set({1, 2, 3});
            return Text('Size: ${set.value.length}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(set.isDisposed, isTrue);
    });

    testWidgets('useSignal.iterable is disposed on unmount', (tester) async {
      late IterableSignal<int> iterable;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            iterable = useSignal.iterable(() => [1, 2, 3]);
            return Text('Count: ${iterable.value.length}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(iterable.isDisposed, isTrue);
    });

    testWidgets('useSignal.async is disposed on unmount', (tester) async {
      late AsyncSignal<int> asyncSignal;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            asyncSignal = useSignal.async(
              FutureSource(Future.value(42)),
            );
            return Text('Async', textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(asyncSignal.isDisposed, isTrue);
    });

    testWidgets('useComputed is disposed on unmount', (tester) async {
      late Computed<int> computed;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(5);
            computed = useComputed(() => signal.value * 2);
            return Text('Computed: ${computed.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(computed.isDisposed, isTrue);
    });

    testWidgets('useComputed.writable is disposed on unmount', (tester) async {
      late Computed<int> writable;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final source = useSignal(10);
            writable = useComputed.writable(
              () => source.value * 2,
              (value) => source.value = value ~/ 2,
            );
            return Text('Writable: ${writable.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(writable.isDisposed, isTrue);
    });

    testWidgets('useJoltEffect is disposed on unmount', (tester) async {
      late Effect effect;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(1);
            effect = useJoltEffect(() {
              signal.value;
            });
            return Text('Value: ${signal.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(effect.isDisposed, isTrue);
    });

    testWidgets('useWatcher is disposed on unmount', (tester) async {
      late Watcher watcher;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(1);
            watcher = useWatcher(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return Text('Value: ${signal.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(watcher.isDisposed, isTrue);
    });

    testWidgets('useWatcher.immediately is disposed on unmount',
        (tester) async {
      late Watcher watcher;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(1);
            watcher = useWatcher.immediately(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return Text('Value: ${signal.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(watcher.isDisposed, isTrue);
    });

    testWidgets('useWatcher.once is disposed on unmount', (tester) async {
      late Watcher watcher;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final signal = useSignal(1);
            watcher = useWatcher.once(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return Text('Value: ${signal.value}',
                textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(watcher.isDisposed, isTrue);
    });

    testWidgets('useEffectScope is disposed on unmount', (tester) async {
      late EffectScope scope;

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            scope = useEffectScope();
            return const Text('Test', textDirection: TextDirection.ltr);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(scope.isDisposed, isTrue);
    });
  });
}
