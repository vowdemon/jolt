import "package:fake_async/fake_async.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("batch", () {
    test("defers effect until all writes in the batch finish", () {
      final first = Signal(1);
      final second = Signal(2);
      final sum = Computed<int>(() => first.value + second.value);
      final values = <int>[];

      Effect(() => values.add(sum.value));

      expect(values, equals([3]));

      batch(() {
        first.value = 10;
        first.value = 11;
        second.value = 20;
      });

      expect(values, equals([3, 31]));
    });

    test("defers notify until batch ends", () {
      final source = Signal(<int>[1]);
      final values = <int>[];

      Effect(() => values.add(source.value.length));

      expect(values, equals([1]));

      batch(() {
        source.value.add(2);
        source.notify();
        source.value.add(3);
        expect(values, equals([1]));
      });

      expect(values, equals([1, 3]));
    });

    test("defers effect until outer nested batch completes", () {
      final first = Signal(1);
      final second = Signal(2);
      final firstValues = <int>[];
      final secondValues = <int>[];

      Effect(() => firstValues.add(first.value));
      Effect(() => secondValues.add(second.value));

      expect(firstValues, equals([1]));
      expect(secondValues, equals([2]));

      batch(() {
        first.value = 10;

        batch(() {
          second.value = 20;
          first.value = 15;
          expect(firstValues, equals([1]));
          expect(secondValues, equals([2]));
        });

        second.value = 25;
        expect(firstValues, equals([1]));
        expect(secondValues, equals([2]));
      });

      expect(firstValues, equals([1, 15]));
      expect(secondValues, equals([2, 25]));
    });

    test("applies conditional dependency snapshot at batch end", () {
      final condition = Signal(true);
      final value = Signal(42);
      final selected = Computed<int>(() {
        if (condition.value) {
          return value.value;
        }
        return 0;
      });
      final values = <int>[];

      Effect(() => values.add(selected.value));

      expect(values, equals([42]));

      batch(() {
        condition.value = false;
        value.value = 100;
      });

      expect(values, equals([42, 0]));
    });

    test("flushes pending effects when batch callback throws", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() => values.add(signal.value));

      expect(values, equals([1]));

      expect(
        () => batch(() {
          signal.value = 2;
          throw Exception("batch error");
        }),
        throwsA(isA<Exception>()),
      );

      expect(signal.value, equals(2));
      expect(values, equals([1, 2]));
    });

    test("completes when a batched signal is disposed mid-batch", () {
      final first = Signal(1);
      final second = Signal(2);
      final sum = Computed<int>(() => first.value + second.value);
      final values = <int>[];

      Effect(() => values.add(sum.value));

      expect(values, equals([3]));

      batch(() {
        first.value = 10;
        first.dispose();
        second.value = 20;
      });

      expect(values, equals([3, 30]));
    });

    test("empty batch does not notify subscribers", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() => values.add(signal.value));

      expect(values, equals([1]));

      batch(() {});

      expect(values, equals([1]));
    });

    test("does not batch work scheduled inside batch callback", () {
      fakeAsync((async) {
        final signal = Signal(1);
        final values = <int>[];

        Effect(() => values.add(signal.value));

        expect(values, equals([1]));

        batch(() {
          signal.value = 2;
          Future.delayed(const Duration(milliseconds: 1), () {
            signal.value = 3;
          });
        });

        expect(values, equals([1, 2]));

        async.elapse(const Duration(milliseconds: 1));
        expect(values, equals([1, 2, 3]));
      });
    });

    test("only batches synchronous prefix before first await", () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() => values.add(signal.value));

      expect(values, equals([1]));

      await batch(() async {
        signal.value = 20;
        signal.value = 2;
        await Future.microtask(() {});
        signal.value = 30;
        signal.value = 3;
      });

      expect(values, equals([1, 2, 30, 3]));
    });

    test("nested batch inside async callback runs after outer batch ends",
        () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() => values.add(signal.value));

      batch(() {
        signal.value = 2;
      });
      expect(values, equals([1, 2]));

      await batch(() async {
        signal.value = 40;
        signal.value = 4;
        await Future.microtask(() {});
        batch(() {
          signal.value = 50;
          signal.value = 5;
        });
      });

      expect(values, equals([1, 2, 4, 5]));
    });
  });
}
