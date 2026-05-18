import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsWritableExtension", () {
    test("update modifies value using updater function", () {
      final signal = Signal(5);
      final newValue = signal.update((value) => value + 1);

      expect(newValue, equals(6));
      expect(signal.value, equals(6));
    });

    test("set modifies value and returns it", () {
      final signal = Signal(10);
      final result = signal.set(20);

      expect(result, equals(20));
      expect(signal.value, equals(20));
    });

    test("update uses peek without establishing dependency", () {
      final signal = Signal(10);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([10]));

      // update should not trigger effect when reading current value
      signal.update((value) => value + 5);
      expect(signal.value, equals(15));
      expect(values, equals([10, 15])); // Only one update triggered
    });

    test("update works with different data types", () {
      final stringSignal = Signal("hello");
      final listSignal = Signal<List<int>>([1, 2, 3]);
      final mapSignal = Signal<Map<String, int>>({"a": 1});

      stringSignal.update((value) => value.toUpperCase());
      listSignal.update((value) => [...value, 4, 5]);
      mapSignal.update((value) => {...value, "b": 2});

      expect(stringSignal.value, equals("HELLO"));
      expect(listSignal.value, equals([1, 2, 3, 4, 5]));
      expect(mapSignal.value, equals({"a": 1, "b": 2}));
    });

    test("update works with WritableComputed", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );

      expect(writableComputed.value, equals(10));

      writableComputed.update((value) => value + 10);
      expect(writableComputed.value, equals(20));
      expect(baseSignal.value, equals(10));

      writableComputed.update((value) => value * 2);
      expect(writableComputed.value, equals(40));
      expect(baseSignal.value, equals(20));
    });
  });
}
