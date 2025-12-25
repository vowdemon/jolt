// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Helper InheritedWidget for testing useInherited
class _TestCounter extends InheritedWidget {
  final int count;

  const _TestCounter({
    required this.count,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _TestCounter oldWidget) {
    return oldWidget.count != count;
  }

  static _TestCounter of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TestCounter>()!;
  }
}

/// Helper SetupWidget for testing useInherited with persistent widget instance
class _TestThemeWidget extends SetupWidget<_TestThemeWidget> {
  const _TestThemeWidget();

  @override
  setup(context, props) {
    final theme = useInherited(Theme.of);
    return () => Text('Color: ${theme.value.primaryColor}');
  }
}

void main() {
  group('Jolt Hooks', () {
    testWidgets('useSignal creates and maintains signal', (tester) async {
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(42);
          return () => Text('Value: ${signal.value}');
        }),
      ));

      expect(find.text('Value: 42'), findsOneWidget);

      signal.value = 100;
      await tester.pumpAndSettle();

      expect(find.text('Value: 100'), findsOneWidget);
    });

    testWidgets('useSignal.lazy creates signal without initial value',
        (tester) async {
      late Signal<String?> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal.lazy<String?>();
          return () => Text('Value: ${signal.value ?? 'empty'}');
        }),
      ));

      expect(find.text('Value: empty'), findsOneWidget);

      signal.value = 'loaded';
      await tester.pumpAndSettle();

      expect(find.text('Value: loaded'), findsOneWidget);
    });

    testWidgets('useComputed creates computed value', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(5);
          final computed = useComputed(() => signal.value * 2);
          return () => Text('Computed: ${computed.value}');
        }),
      ));

      expect(find.text('Computed: 10'), findsOneWidget);
    });

    testWidgets('useComputed.withPrevious passes null on first computation',
        (tester) async {
      int? previousValue;
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(5);
          final computed = useComputed.withPrevious<int>((prev) {
            previousValue = prev;
            return signal.value * 2;
          });
          return () => Text('Computed: ${computed.value}');
        }),
      ));

      expect(find.text('Computed: 10'), findsOneWidget);
      expect(previousValue, isNull);
    });

    testWidgets('useComputed.withPrevious receives previous value on updates',
        (tester) async {
      final previousValues = <int?>[];
      late Signal<int> signal;
      late Computed<int> computed;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          computed = useComputed.withPrevious<int>((prev) {
            previousValues.add(prev);
            if (prev == null) {
              return signal.value;
            } else {
              return prev + signal.value;
            }
          });
          return () => Text('Computed: ${computed.value}');
        }),
      ));

      expect(find.text('Computed: 1'), findsOneWidget);
      expect(previousValues, equals([null]));

      signal.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Computed: 3'), findsOneWidget); // 1 + 2
      expect(previousValues, equals([null, 1]));

      signal.value = 3;
      await tester.pumpAndSettle();
      expect(find.text('Computed: 6'), findsOneWidget); // 3 + 3
      expect(previousValues, equals([null, 1, 3]));
    });

    testWidgets('useComputed.withPrevious works with nullable types',
        (tester) async {
      final previousValues = <int?>[];
      late Signal<int?> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal<int?>(null);
          final computed = useComputed.withPrevious<int?>((prev) {
            previousValues.add(prev);
            return signal.value;
          });
          return () => Text('Value: ${computed.value ?? 'null'}');
        }),
      ));

      expect(find.text('Value: null'), findsOneWidget);
      expect(previousValues, equals([null]));

      signal.value = 42;
      await tester.pumpAndSettle();
      expect(find.text('Value: 42'), findsOneWidget);
      expect(previousValues, equals([null, null]));

      signal.value = 100;
      await tester.pumpAndSettle();
      expect(find.text('Value: 100'), findsOneWidget);
      expect(previousValues, equals([null, null, 42]));
    });

    testWidgets('useWritableComputed creates writable computed',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final source = useSignal(10);
          final writable = useComputed.writable(
            () => source.value * 2,
            (value) => source.value = value ~/ 2,
          );
          return () => Text('Writable: ${writable.value}');
        }),
      ));

      expect(find.text('Writable: 20'), findsOneWidget);
    });

    testWidgets(
        'useComputed.writableWithPrevious passes null on first computation',
        (tester) async {
      int? previousValue;
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(5);
          final writable = useComputed.writableWithPrevious<int>(
            (prev) {
              previousValue = prev;
              return signal.value * 2;
            },
            (value) => signal.value = value ~/ 2,
          );
          return () => Text('Writable: ${writable.value}');
        }),
      ));

      expect(find.text('Writable: 10'), findsOneWidget);
      expect(previousValue, isNull);
    });

    testWidgets(
        'useComputed.writableWithPrevious receives previous value and handles writes',
        (tester) async {
      final previousValues = <int?>[];
      late Signal<int> signal;
      late WritableComputed<int> writable;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          writable = useComputed.writableWithPrevious<int>(
            (prev) {
              previousValues.add(prev);
              if (prev == null) {
                return signal.value;
              } else {
                return prev + signal.value;
              }
            },
            (value) {
              // Simple setter: set signal to a fixed value
              signal.value = 5;
            },
          );
          return () => Text('Writable: ${writable.value}');
        }),
      ));

      expect(find.text('Writable: 1'), findsOneWidget);
      expect(previousValues, equals([null]));

      signal.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Writable: 3'), findsOneWidget); // 1 + 2
      expect(previousValues, equals([null, 1]));

      signal.value = 3;
      await tester.pumpAndSettle();
      expect(find.text('Writable: 6'), findsOneWidget); // 3 + 3
      expect(previousValues, equals([null, 1, 3]));

      writable.value = 10;
      await tester.pumpAndSettle();
      expect(signal.value, equals(5)); // Setter sets signal to 5
      expect(find.text('Writable: 11'), findsOneWidget); // 6 + 5 = 11
      expect(previousValues, equals([null, 1, 3, 6]));
    });

    testWidgets('useJoltEffect runs effect', (tester) async {
      int effectCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useEffect(() {
            effectCount++;
            signal.value; // Track dependency
          });
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, greaterThanOrEqualTo(1));
    });

    testWidgets('useEffect with lazy=false runs immediately and on changes',
        (tester) async {
      int effectCount = 0;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          useEffect(() {
            effectCount++;
            signal.value; // Track dependency
          }, lazy: false);
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Runs immediately when lazy=false

      // Change signal value
      signal.value = 2;
      await tester.pumpAndSettle();

      expect(effectCount,
          greaterThanOrEqualTo(2)); // Runs again when dependency changes
    });

    testWidgets('useEffect.lazy does not run automatically', (tester) async {
      int effectCount = 0;
      late Effect effect;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          effect = useEffect.lazy(() {
            effectCount++;
            signal.value; // Track dependency
          });
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 0); // Does not run automatically when lazy=true

      // Signal changes but effect doesn't run automatically
      signal.value = 2;
      await tester.pumpAndSettle();

      expect(effectCount, 0); // Still doesn't run automatically

      // Manually run the effect
      effect.run();
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Runs when manually triggered
    });

    testWidgets('useFlutterEffect runs effect at frame end', (tester) async {
      int effectCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useFlutterEffect(() {
            effectCount++;
            signal.value; // Track dependency
          });
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Runs at frame end when lazy=false
    });

    testWidgets(
        'useFlutterEffect with lazy=false runs at frame end and on changes',
        (tester) async {
      int effectCount = 0;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          useFlutterEffect(() {
            effectCount++;
            signal.value; // Track dependency
          }, lazy: false);
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Runs at frame end when lazy=false

      // Change signal value
      signal.value = 2;
      await tester.pumpAndSettle(); // Wait for frame end

      expect(effectCount, 2); // Runs again at frame end when dependency changes

      // Multiple changes in same frame should batch
      signal.value = 3;
      signal.value = 4;
      await tester.pumpAndSettle(); // Wait for frame end

      expect(effectCount, 3); // Should execute only once per frame
    });

    testWidgets('useFlutterEffect.lazy does not run automatically',
        (tester) async {
      int effectCount = 0;
      late FlutterEffect effect;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          effect = useFlutterEffect.lazy(() {
            effectCount++;
            signal.value; // Track dependency
          });
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 0); // Does not run automatically when lazy=true

      // Signal changes but effect doesn't run automatically
      signal.value = 2;
      await tester.pumpAndSettle();

      expect(effectCount, 0); // Still doesn't run automatically

      // Manually run the effect
      effect.run();
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Runs when manually triggered
    });

    testWidgets('useFlutterEffect batches multiple triggers in same frame',
        (tester) async {
      int effectCount = 0;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          useFlutterEffect(() {
            effectCount++;
            signal.value; // Track dependency
          });
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 1); // Initial execution

      // Multiple changes in same frame
      signal.value = 2;
      signal.value = 3;
      signal.value = 4;

      // Should not execute yet (before frame end)
      expect(effectCount, 1);

      await tester.pumpAndSettle(); // Wait for frame end

      // Should execute only once with final value
      expect(effectCount, 2);
    });

    testWidgets('useWatcher watches changes', (tester) async {
      int watchCount = 0;
      int? lastValue;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useWatcher(
            () => signal.value,
            (newValue, oldValue) {
              watchCount++;
              lastValue = newValue;
            },
            immediately: true,
          );
          return () => Text('Value: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(watchCount, greaterThanOrEqualTo(1));
      expect(lastValue, 1);
    });

    testWidgets('useWatcher.immediately executes immediately', (tester) async {
      int watchCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useWatcher.immediately(
            () => signal.value,
            (newValue, oldValue) {
              watchCount++;
            },
          );
          return () => Text('Value: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(watchCount, greaterThanOrEqualTo(1));
    });

    testWidgets('useWatcher.once executes only once', (tester) async {
      int watchCount = 0;
      late Signal<int> signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(1);
          useWatcher.once(
            () => signal.value,
            (newValue, oldValue) {
              watchCount++;
            },
          );
          return () => Text('Value: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      // Once watcher should execute when signal changes
      signal.value = 2;
      await tester.pumpAndSettle();

      expect(watchCount, lessThanOrEqualTo(1));
    });

    testWidgets('useJoltEffectScope creates effect scope', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final scope = useEffectScope();
          expect(scope, isNotNull);
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('useListSignal creates list signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final list = useSignal.list([1, 2, 3]);
          return () => Text('Length: ${list.value.length}');
        }),
      ));

      expect(find.text('Length: 3'), findsOneWidget);
    });

    testWidgets('useMapSignal creates map signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final map = useSignal.map({'key': 'value'});
          return () => Text('Value: ${map.value['key']}');
        }),
      ));

      expect(find.text('Value: value'), findsOneWidget);
    });

    testWidgets('useSetSignal creates set signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final set = useSignal.set({1, 2, 3});
          return () => Text('Size: ${set.value.length}');
        }),
      ));

      expect(find.text('Size: 3'), findsOneWidget);
    });

    testWidgets('useIterableSignal creates iterable signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final iterable = useSignal.iterable(() => [1, 2, 3]);
          return () => Text('Count: ${iterable.value.length}');
        }),
      ));

      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('useStream creates stream from node', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          final stream = useJoltStream(signal);
          expect(stream, isNotNull);
          return () => Text('Value: ${signal.value}');
        }),
      ));

      expect(find.text('Value: 1'), findsOneWidget);
    });

    testWidgets('useSignal.async creates async signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final asyncSignal = useSignal.async(
            () => FutureSource(Future.value(42)),
          );
          return () => Text('Async: ${asyncSignal.value}');
        }),
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('Async:'), findsOneWidget);
    });

    testWidgets('useSignal.async with initialValue AsyncSuccess',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final asyncSignal = useSignal.async(
            () => FutureSource(
                Future.delayed(const Duration(milliseconds: 100), () => 100)),
            initialValue: () => AsyncSuccess(42),
          );
          return () => Text(
              'Data: ${asyncSignal.value.map(success: (data) => data.toString(), loading: () => 'Loading', error: (_, __) => 'Error') ?? 'Unknown'}');
        }),
      ));

      // Should start with initialValue (AsyncSuccess(42))
      expect(find.textContaining('Data: 42'), findsOneWidget);

      await tester.pumpAndSettle();

      // After future completes, should update to new value (100)
      expect(find.textContaining('Data: 100'), findsOneWidget);
    });

    testWidgets('useSignal.async with initialValue AsyncLoading',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final asyncSignal = useSignal.async(
            () => FutureSource(
                Future.delayed(const Duration(milliseconds: 100), () => 42)),
            initialValue: () => AsyncLoading<int>(),
          );
          return () => Text(
              'State: ${asyncSignal.value.map(loading: () => 'Loading', success: (data) => 'Success: $data', error: (_, __) => 'Error') ?? 'Unknown'}');
        }),
      ));

      // Should start with initialValue (AsyncLoading)
      expect(find.textContaining('State: Loading'), findsOneWidget);

      await tester.pumpAndSettle();

      // After future completes, should update to success
      expect(find.textContaining('State: Success: 42'), findsOneWidget);
    });

    testWidgets('useSignal.async with initialValue AsyncError', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final asyncSignal = useSignal.async(
            () => FutureSource(
                Future.delayed(const Duration(milliseconds: 100), () => 42)),
            initialValue: () => AsyncError<int>(Exception('Initial error')),
          );
          return () => Text(
              'State: ${asyncSignal.value.map(error: (error, _) => 'Error: $error', loading: () => 'Loading', success: (data) => 'Success: $data') ?? 'Unknown'}');
        }),
      ));

      // Should start with initialValue (AsyncError)
      expect(find.textContaining('Error: Exception: Initial error'),
          findsOneWidget);

      await tester.pumpAndSettle();

      // After future completes, should update to success
      expect(find.textContaining('State: Success: 42'), findsOneWidget);
    });

    testWidgets('multiple hooks maintain state across rebuilds',
        (tester) async {
      late Signal<int> signal1;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal1 = useSignal(1);
          final signal2 = useSignal(2);
          final computed = useComputed(() => signal1.value + signal2.value);
          return () => Text('Sum: ${computed.value}');
        }),
      ));

      expect(find.text('Sum: 3'), findsOneWidget);

      // Rebuild should maintain hook instances
      signal1.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Sum: 12'), findsOneWidget);
    });

    testWidgets('hooks are disposed on unmount', (tester) async {
      bool disposed = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useEffect(() {
            signal.value; // Track signal
            onEffectCleanup(() => disposed = true);
          });
          return () => Text('Value: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(disposed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(disposed, isTrue);
    });

    testWidgets('useFlutterEffect cleanup is called on unmount',
        (tester) async {
      bool disposed = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useFlutterEffect(() {
            signal.value; // Track signal
            onEffectCleanup(() => disposed = true);
          });
          return () => Text('Value: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(disposed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(disposed, isTrue);
    });

    group('Hook disposal', () {
      testWidgets('useSignal is disposed on unmount', (tester) async {
        late Signal<int> signal;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            signal = useSignal(1);
            // Track disposal by checking if signal is still accessible
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Value: 1'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        // Signal should be disposed
        expect(signal.isDisposed, isTrue);
      });

      testWidgets('useSignal.lazy is disposed on unmount', (tester) async {
        late Signal<int?> signal;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            signal = useSignal.lazy<int?>();
            return () => Text('Value: ${signal.value ?? 'null'}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(signal.isDisposed, isTrue);
      });

      testWidgets('useSignal.list is disposed on unmount', (tester) async {
        late ListSignal<int> list;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            list = useSignal.list([1, 2, 3]);
            return () => Text('Length: ${list.value.length}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(list.isDisposed, isTrue);
      });

      testWidgets('useSignal.map is disposed on unmount', (tester) async {
        late MapSignal<String, String> map;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            map = useSignal.map({'key': 'value'});
            return () => Text('Value: ${map.value['key']}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(map.isDisposed, isTrue);
      });

      testWidgets('useSignal.set is disposed on unmount', (tester) async {
        late SetSignal<int> set;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            set = useSignal.set({1, 2, 3});
            return () => Text('Size: ${set.value.length}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(set.isDisposed, isTrue);
      });

      testWidgets('useSignal.iterable is disposed on unmount', (tester) async {
        late IterableSignal<int> iterable;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            iterable = useSignal.iterable(() => [1, 2, 3]);
            return () => Text('Count: ${iterable.value.length}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(iterable.isDisposed, isTrue);
      });

      testWidgets('useSignal.async is disposed on unmount', (tester) async {
        late AsyncSignal<int> asyncSignal;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            asyncSignal = useSignal.async(
              () => FutureSource(Future.value(42)),
            );
            return () => Text('Async');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(asyncSignal.isDisposed, isTrue);
      });

      testWidgets('useComputed is disposed on unmount', (tester) async {
        late Computed<int> computed;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(5);
            computed = useComputed(() => signal.value * 2);
            return () => Text('Computed: ${computed.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(computed.isDisposed, isTrue);
      });

      testWidgets('useComputed.writable is disposed on unmount',
          (tester) async {
        late Computed<int> writable;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final source = useSignal(10);
            writable = useComputed.writable(
              () => source.value * 2,
              (value) => source.value = value ~/ 2,
            );
            return () => Text('Writable: ${writable.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(writable.isDisposed, isTrue);
      });

      testWidgets('useComputed.withPrevious is disposed on unmount',
          (tester) async {
        late Computed<int> computed;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(5);
            computed = useComputed.withPrevious<int>((prev) {
              return signal.value * 2;
            });
            return () => Text('Computed: ${computed.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(computed.isDisposed, isTrue);
      });

      testWidgets('useComputed.writableWithPrevious is disposed on unmount',
          (tester) async {
        late WritableComputed<int> writable;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final source = useSignal(10);
            writable = useComputed.writableWithPrevious<int>(
              (prev) => source.value * 2,
              (value) => source.value = value ~/ 2,
            );
            return () => Text('Writable: ${writable.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(writable.isDisposed, isTrue);
      });

      testWidgets('useEffect is disposed on unmount', (tester) async {
        late Effect effect;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(1);
            effect = useEffect(() {
              signal.value;
            });
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(effect.isDisposed, isTrue);
      });

      testWidgets('useFlutterEffect is disposed on unmount', (tester) async {
        late FlutterEffect effect;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(1);
            effect = useFlutterEffect(() {
              signal.value;
            });
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(effect.isDisposed, isTrue);
      });

      testWidgets('useWatcher is disposed on unmount', (tester) async {
        late Watcher watcher;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(1);
            watcher = useWatcher(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(watcher.isDisposed, isTrue);
      });

      testWidgets('useWatcher.immediately is disposed on unmount',
          (tester) async {
        late Watcher watcher;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(1);
            watcher = useWatcher.immediately(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(watcher.isDisposed, isTrue);
      });

      testWidgets('useWatcher.once is disposed on unmount', (tester) async {
        late Watcher watcher;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            final signal = useSignal(1);
            watcher = useWatcher.once(
              () => signal.value,
              (newValue, oldValue) {},
            );
            return () => Text('Value: ${signal.value}');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(watcher.isDisposed, isTrue);
      });

      testWidgets('useEffectScope is disposed on unmount', (tester) async {
        late EffectScope scope;

        await tester.pumpWidget(MaterialApp(
          home: SetupBuilder(setup: (context) {
            scope = useEffectScope();
            return () => const Text('Test');
          }),
        ));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(scope.isDisposed, isTrue);
      });
    });
  });

  group('useInherited', () {
    testWidgets('useInherited gets initial value from InheritedWidget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.blue),
          home: SetupBuilder(setup: (context) {
            final theme = useInherited(Theme.of);
            return () => Text('Color: ${theme().primaryColor}');
          }),
        ),
      );

      expect(find.text('Color: ${Colors.blue}'), findsOneWidget);
    });

    testWidgets('useInherited updates when InheritedWidget changes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.blue),
          home: SetupBuilder(setup: (context) {
            final theme = useInherited(Theme.of);
            return () => Text('Color: ${theme().primaryColor}');
          }),
        ),
      );

      expect(find.text('Color: ${Colors.blue}'), findsOneWidget);

      // Change theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.red),
          home: SetupBuilder(setup: (context) {
            final theme = useInherited(Theme.of);
            return () => Text('Color: ${theme().primaryColor}');
          }),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Color: ${Colors.red}'), findsOneWidget);
      expect(find.text('Color: ${Colors.blue}'), findsNothing);
    });

    testWidgets('useInherited works with MediaQuery', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.0),
            child: SetupBuilder(setup: (context) {
              final mediaQuery = useInherited(MediaQuery.of);
              return () => Text('Scale: ${mediaQuery().textScaleFactor}');
            }),
          ),
        ),
      );

      expect(find.text('Scale: 1.0'), findsOneWidget);

      // Change MediaQuery
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.5),
            child: SetupBuilder(setup: (context) {
              final mediaQuery = useInherited(MediaQuery.of);
              return () => Text('Scale: ${mediaQuery().textScaleFactor}');
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Scale: 1.5'), findsOneWidget);
      expect(find.text('Scale: 1.0'), findsNothing);
    });

    testWidgets('useInherited works with custom InheritedWidget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestCounter(
            count: 10,
            child: SetupBuilder(setup: (context) {
              final counter = useInherited(_TestCounter.of);
              return () => Text('Count: ${counter().count}');
            }),
          ),
        ),
      );

      expect(find.text('Count: 10'), findsOneWidget);

      // Change counter
      await tester.pumpWidget(
        MaterialApp(
          home: _TestCounter(
            count: 20,
            child: SetupBuilder(setup: (context) {
              final counter = useInherited(_TestCounter.of);
              return () => Text('Count: ${counter().count}');
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Count: 20'), findsOneWidget);
      expect(find.text('Count: 10'), findsNothing);
    });

    testWidgets('useInherited works with multiple InheritedWidgets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.blue),
          home: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.0),
            child: SetupBuilder(setup: (context) {
              final theme = useInherited(Theme.of);
              final mediaQuery = useInherited(MediaQuery.of);
              return () => Text(
                  'Theme: ${theme().primaryColor}, Scale: ${mediaQuery().textScaleFactor}');
            }),
          ),
        ),
      );

      expect(find.textContaining('Theme: ${Colors.blue}'), findsOneWidget);
      expect(find.textContaining('Scale: 1.0'), findsOneWidget);

      // Change both
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.red),
          home: MediaQuery(
            data: const MediaQueryData(textScaleFactor: 1.5),
            child: SetupBuilder(setup: (context) {
              final theme = useInherited(Theme.of);
              final mediaQuery = useInherited(MediaQuery.of);
              return () => Text(
                  'Theme: ${theme().primaryColor}, Scale: ${mediaQuery().textScaleFactor}');
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Theme: ${Colors.red}'), findsOneWidget);
      expect(find.textContaining('Scale: 1.5'), findsOneWidget);
      expect(find.textContaining('Theme: ${Colors.blue}'), findsNothing);
      expect(find.textContaining('Scale: 1.0'), findsNothing);
    });

    testWidgets(
        'useInherited works with SetupWidget that maintains same instance',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.blue),
          home: const _TestThemeWidget(),
        ),
      );

      expect(find.text('Color: ${Colors.blue}'), findsOneWidget);

      // Change theme with same widget instance
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.red),
          home: const _TestThemeWidget(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Color: ${Colors.red}'), findsOneWidget);
      expect(find.text('Color: ${Colors.blue}'), findsNothing);
    });
  });
}
