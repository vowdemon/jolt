import "dart:async";
import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsUntilExtension", () {
    group("until() method", () {
      test("waits for condition to be met", () async {
        final signal = Signal(0);
        final future = signal.until((value) => value >= 5);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals(5));
      });

      test("completes immediately if condition already met", () async {
        final signal = Signal(10);
        final future = signal.until((value) => value >= 5);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(10));
      });

      test("works with different types", () async {
        final stringSignal = Signal("loading");
        final stringFuture = stringSignal.until((v) => v == "ready");
        stringSignal.value = "ready";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await stringFuture, equals("ready"));

        final boolSignal = Signal(false);
        final boolFuture = boolSignal.until((v) => v == true);
        boolSignal.value = true;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await boolFuture, equals(true));
      });

      test("works with Computed", () async {
        final source = Signal(0);
        final computed = Computed<int>(() => source.value * 2);
        final future = computed.until((value) => value >= 10);

        source.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(10));
      });

      test("completes with value that satisfied predicate", () async {
        final signal = Signal(0);
        final future = signal.until((value) => value >= 5);

        signal.value = 1;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 7; // This satisfies the condition
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals(7));
      });

      test("disposes effect when future completes", () async {
        final signal = Signal(0);
        final future = signal.until((value) => value >= 5);

        signal.value = 5;
        final result = await future;

        expect(result, equals(5));

        // Verify effect is disposed by checking signal still works
        signal.value = 0;
        final values = <int>[];
        Effect(() {
          values.add(signal.value);
        });

        signal.value = 6;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([0, 6]));
      });

      test("detach keeps effect from scope, until continues after scope dispose",
          () async {
        final signal = Signal(0);
        late Until<int> until;

        final scope = EffectScope()
          ..run(() {
            until = Until(signal, (v) => v >= 5, detach: true);
          });
        scope.dispose();

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(5));
      });

      test("Until.when factory works", () async {
        final signal = Signal(0);
        final until = Until<int>.when(signal, 5);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(5));
      });

      test("Until.changed factory works", () async {
        final signal = Signal(0);
        final until = Until<int>.changed(signal);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(5));
      });

      test("Until constructor works", () async {
        final signal = Signal(0);
        final until = Until(signal, (value) => value >= 5);

        expect(until, isA<Until>());
        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(5));
      });

      test("until returns Until with cancel method", () {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        expect(until, isA<Until>());
        expect(until.cancel, isA<Function>());
      });

      test("isCompleted and isCancelled", () async {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        expect(until.isCompleted, isFalse);
        expect(until.isCancelled, isFalse);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(until.isCompleted, isTrue);
        expect(until.isCancelled, isFalse);
      });

      test("isCancelled after cancel", () {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        until.cancel();
        expect(until.isCancelled, isTrue);
      });

      test("cancel disposes effect, future stays pending", () async {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        until.cancel();
        expect(until.isCancelled, isTrue);
        expect(until.isCompleted, isFalse);
      });

      test("cancel has no effect if condition already met", () async {
        final signal = Signal(10);
        final until = signal.until((value) => value >= 5);

        expect(await until, equals(10));
        until.cancel(); // No-op, should not throw
      });

      test("handles multiple until calls on same signal", () async {
        final signal = Signal(0);
        final future1 = signal.until((value) => value >= 5);
        final future2 = signal.until((value) => value >= 10);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future1, equals(5));

        signal.value = 10;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future2, equals(10));
      });

      test("works with nullable types", () async {
        final signal = Signal<String?>(null);
        final future =
            signal.until((value) => value != null && value.isNotEmpty);

        signal.value = "test";
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals("test"));
      });
    });

    group("untilWhen() method", () {
      test("waits for value to equal predicate", () async {
        final signal = Signal(0);
        final future = signal.untilWhen(5);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals(5));
      });

      test("completes immediately if value already equals predicate", () async {
        final signal = Signal(5);
        final future = signal.untilWhen(5);
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(5));
      });

      test("works with different types", () async {
        final stringSignal = Signal("loading");
        final stringFuture = stringSignal.untilWhen("ready");
        stringSignal.value = "ready";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await stringFuture, equals("ready"));

        final boolSignal = Signal(false);
        final boolFuture = boolSignal.untilWhen(true);
        boolSignal.value = true;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await boolFuture, equals(true));
      });

      test("works with Computed", () async {
        final source = Signal(0);
        final computed = Computed<int>(() => source.value * 2);
        final future = computed.untilWhen(10);

        source.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(10));
      });

      test("works with nullable types", () async {
        final signal = Signal<String?>(null);
        final future = signal.untilWhen("test");

        signal.value = "test";
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, equals("test"));
      });

      test("handles null predicate", () async {
        final signal = Signal<String?>("not null");
        final future = signal.untilWhen(null);

        signal.value = null;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await future, isNull);
      });
    });

    group("untilChanged() method", () {
      test("waits until value changes from current", () async {
        final signal = Signal(0);
        final future = signal.untilChanged();

        signal.value = 0;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(5));
      });

      test("completes with first value that changes", () async {
        final signal = Signal(0);
        final future = signal.untilChanged();

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals(3));
      });

      test("works with different types", () async {
        final signal = Signal("a");
        final future = signal.untilChanged();

        signal.value = "b";
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await future, equals("b"));
      });
    });
  });
}
