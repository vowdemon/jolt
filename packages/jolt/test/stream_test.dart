import "dart:async";

import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/utils/stream.dart";
import "package:test/test.dart";
import "utils.dart";

void main() {
  group("Stream Extension Tests", () {
    group("Basic Stream Operations", () {
      test("Signal stream - basic listening", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        // Initial value should not be emitted
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Change value should emit
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3]));
      });

      test("Computed stream - reactive listening", () async {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);
        final values = <int>[];

        computed.stream.listen(values.add);

        // Initial value should not be emitted
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Change source signal should emit computed value
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([4]));

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([4, 6]));
      });

      test("Multiple listeners on same stream", () async {
        final signal = Signal(1);
        final values1 = <int>[];
        final values2 = <int>[];

        signal.stream.listen(values1.add);
        signal.stream.listen(values2.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(values1, equals([2]));
        expect(values2, equals([2]));
      });

      test("Stream reuse - same instance", () {
        final signal = Signal(1);
        final stream1 = signal.stream;
        final stream2 = signal.stream;

        expect(stream1, equals(stream2));
      });
    });

    group("Listen Method", () {
      test("Listen with immediately false", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.listen(values.add, immediately: false);

        // Should not emit initial value
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Should emit on change
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        subscription.cancel();
      });

      test("Listen with immediately true", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.listen(values.add, immediately: true);

        await Future.microtask(() {});
        // Should emit initial value immediately
        expect(values, equals([1]));

        // Should emit on change
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([1, 2]));

        subscription.cancel();
      });
    });

    group("Subscription Management", () {
      test("Cancel subscription", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        subscription.cancel();

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2])); // Should not receive new values
      });

      test("Subscription state management", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.stream.listen(values.add);

        expect(subscription.isPaused, isFalse);

        // First change
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        // Second change
        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3]));

        subscription.cancel();

        // Change after cancel - should not receive
        signal.value = 4;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3])); // Should not receive after cancel
      });
    });

    group("Collection Signals", () {
      test("ListSignal stream", () async {
        final listSignal = ListSignal<int>([1, 2, 3]);
        final values = <List<int>>[];

        listSignal.stream.listen((value) {
          values.add(List.from(value));
        });

        // Should not emit initial value
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Should emit on mutation
        listSignal.add(4);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              [1, 2, 3, 4]
            ]));

        listSignal.remove(2);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              [1, 2, 3, 4],
              [1, 3, 4]
            ]));
      });

      test("MapSignal stream", () async {
        final mapSignal = MapSignal<String, int>({});
        final values = <Map<String, int>>[];

        mapSignal.stream.listen((value) {
          values.add(Map.from(value));
        });

        // Should not emit initial value
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Should emit on mutation
        mapSignal["a"] = 1;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              {"a": 1}
            ]));

        mapSignal["b"] = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              {"a": 1},
              {"a": 1, "b": 2}
            ]));
      });

      test("SetSignal stream", () async {
        final setSignal = SetSignal<int>({});
        final values = <Set<int>>[];

        setSignal.stream.listen((value) {
          values.add(Set.from(value));
        });

        // Should not emit initial value
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Should emit on mutation
        setSignal.add(1);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              {1}
            ]));

        setSignal.add(2);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              {1},
              {1, 2}
            ]));
      });
    });

    group("Batch Updates", () {
      test("Batch updates emit only final value", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        batch(() {
          signal
            ..value = 2
            ..value = 3
            ..value = 4;
        });

        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([4])); // Only final value should be emitted
      });
    });

    group("Data Types", () {
      test("String values", () async {
        final signal = Signal("hello");
        final values = <String>[];

        signal.stream.listen(values.add);

        signal.value = "world";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals(["world"]));
      });

      test("Nullable values", () async {
        final signal = Signal<int?>(null);
        final values = <int?>[];

        signal.stream.listen(values.add);

        signal.value = 42;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([42]));

        signal.value = null;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([42, null]));
      });

      test("Custom objects", () async {
        final signal = Signal(TestPerson("Alice", 30));
        final values = <TestPerson>[];

        signal.stream.listen(values.add);

        signal.value = TestPerson("Bob", 25);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([TestPerson("Bob", 25)]));
      });
    });

    group("Error Handling", () {
      test("Disposed signal throws assertion error", () {
        final signal = Signal(1);
        final _ = signal.stream; // Create stream first

        signal.dispose();

        expect(() => signal.stream, throwsA(isA<AssertionError>()));
      });
    });

    group("Rapid Changes", () {
      test("Handle rapid value changes", () async {
        final signal = Signal(0);
        final values = <int>[];

        signal.stream.listen(values.add);

        // Rapid consecutive changes
        for (var i = 1; i <= 5; i++) {
          signal.value = i;
        }

        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, equals([1, 2, 3, 4, 5]));
      });
    });

    group("Watcher Management", () {
      test("Watcher creation on first listener", () async {
        final signal = Signal(1);
        final values = <int>[];

        // First listener should create watcher
        final subscription1 = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        // Second listener should reuse existing watcher
        final subscription2 = signal.stream.listen(values.add);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3, 3])); // Both listeners should receive

        subscription1.cancel();
        subscription2.cancel();
      });

      test("Watcher cleanup when all listeners cancel", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription1 = signal.stream.listen(values.add);

        final subscription2 = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 2]));

        // Cancel all listeners
        subscription1.cancel();
        subscription2.cancel();

        // Watcher should be cleaned up, no more emissions
        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 2])); // Should not receive new values
      });

      test("Watcher recreation after cleanup", () async {
        final signal = Signal(1);
        final values = <int>[];

        // First round of listeners
        final subscription1 = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        subscription1.cancel();

        // Second round of listeners should recreate watcher
        signal.stream.listen(values.add);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3])); // Should receive new values
      });

      test("Watcher lifecycle with collection signals", () async {
        final listSignal = ListSignal<int>([1, 2, 3]);
        final values = <List<int>>[];

        final subscription = listSignal.stream.listen((value) {
          values.add(List.from(value));
        });

        // Should not emit initial value
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        // Should emit on mutation
        listSignal.add(4);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              [1, 2, 3, 4]
            ]));

        // Cancel subscription
        subscription.cancel();

        // Should not emit after cancel
        listSignal.add(5);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(
            values,
            equals([
              [1, 2, 3, 4]
            ]));
      });

      test("Watcher cleanup on signal disposal", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        // Dispose signal should clean up watcher
        signal.dispose();

        // Should not be able to create new stream after disposal
        expect(() => signal.stream, throwsA(isA<AssertionError>()));
      });

      test("Stream holder reuse across multiple accesses", () {
        final signal = Signal(1);

        // Multiple accesses to stream should return same instance
        final stream1 = signal.stream;
        final stream2 = signal.stream;

        expect(stream1, equals(stream2));

        // Even after listeners are added and removed
        final subscription = signal.stream.listen((_) {});
        // test code
        // ignore: cascade_invocations
        subscription.cancel();

        final stream3 = signal.stream;
        expect(stream1, equals(stream3));
      });
    });

    group("getStreamController", () {
      test("getStreamController should return controller after stream creation",
          () {
        final signal = Signal(42);

        // Initially, controller should be null
        final controllerBefore = JoltStreamHelper.getStreamController(signal);
        expect(controllerBefore, isNull);

        // After accessing stream, controller should be created
        final _ = signal.stream;
        final controllerAfter = JoltStreamHelper.getStreamController(signal);
        expect(controllerAfter, isNotNull);
        expect(controllerAfter, isA<StreamController<int>>());
      });

      test("getStreamController should return same controller instance", () {
        final signal = Signal(42);

        // Access stream to create controller
        final _ = signal.stream;

        final controller1 = JoltStreamHelper.getStreamController(signal);
        final controller2 = JoltStreamHelper.getStreamController(signal);

        expect(controller1, isNotNull);
        expect(controller2, isNotNull);
        expect(controller1, same(controller2));
      });

      test("getStreamController should work with different signal types", () {
        final signal = Signal(42);
        final computed = Computed<int>(() => signal.value * 2);

        // Access streams to create controllers
        final _ = signal.stream;
        final __ = computed.stream;

        final signalController = JoltStreamHelper.getStreamController(signal);
        final computedController =
            JoltStreamHelper.getStreamController(computed);

        expect(signalController, isNotNull);
        expect(computedController, isNotNull);
        expect(signalController, isNot(same(computedController)));
      });
    });
  });
}
