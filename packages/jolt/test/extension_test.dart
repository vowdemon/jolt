import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";
import "utils.dart";

void main() {
  group("Extension methods", () {
    group("JoltReadonlyExtension", () {
      test("until should wait for condition to be met", () async {
        final signal = Signal(0);
        final future = signal.until((value) => value >= 5);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals(5));
      });

      test("until should complete immediately if condition already met",
          () async {
        final signal = Signal(10);
        final future = signal.until((value) => value >= 5);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(10));
      });

      test("until should work with different types", () async {
        final stringSignal = Signal("loading");
        final stringFuture = stringSignal.until((v) => v == "ready");
        stringSignal.value = "ready";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await stringFuture, equals("ready"));

        final boolSignal = Signal(false);
        final boolFuture = boolSignal.until((v) => v == true);
        boolSignal.value = true;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await boolFuture, equals(true));
      });

      test("until should work with Computed", () async {
        final source = Signal(0);
        final computed = Computed<int>(() => source.value * 2);
        final future = computed.until((value) => value >= 10);

        source.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(10));
      });
    });

    group("JoltWritableExtension", () {
      test("should update signal value using update method", () {
        final counter = DebugCounter();
        final signal = Signal(5, onDebug: counter.onDebug);
        expect(signal.value, equals(5));

        // Update using increment
        final newValue = signal.update((value) => value + 1);
        expect(newValue, equals(6));
        expect(signal.value, equals(6));
        expect(signal.peek, equals(6));
        expect(counter.setCount, equals(1));

        // Update using multiplication
        signal.update((value) => value * 2);
        expect(signal.value, equals(12));
        expect(signal.peek, equals(12));
        expect(counter.setCount, equals(2));

        // Update multiple times
        signal.update((value) => value - 5);
        expect(signal.value, equals(7));
        signal.update((value) => value * 3);
        expect(signal.value, equals(21));
        expect(counter.setCount, equals(4));
      });

      test("update method should internally call set", () {
        final signal = Signal(10);

        // Verify update is equivalent to set(updater(peek))
        final updateResult = signal.update((value) {
          expect(value, equals(10)); // Should get current value via peek
          return value + 5;
        });

        expect(updateResult, equals(15));
        expect(signal.value, equals(15));

        // Verify update behaves the same as set(updater(peek))
        signal.value = 10;
        final directSetResult = signal.set(signal.peek + 5);
        expect(directSetResult, equals(15));
        expect(signal.value, equals(15));

        // Both approaches should produce the same result
        signal.value = 20;
        final viaUpdate = signal.update((v) => v * 2);
        signal.value = 20;
        final viaSet = signal.set(signal.peek * 2);
        expect(viaUpdate, equals(viaSet));
        expect(viaUpdate, equals(40));
      });

      test(
          "update should not establish reactive dependency when reading current value",
          () {
        final signal = Signal(10);
        final computed = Computed<int>(() => signal.value * 2);
        final values = <int>[];

        Effect(() {
          values.add(computed.value);
        });

        expect(values, equals([20]));

        // Update using update method - should trigger effect once
        signal.update((value) => value + 10);
        expect(signal.value, equals(20));
        expect(computed.value, equals(40));
        expect(values, equals([20, 40])); // Effect should trigger once
      });

      test("update should work with different data types", () {
        // String signal
        final stringSignal = Signal("hello");
        stringSignal.update((value) => value.toUpperCase());
        expect(stringSignal.value, equals("HELLO"));

        // List signal
        final listSignal = Signal<List<int>>([1, 2, 3]);
        listSignal.update((value) => [...value, 4, 5]);
        expect(listSignal.value, equals([1, 2, 3, 4, 5]));

        // Map signal
        final mapSignal = Signal<Map<String, int>>({"a": 1});
        mapSignal.update((value) => {...value, "b": 2});
        expect(mapSignal.value, equals({"a": 1, "b": 2}));
      });

      test("update should work with WritableComputed", () {
        final baseSignal = Signal(5);
        final writableComputed = WritableComputed<int>(
          () => baseSignal.value * 2,
          (value) => baseSignal.value = value ~/ 2,
        );

        expect(writableComputed.value, equals(10));

        // Update writable computed using update method
        writableComputed.update((value) => value + 10);
        expect(writableComputed.value, equals(20));
        expect(baseSignal.value, equals(10));

        // Verify it internally calls set
        writableComputed.update((value) => value * 2);
        expect(writableComputed.value, equals(40));
        expect(baseSignal.value, equals(20));
      });
    });
  });
}
