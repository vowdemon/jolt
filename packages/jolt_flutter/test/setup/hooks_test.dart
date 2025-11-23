import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/setup.dart';

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

    testWidgets('useJoltEffect with immediately=false', (tester) async {
      int effectCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(1);
          useEffect(() {
            effectCount++;
          }, immediately: false);
          return () => Text('Count: ${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(effectCount, 0);
    });

    testWidgets('useJoltWatcher watches changes', (tester) async {
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

    // testWidgets('useJoltStream creates stream from node', (tester) async {
    //   await tester.pumpWidget(MaterialApp(
    //     home: SetupBuilder(setup: (context) {
    //       final signal = useSignal(1);
    //       final stream = useJoltStream(signal);
    //       expect(stream, isNotNull);
    //       return () => Text('Value: ${signal.value}');
    //     }),
    //   ));

    //   expect(find.text('Value: 1'), findsOneWidget);
    // });

    testWidgets('useConvertComputed creates converted computed',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final source = useSignal('123');
          final converted = useComputed.convert<int, String>(
            source,
            (value) => int.parse(value),
            (value) => value.toString(),
          );
          return () => Text('Converted: ${converted.value}');
        }),
      ));

      expect(find.text('Converted: 123'), findsOneWidget);
    });

    testWidgets('usePersistSignal creates persist signal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final persist = useSignal.persist(
            () => 0,
            () => 42,
            (value) async {},
          );
          return () => Text('Persist: ${persist.value}');
        }),
      ));

      expect(find.text('Persist: 0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Persist: 42'), findsOneWidget);
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
  });
}
