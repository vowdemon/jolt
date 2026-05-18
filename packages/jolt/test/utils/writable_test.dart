import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsWritableExtension", () {
    test("set assigns value and returns it", () {
      final signal = Signal(10);
      final result = signal.set(20);

      expect(result, equals(20));
      expect(signal.value, equals(20));
    });

    test("update applies updater and returns new value", () {
      final signal = Signal(5);
      final newValue = signal.update((value) => value + 1);

      expect(newValue, equals(6));
      expect(signal.value, equals(6));
    });

    test("update reads current value via peek inside active effect", () {
      final signal = Signal(0);
      var runs = 0;

      Effect(() {
        runs++;
        signal.update((v) => v + 1);
      });

      expect(runs, equals(1));
      expect(signal.value, equals(1));
    });

    test("update on WritableComputed", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );

      expect(writableComputed.update((value) => value + 10), equals(20));
      expect(writableComputed.value, equals(20));
      expect(baseSignal.value, equals(10));
    });
  });
}
