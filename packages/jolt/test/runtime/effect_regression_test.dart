import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Effect runtime regressions", () {
    test("disposed effect does not run when later flushed from queue", () {
      final signal = Signal(1);
      final values = <int>[];
      final effect = Effect(() {
        values.add(signal.value);
      });

      batch(() {
        signal.value = 2;
        effect.dispose();
      });

      expect(values, equals([1]));
    });

    test("supports explicit recursive effects via recursedCheck override", () {
      final signal = Signal(0);
      var triggers = 0;

      Effect(() {
        getActiveSub()!.flags &= ~ReactiveFlags.recursedCheck;
        triggers++;
        if (signal.value < 5) {
          signal.value++;
        }
      });

      expect(triggers, equals(6));
    });

    test("nested child effects clean up before parent re-run", () {
      final signal = Signal(0);
      final log = <String>[];

      Effect(() {
        signal.value;
        log.add("outer:run");
        Effect(() {
          log.add("inner:run");
          onEffectCleanup(() => log.add("inner:cleanup"));
        });
        onEffectCleanup(() => log.add("outer:cleanup"));
      });

      log.clear();
      signal.value = 1;

      expect(
        log,
        equals([
          "inner:cleanup",
          "outer:cleanup",
          "outer:run",
          "inner:run",
        ]),
      );
    });

    test("sibling nested effects clean up in reverse creation order", () {
      final log = <String>[];

      final effect = Effect(() {
        Effect(() {
          onEffectCleanup(() => log.add("inner1"));
        });
        Effect(() {
          onEffectCleanup(() => log.add("inner2"));
        });
        Effect(() {
          onEffectCleanup(() => log.add("inner3"));
        });
        onEffectCleanup(() => log.add("outer"));
      });

      effect.dispose();

      expect(log, equals(["inner3", "inner2", "inner1", "outer"]));
    });

    test("computed-owned child effects clean up in reverse creation order", () {
      final log = <String>[];
      final computed = Computed(() {
        Effect(() => onEffectCleanup(() => log.add("e1")));
        Effect(() => onEffectCleanup(() => log.add("e2")));
        Effect(() => onEffectCleanup(() => log.add("e3")));
        return 0;
      });

      final effect = Effect(() {
        computed.value;
      });

      log.clear();
      effect.dispose();

      expect(log, equals(["e3", "e2", "e1"]));
    });

    test("computed-created child effect cleans up before recomputation", () {
      final signal = Signal(0);
      final log = <String>[];

      final computed = Computed(() {
        log.add("computed:eval");
        Effect(() {
          log.add("inner:run");
          onEffectCleanup(() => log.add("inner:cleanup"));
        });
        return signal.value;
      });

      Effect(() {
        computed.value;
      });

      log.clear();
      signal.value = 1;

      expect(
        log,
        equals([
          "inner:cleanup",
          "computed:eval",
          "inner:run",
        ]),
      );
    });

    test("outer effect keeps its own dependency after inner-only re-runs", () {
      final outerSignal = Signal(0);
      final innerSignal = Signal(0);
      var outerRuns = 0;
      var innerRuns = 0;

      Effect(() {
        outerSignal.value;
        outerRuns++;
        Effect(() {
          innerSignal.value;
          innerRuns++;
        });
      });

      expect(outerRuns, equals(1));
      expect(innerRuns, equals(1));

      innerSignal.value = 1;
      expect(outerRuns, equals(1));
      expect(innerRuns, greaterThanOrEqualTo(2));

      outerSignal.value = 1;
      expect(outerRuns, equals(2));
    });

    test("unchanged sibling computed disposal path does not crash", () {
      final signal = Signal(0);
      late Effect effect;

      final stableComputed = Computed(() {
        signal.value;
        return 0;
      });
      final disposingComputed = Computed(() {
        if (signal.value != 0) effect.dispose();
        return signal.value;
      });
      final rootComputed = Computed(() {
        stableComputed.value;
        disposingComputed.value;
        return 0;
      });

      effect = Effect(() {
        rootComputed.value;
      });

      expect(() => signal.value = 1, returnsNormally);
    });
  });
}
