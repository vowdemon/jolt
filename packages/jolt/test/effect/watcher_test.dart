import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Watcher", () {
    test("tracks sources and triggers after changes", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];

      Watcher(() => (signal1.value, signal2.value, computed.value), (value, _) {
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
    });

    test("immediately runs with the current value", () {
      final signal = Signal(10);
      final values = <int>[];

      Watcher.immediately(() => signal.value, (newValue, _) {
        values.add(newValue);
      });

      expect(values, equals([10]));

      signal.value = 20;
      signal.value = 30;
      expect(values, equals([10, 20, 30]));
    });

    test("builtin comparator suppresses duplicate callbacks", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];

      Watcher(() => (signal1.value, signal2.value, computed.value), (value, _) {
        values.add(value);
      });

      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });

      expect(values, equals([(2, 4, 6)]));
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

      watcher.pause();
      signal.value = 10;
      expect(values, equals([2]));

      watcher.resume();
      expect(values, equals([2, 10]));

      signal.value = 20;
      expect(values, equals([2, 10, 20]));
    });

    test("ignoreUpdates prevents callback execution and preserves previous visible state", () {
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

      signal.value = 4;
      expect(events, equals([(2, 1), (4, 2)]));
    });

    test("ignoreUpdates works inside nested batches", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];
      final watcher = Watcher(() => signal1.value + signal2.value, (newValue, _) {
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

    test("links to parent scope when detach is explicitly false", () {
      late EffectScope scope;
      late Watcher<int> watcher;

      scope = EffectScope()
        ..run(() {
          final signal = Signal(0);
          watcher = Watcher(
            () => signal.value,
            (_, __) {},
            detach: false,
          );
        });

      scope.dispose();

      expect(scope.isDisposed, isTrue);
      expect(watcher.isDisposed, isTrue);
    });

    test("nested detached scopes keep watchers alive until their own dispose", () {
      late EffectScope outerScope;
      late EffectScope midScope;
      late Watcher<int> watcher;

      outerScope = EffectScope()
        ..run(() {
          midScope = EffectScope(detach: true)
            ..run(() {
              final signal = Signal(0);
              watcher = Watcher(() => signal.value, (_, __) {});
            });
        });

      outerScope.dispose();

      expect(outerScope.isDisposed, isTrue);
      expect(midScope.isDisposed, isFalse);
      expect(watcher.isDisposed, isFalse);

      midScope.dispose();

      expect(midScope.isDisposed, isTrue);
      expect(watcher.isDisposed, isTrue);
    });

    test("immediately and once watchers can detach from scopes", () {
      late EffectScope immediateScope;
      late Watcher<int> immediateWatcher;
      late EffectScope onceScope;
      late Watcher<int> onceWatcher;

      immediateScope = EffectScope()
        ..run(() {
          final signal = Signal(0);
          immediateWatcher = Watcher.immediately(
            () => signal.value,
            (_, __) {},
            detach: true,
          );
        });
      onceScope = EffectScope()
        ..run(() {
          final signal = Signal(0);
          onceWatcher = Watcher.once(
            () => signal.value,
            (_, __) {},
            detach: true,
          );
        });

      immediateScope.dispose();
      onceScope.dispose();

      expect(immediateWatcher.isDisposed, isFalse);
      expect(onceWatcher.isDisposed, isFalse);

      immediateWatcher.dispose();
      onceWatcher.dispose();
    });
  });
}
