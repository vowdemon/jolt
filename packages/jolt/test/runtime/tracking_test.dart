import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/impl/effect.dart";
import "package:test/test.dart";

void main() {
  group("untracked", () {
    test("reads inside untracked are not effect dependencies", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([1]));
      signal.value = 2;
      expect(values, equals([1]));
    });

    test("mixed tracked and untracked reads in one effect run", () {
      final tracked = Signal(1);
      final ignored = Signal(2);
      final trackedValues = <int>[];
      final ignoredValues = <int>[];

      Effect(() {
        trackedValues.add(tracked.value);
        ignoredValues.add(untracked(() => ignored.value));
      });

      expect(trackedValues, equals([1]));
      expect(ignoredValues, equals([2]));

      tracked.value = 10;
      expect(trackedValues, equals([1, 10]));
      expect(ignoredValues, equals([2, 2]));

      ignored.value = 20;
      expect(trackedValues, equals([1, 10]));
      expect(ignoredValues, equals([2, 2]));
    });

    test("conditional branches rebuild the dependency set", () {
      final useTrackedPath = Signal(true);
      final value = Signal(42);
      final values = <int>[];

      Effect(() {
        if (useTrackedPath.value) {
          values.add(value.value);
        } else {
          values.add(untracked(() => value.value));
        }
      });

      expect(values, equals([42]));

      value.value = 100;
      expect(values, equals([42, 100]));

      useTrackedPath.value = false;
      expect(values, equals([42, 100, 100]));

      value.value = 200;
      expect(values, equals([42, 100, 100]));
    });

    test("untracked isolation is per effect", () {
      final signal = Signal(1);
      final trackedValues = <int>[];
      final untrackedValues = <int>[];

      Effect(() => trackedValues.add(signal.value));
      Effect(() => untrackedValues.add(untracked(() => signal.value)));

      expect(trackedValues, equals([1]));
      expect(untrackedValues, equals([1]));

      signal.value = 2;
      expect(trackedValues, equals([1, 2]));
      expect(untrackedValues, equals([1]));
    });
  });

  group("EffectImpl.track", () {
    test("registers dependencies on a lazy effect and returns the result", () {
      var runs = 0;
      final signal = Signal(1);
      final effect = Effect(() => runs++, lazy: true);
      final impl = effect as EffectImpl;

      expect(impl.track(() => signal.value), 1);
      expect(runs, 0);

      signal.value = 2;
      expect(runs, 1);
    });

    test("purge true drops prior track deps before collecting new ones", () {
      var runs = 0;
      final first = Signal(1);
      final second = Signal(2);
      final effect = Effect(() => runs++, lazy: true);
      final impl = effect as EffectImpl;

      impl.track(() => first.value);
      impl.track(() => second.value);

      first.value = 10;
      expect(runs, 0);

      second.value = 20;
      expect(runs, 1);
    });

    test("purge false keeps prior track deps across track calls", () {
      var runs = 0;
      final first = Signal(1);
      final second = Signal(2);
      final effect = Effect(() => runs++, lazy: true);
      final impl = effect as EffectImpl;

      impl.track(() => first.value, false);
      impl.track(() => second.value, false);

      first.value = 10;
      expect(runs, 1);
    });

    test("propagates errors from the tracked function", () {
      final effect = Effect(() {}, lazy: true);

      expect(
        () => (effect as EffectImpl).track(() => throw Exception("track error")),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          "message",
          contains("track error"),
        )),
      );
    });

    test("restores the previous active subscriber after nested track", () {
      final signal = Signal(1);
      final outer = Effect(() {}, lazy: true);
      final inner = Effect(() {}, lazy: true);
      final values = <int>[];

      (outer as EffectImpl).track(() {
        values.add(signal.value);
        (inner as EffectImpl).track(() => values.add(signal.value));
        values.add(signal.value);
      });

      expect(values, equals([1, 1, 1]));
    });
  });

  group("triggerTracked", () {
    test("re-notifies subscribers and returns the callback result", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() => values.add(signal.value));

      expect(values, equals([1]));
      signal.value = 2;
      expect(values, equals([1, 2]));

      expect(triggerTracked(() => signal.value), 2);
      expect(values, equals([1, 2, 2]));
    });

    test(
      "does not notify computed-only dependents when only a source is read",
      () {
        final first = Signal(1);
        final second = Signal(2);
        final sum = Computed(() => first.value + second.value);
        final values = <int>[];

        Effect(() => values.add(sum.value));

        expect(values, equals([3]));
        first.value = 10;
        expect(values, equals([3, 12]));

        triggerTracked(() => first.value);
        expect(values, equals([3, 12]));
      },
    );

    test("does not notify subscribers of signals that were not read", () {
      final tracked = Signal(1);
      final unread = Signal(2);
      final values = <int>[];

      Effect(() => values.add(tracked.value));

      expect(values, equals([1]));
      triggerTracked(() => unread.value);
      expect(values, equals([1]));
    });

    test("nested calls notify each accessed signal", () {
      final first = Signal(1);
      final second = Signal(2);
      final firstValues = <int>[];
      final secondValues = <int>[];

      Effect(() => firstValues.add(first.value));
      Effect(() => secondValues.add(second.value));

      triggerTracked(() {
        first.value;
        triggerTracked(() => second.value);
      });

      expect(firstValues, equals([1, 1]));
      expect(secondValues, equals([2, 2]));
    });

    test("runs inside batch and flushes once with batched writes", () {
      final first = Signal(1);
      final second = Signal(2);
      final values = <int>[];

      Effect(() => values.add(first.value + second.value));

      expect(values, equals([3]));

      batch(() {
        first.value = 10;
        second.value = 20;
        triggerTracked(() {
          first.value;
          second.value;
        });
      });

      expect(values, equals([3, 30]));
    });

    test("propagates errors from the callback", () {
      expect(
        () => triggerTracked(() => throw Exception("trigger error")),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          "message",
          contains("trigger error"),
        )),
      );
    });
  });
}
