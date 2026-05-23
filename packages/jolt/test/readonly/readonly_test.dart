import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/impl/readonly.dart";
import "package:test/test.dart";

void main() {
  group("Readonly", () {
    test("readonly is readable and not writable", () {
      final constant = Readonly(42);

      expect(constant.value, equals(42));
      expect(constant.peek, equals(42));

      expect(
        () => (constant as dynamic).value = 99,
        throwsA(isA<NoSuchMethodError>()),
      );
      expect(constant.value, equals(42));
    });

    test("reflects value and peek from source", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly, isA<Readonly<int>>());
      expect(readonly.value, equals(42));
      expect(readonly.peek, equals(42));

      signal.value = 10;
      expect(readonly.value, equals(10));
      expect(readonly.peek, equals(10));
    });

    test("value tracks source while peek does not", () {
      final signal = Signal(1);
      final readonly = signal.readonly();
      var valueRuns = 0;
      var peekRuns = 0;

      Effect(() {
        valueRuns++;
        readonly.value;
      });
      Effect(() {
        peekRuns++;
        readonly.peek;
      });

      signal.value = 2;

      expect(valueRuns, equals(2));
      expect(peekRuns, equals(1));
    });

    test("readonly() returns cached view for same source", () {
      final signal1 = Signal(5);
      final signal2 = Signal(5);
      final readonly1 = signal1.readonly();
      final readonly2 = signal1.readonly();
      final readonly3 = signal2.readonly();

      expect(readonly1, same(readonly2));
      expect(readonly1, isNot(same(readonly3)));
    });

    test("toString reflects current value", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly.toString(), equals("42"));

      signal.value = 100;
      expect(readonly.toString(), equals("100"));
    });

    test("effect re-runs when derived source changes", () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);
      final readonly = computed.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([10]));
      signal.value = 10;
      expect(values, equals([10, 20]));
      expect(readonly.value, equals(20));
    });

    test("writable computed readonly view tracks source", () {
      final first = Signal("John");
      final last = Signal("Doe");
      final fullName = WritableComputed(
        () => "${first.value} ${last.value}",
        (value) {
          final parts = value.split(" ");
          first.value = parts.first;
          last.value = parts.last;
        },
      );
      final readonly = fullName.readonly();
      final values = <String>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals(["John Doe"]));

      fullName.value = "Jane Smith";
      expect(values, equals(["John Doe", "Jane Smith"]));
      expect(readonly.value, equals("Jane Smith"));
    });
  });

  group("Constant Readonly", () {
    test("raw exposes the constant itself", () {
      final constant = Readonly(42) as ConstantImpl<int>;

      expect(constant.raw, same(constant));
    });

    test("effect does not re-run when only constant is tracked", () {
      final constant = Readonly(5);
      final unrelated = Signal(0);
      var runs = 0;

      Effect(() {
        runs++;
        constant.value;
      });

      unrelated.value = 1;
      unrelated.value = 2;
      expect(runs, equals(1));
    });

    test("toString reflects value including null", () {
      expect(Readonly(42).toString(), equals("42"));
      expect(Readonly<int?>(null).toString(), equals("null"));
    });
  });
}
