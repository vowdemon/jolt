import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsReadableExtension", () {
    group("call() and get() methods", () {
      test("read current value", () {
        final signal = Signal(42);
        expect(signal(), equals(42));
        expect(signal.get(), equals(42));
      });

      test("track dependencies while peek stays untracked", () {
        final signal = Signal(1);
        var peekRuns = 0;
        var callRuns = 0;
        var getRuns = 0;

        Effect(() {
          peekRuns++;
          signal.peek;
        });
        Effect(() {
          callRuns++;
          signal();
        });
        Effect(() {
          getRuns++;
          signal.get();
        });

        signal.value = 2;

        expect(peekRuns, equals(1));
        expect(callRuns, equals(2));
        expect(getRuns, equals(2));
      });

      test("work on Readonly views", () {
        final signal = Signal(0);
        final readonly = signal.readonly();
        final values = <int>[];

        Effect(() {
          values.add(readonly());
        });

        expect(values, equals([0]));
        signal.value = 1;
        expect(values, equals([0, 1]));
        expect(readonly.get(), equals(1));
      });
    });

    group("derived() method", () {
      test("creates reactive Computed from source", () {
        final signal = Signal(5);
        final derived = signal.derived((value) => value * 2);
        final values = <int>[];

        expect(derived, isA<Computed<int>>());
        expect(derived.value, equals(10));

        Effect(() {
          values.add(derived.value);
        });

        expect(values, equals([10]));
        signal.value = 10;
        expect(derived.value, equals(20));
        expect(values, equals([10, 20]));
      });

      test("works when source is Computed", () {
        final source = Signal(5);
        final computed = Computed<int>(() => source.value * 2);
        final derived = computed.derived((value) => value + 10);

        expect(derived.value, equals(20));
        source.value = 10;
        expect(derived.value, equals(30));
      });

      test("works when source is Readonly", () {
        final signal = Signal(5);
        final readonly = signal.readonly();
        final derived = readonly.derived((value) => value * 2);
        final values = <int>[];

        Effect(() {
          values.add(derived.value);
        });

        expect(values, equals([10]));
        signal.value = 10;
        expect(values, equals([10, 20]));
      });
    });
  });
}
