import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Watcher", () {
    test(
      "tracks sources, batches changes, and suppresses duplicate values",
      () {
        final signal1 = Signal(1);
        final signal2 = Signal(2);
        final computed = Computed(() => signal1.value + signal2.value);
        final values = <(int, int, int)>[];

        Watcher(() => (signal1.value, signal2.value, computed.value),
            (value, _) {
          values.add(value);
        });

        expect(values, isEmpty);

        batch(() {
          signal1.value = 2;
          signal2.value = 4;
        });

        expect(values, equals([(2, 4, 6)]));

        signal1.value = 4;
        expect(values, equals([(2, 4, 6), (4, 4, 8)]));

        batch(() {
          signal1.value = 4;
          signal2.value = 4;
        });

        expect(values, equals([(2, 4, 6), (4, 4, 8)]));
      },
    );

    test("immediately runs with current value and null oldValue", () {
      final signal = Signal(10);
      final events = <(int, int?)>[];

      Watcher.immediately(() => signal.value, (newValue, oldValue) {
        events.add((newValue, oldValue));
      });

      expect(events, equals([(10, null)]));

      signal.value = 20;
      signal.value = 30;
      expect(events, equals([(10, null), (20, 10), (30, 20)]));
    });

    test("trigger runs callback with current sources", () {
      final signal = Signal(1);
      final values = <int>[];
      final watcher = Watcher(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      expect(values, isEmpty);

      watcher.trigger();
      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));
    });

    test("custom comparators can force or suppress callbacks", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed(() => signal1.value + signal2.value);
      final alwaysValues = <(int, int, int)>[];
      final distinctValues = <(int, int, int)>[];

      Watcher(
        () => (signal1.value, signal2.value, computed.value),
        (value, _) => alwaysValues.add(value),
        when: (newValue, oldValue) => true,
      );
      Watcher(
        () => (signal1.value, signal2.value, computed.value),
        (value, _) => distinctValues.add(value),
        when: (newValue, oldValue) => newValue != oldValue,
      );

      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      signal1.notify();

      expect(alwaysValues, equals([(2, 4, 6), (2, 4, 6)]));
      expect(distinctValues, equals([(2, 4, 6)]));
    });

    test("testCachedSources and effect exose watcher internals", () {
      final signal = Signal(1);
      final watcher = Watcher(() => signal.value, (_, __) {});

      signal.value = 2;

      final impl = watcher as WatcherImpl<int>;
      expect(impl.testCachedSources, equals(2));
      expect(impl.effect, isA<EffectNode>());
    });

    test("dispose stops future callbacks", () {
      final signal = Signal(1);
      final values = <int>[];
      final watcher = Watcher(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      signal.value = 2;
      expect(values, equals([2]));

      watcher.dispose();
      signal.value = 3;

      expect(values, equals([2]));
      expect(watcher.isDisposed, isTrue);
    });

    test("once disposes itself after the first callback", () {
      final signal = Signal(1);
      final values = <int>[];
      final watcher = Watcher.once(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      expect(values, isEmpty);
      expect(watcher.isDisposed, isFalse);

      signal.value = 2;
      expect(values, equals([2]));
      expect(watcher.isDisposed, isTrue);

      signal.value = 3;
      expect(values, equals([2]));
    });

    test("runs watcher cleanup before the next callback", () {
      final signal = Signal(1);
      final log = <String>[];

      Watcher(
        () => signal.value,
        (newValue, _) {
          log.add("run:$newValue");
          onEffectCleanup(() => log.add("cleanup:$newValue"));
        },
      );

      signal.value = 2;
      signal.value = 3;

      expect(log, equals(["run:2", "cleanup:2", "run:3"]));
    });

    test("runs registered watcher cleanup on dispose", () {
      final signal = Signal(1);
      final log = <String>[];

      final watcher = Watcher(
        () => signal.value,
        (newValue, _) {
          log.add("run:$newValue");
          onEffectCleanup(() => log.add("cleanup:$newValue"));
        },
      );

      signal.value = 2;
      watcher.dispose();

      expect(log, equals(["run:2", "cleanup:2"]));
    });

    test("runs multiple watcher cleanups in registration order", () {
      final signal = Signal(1);
      final order = <int>[];

      Watcher(
        () => signal.value,
        (_, __) {
          onEffectCleanup(() => order.add(1));
          onEffectCleanup(() => order.add(2));
          onEffectCleanup(() => order.add(3));
        },
      );

      signal.value = 2;
      signal.value = 3;

      expect(order, equals([1, 2, 3]));
    });
  });

  group("Watcher control", () {
    test("pause and resume replay the latest changed value", () {
      final signal = Signal(1);
      final values = <int>[];
      final watcher = Watcher(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      signal.value = 2;
      expect(values, equals([2]));

      expect(watcher.isPaused, isFalse);
      watcher.pause();
      watcher.pause();
      expect(watcher.isPaused, isTrue);

      signal.value = 10;
      expect(values, equals([2]));

      watcher.resume();
      expect(watcher.isPaused, isFalse);
      expect(values, equals([2, 10]));

      signal.value = 20;
      expect(values, equals([2, 10, 20]));
    });

    test(
      "ignoreUpdates prevents callback execution and preserves previous visible state",
      () {
        final signal = Signal(1);
        final events = <(int, int?)>[];
        final watcher = Watcher(() => signal.value, (newValue, oldValue) {
          events.add((newValue, oldValue));
        });

        signal.value = 2;
        expect(events, equals([(2, 1)]));

        watcher.ignoreUpdates(() {
          signal.value = 3;
        });

        expect(events, equals([(2, 1)]));
        expect(signal.value, equals(3));

        signal.value = 4;
        expect(events, equals([(2, 1), (4, 2)]));
      },
    );

    test("ignoreUpdates works inside nested batches", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];
      final watcher =
          Watcher(() => signal1.value + signal2.value, (newValue, _) {
        values.add(newValue);
      });

      batch(() {
        signal1.value = 3;
        signal2.value = 4;
      });
      expect(values, equals([7]));

      batch(() {
        signal1.value = 5;
        batch(() {
          watcher.ignoreUpdates(() {
            signal2.value = 6;
            signal1.value = 7;
          });
          signal2.value = 8;
        });
      });

      expect(values, equals([7, 15]));
    });

    test("ignoreUpdates restores watcher state after exceptions", () {
      final signal = Signal(1);
      final values = <int>[];
      final watcher = Watcher(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      expect(
        () => batch(() {
          signal.value = 2;
          watcher.ignoreUpdates(() {
            signal.value = 3;
            throw Exception("test exception");
          });
        }),
        throwsException,
      );

      expect(values, equals([3]));
      expect(signal.value, equals(3));

      signal.value = 4;
      expect(values, equals([3, 4]));
    });
  });

  group("Watcher detach parameter", () {
    test("links to parent scope by default", () {
      late EffectScope scope;
      late Watcher<int> watcher;

      scope = EffectScope()
        ..run(() {
          final signal = Signal(0);
          watcher = Watcher(() => signal.value, (_, __) {});
        });

      scope.dispose();

      expect(scope.isDisposed, isTrue);
      expect(watcher.isDisposed, isTrue);
    });

    test("does not link to parent scope when detach is true", () {
      late EffectScope scope;
      late Watcher<int> watcher;

      scope = EffectScope()
        ..run(() {
          final signal = Signal(0);
          watcher = Watcher(() => signal.value, (_, __) {}, detach: true);
        });

      scope.dispose();

      expect(scope.isDisposed, isTrue);
      expect(watcher.isDisposed, isFalse);

      watcher.dispose();
      expect(watcher.isDisposed, isTrue);
    });

    test("detach keeps immediately and once watchers alive after scope dispose",
        () {
      late EffectScope scope;
      late Watcher<int> immediateWatcher;
      late Watcher<int> onceWatcher;
      late Signal<int> immediateSignal;
      late Signal<int> onceSignal;
      final immediateValues = <int>[];
      final onceValues = <int>[];

      scope = EffectScope()
        ..run(() {
          immediateSignal = Signal(0);
          onceSignal = Signal(0);
          immediateWatcher = Watcher.immediately(
            () => immediateSignal.value,
            (value, _) => immediateValues.add(value),
            detach: true,
          );
          onceWatcher = Watcher.once(
            () => onceSignal.value,
            (value, _) => onceValues.add(value),
            detach: true,
          );
        });

      expect(immediateValues, equals([0]));
      expect(onceValues, isEmpty);

      scope.dispose();
      immediateSignal.value = 1;
      onceSignal.value = 1;

      expect(immediateWatcher.isDisposed, isFalse);
      expect(onceWatcher.isDisposed, isTrue);
      expect(immediateValues, equals([0, 1]));
      expect(onceValues, equals([1]));

      immediateWatcher.dispose();
    });
  });
}
