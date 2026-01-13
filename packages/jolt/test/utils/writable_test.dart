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
  });

  group("JoltSignalExtension", () {
    test("readonly returns ReadonlySignal and reflects changes", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly, isA<ReadonlySignal<int>>());
      expect(readonly.value, equals(42));
      expect(readonly.peek, equals(42));

      signal.value = 10;
      expect(readonly.value, equals(10));
      expect(readonly.peek, equals(10));
    });

    test("readonly view establishes reactive dependency", () {
      final signal = Signal(0);
      final readonly = signal.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([0]));
      signal.value = 1;
      expect(values, equals([0, 1]));
    });

    test("readonly view dispose disposes original signal", () {
      final signal = Signal(5);
      final readonly = signal.readonly();

      expect(signal.isDisposed, isFalse);
      expect(readonly.isDisposed, isFalse);

      readonly.dispose();

      expect(signal.isDisposed, isTrue);
      expect(readonly.isDisposed, isTrue);
    });

    test("readonly view toString returns value string", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly.toString(), equals("42"));

      signal.value = 100;
      expect(readonly.toString(), equals("100"));
    });

    test("readonly view operator == works correctly", () {
      final signal1 = Signal(5);
      final signal2 = Signal(5);
      final readonly1 = signal1.readonly();
      final readonly2 = signal1.readonly(); // Same signal
      final readonly3 = signal2.readonly(); // Different signal

      expect(readonly1 == readonly2, isTrue); // Same root signal
      expect(readonly1 == readonly3, isFalse); // Different root signals
      expect(readonly1 == readonly1, isTrue); // Same instance
    });

    test("readonly view hashCode is consistent", () {
      final signal = Signal(5);
      final readonly1 = signal.readonly();
      final readonly2 = signal.readonly();

      expect(readonly1.hashCode, equals(readonly2.hashCode));
    });

    test("readonly view notify triggers notifications", () {
      final signal = Signal(0);
      final readonly = signal.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([0]));

      readonly.notify();
      expect(
          values, equals([0, 0])); // Notified even though value didn't change
    });
  });

  group("JoltWritableComputedExtension", () {
    test("readonly returns Computed and reflects changes", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();

      expect(readonly, isA<Computed<int>>());
      expect(readonly.value, equals(10));
      expect(readonly.peek, equals(10));

      writableComputed.value = 20;
      expect(readonly.value, equals(20));
      expect(baseSignal.value, equals(10));
    });

    test("readonly view establishes reactive dependency", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([10]));
      baseSignal.value = 10;
      expect(values, equals([10, 20]));
    });

    test("readonly view dispose disposes original writable computed", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();

      expect(writableComputed.isDisposed, isFalse);
      expect(readonly.isDisposed, isFalse);

      readonly.dispose();

      expect(writableComputed.isDisposed, isTrue);
      expect(readonly.isDisposed, isTrue);
    });

    test("readonly view toString returns value string", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();

      expect(readonly.toString(), equals("10"));

      writableComputed.value = 20;
      expect(readonly.toString(), equals("20"));
    });

    test("readonly view operator == works correctly", () {
      final baseSignal1 = Signal(5);
      final baseSignal2 = Signal(5);
      final writableComputed1 = WritableComputed<int>(
        () => baseSignal1.value * 2,
        (value) => baseSignal1.value = value ~/ 2,
      );
      final writableComputed2 = WritableComputed<int>(
        () => baseSignal2.value * 2,
        (value) => baseSignal2.value = value ~/ 2,
      );
      final readonly1 = writableComputed1.readonly();
      final readonly2 = writableComputed1.readonly(); // Same writable computed
      final readonly3 =
          writableComputed2.readonly(); // Different writable computed

      expect(readonly1 == readonly2, isTrue); // Same root
      expect(readonly1 == readonly3, isFalse); // Different roots
      expect(readonly1 == readonly1, isTrue); // Same instance
    });

    test("readonly view hashCode is consistent", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly1 = writableComputed.readonly();
      final readonly2 = writableComputed.readonly();

      expect(readonly1.hashCode, equals(readonly2.hashCode));
    });

    test("readonly view notify triggers notifications", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([10]));

      readonly.notify(true);
      expect(
          values, equals([10, 10])); // Notified even though value didn't change
    });

    test("readonly view peekCached returns cached value", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();

      // First access - computes and caches
      expect(readonly.peekCached, equals(10));

      // Change dependency
      baseSignal.value = 10;

      // peekCached returns stale cached value
      expect(readonly.peekCached, equals(10));

      // Accessing value updates cache
      expect(readonly.value, equals(20));
      expect(readonly.peekCached, equals(20));
    });
  });
}
