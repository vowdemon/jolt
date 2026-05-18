import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/impl/effect.dart" show EffectImpl;
import "package:test/test.dart";

void main() {
  group("Effect", () {
    test("runs immediately on creation", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));
    });

    test("lazy effect does not run or track before manual run", () {
      final signal = Signal(1);
      final values = <int>[];

      final effect = Effect.lazy(() {
        values.add(signal.value);
      });

      expect(values, isEmpty);

      signal.value = 2;
      expect(values, isEmpty);

      effect.run();
      expect(values, equals([2]));

      signal.value = 3;
      expect(values, equals([2, 3]));
    });

    test("re-runs when dependencies change", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      signal.value = 2;
      signal.value = 3;

      expect(values, equals([1, 2, 3]));
    });

    test("tracks multiple dependencies", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      Effect(() {
        values.add(signal1.value + signal2.value);
      });

      signal1.value = 10;
      signal2.value = 20;

      expect(values, equals([3, 12, 30]));
    });

    test("tracks computed dependencies", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      Effect(() {
        values.add(computed.value);
      });

      signal.value = 3;

      expect(values, equals([2, 6]));
    });

    test("propagates errors after observable side effects", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
        if (signal.value > 1) {
          throw Exception("test error");
        }
      });

      expect(() => signal.value = 2, throwsA(isA<Exception>()));
      expect(values, equals([1, 2]));
    });

    test("dispose stops future dependency updates", () {
      final signal = Signal(1);
      final values = <int>[];

      final effect = Effect(() {
        values.add(signal.value);
      });

      effect.dispose();
      signal.value = 2;

      expect(effect.isDisposed, isTrue);
      expect(values, equals([1]));
    });

    test("run on disposed effect throws in debug mode", () {
      final effect = Effect(() {});

      effect.dispose();

      expect(() => effect.run(), throwsA(isA<AssertionError>()));
    });

    test("custom effect uses the provided node", () {
      final signal = Signal(1);
      final values = <int>[];
      final node = EffectNode(
        () {
          values.add(signal.value);
        },
        lazy: true,
      );
      final effect = EffectImpl.custom(() {}, node: node);

      effect.run();
      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      effect.dispose();
    });

    test("onCleanup via Effect interface runs on dispose", () {
      final log = <String>[];
      final effect = Effect(() {});

      effect.onCleanup(() => log.add("cleanup"));
      effect.dispose();

      expect(log, equals(["cleanup"]));
    });
  });

  group("Effect cleanup", () {
    test("runs previous cleanup before the next run", () {
      final signal = Signal(0);
      final log = <String>[];

      Effect(() {
        signal.value;
        log.add("run");
        onEffectCleanup(() => log.add("cleanup"));
      });

      log.clear();
      signal.value = 1;

      expect(log, equals(["cleanup", "run"]));
    });

    test("runs registered cleanup on dispose", () {
      final log = <String>[];

      final effect = Effect(() {
        onEffectCleanup(() => log.add("cleanup"));
      });

      effect.dispose();

      expect(log, equals(["cleanup"]));
    });

    test("runs multiple cleanups in registration order", () {
      final signal = Signal(1);
      final order = <int>[];

      Effect(() {
        signal.value;
        onEffectCleanup(() => order.add(1));
        onEffectCleanup(() => order.add(2));
        onEffectCleanup(() => order.add(3));
      });

      signal.value = 2;

      expect(order, equals([1, 2, 3]));
    });

    test("onEffectCleanup with explicit Effect owner", () {
      final log = <String>[];
      final effect = Effect.lazy(() {});

      onEffectCleanup(() => log.add("cleanup"), owner: effect);
      effect.run();
      effect.dispose();

      expect(log, equals(["cleanup"]));
    });
  });
}
