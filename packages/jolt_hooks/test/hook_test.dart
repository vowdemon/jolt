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
            useJoltEffectScope((scope) {
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
}
