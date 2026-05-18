import "dart:async";

import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsUntilExtension", () {
    group("until()", () {
      test("waits until predicate is satisfied", () async {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 7;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await until, equals(7));
      });

      test("completes immediately when already satisfied", () async {
        final signal = Signal(10);
        final until = signal.until((value) => value >= 5);

        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(10));
      });

      test("reports isCompleted after success", () async {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        expect(until.isCompleted, isFalse);
        expect(until.isCancelled, isFalse);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(until.isCompleted, isTrue);
        expect(until.isCancelled, isFalse);
        expect(await until, equals(5));
      });

      test("cancel leaves future pending and ignores later matches", () async {
        final signal = Signal(0);
        final until = signal.until((value) => value >= 5);

        until.cancel();
        expect(until.isCancelled, isTrue);
        expect(until.isCompleted, isFalse);

        signal.value = 5;

        expect(
          await until.timeout(
            const Duration(milliseconds: 20),
            onTimeout: () => -1,
          ),
          equals(-1),
        );
      });

      test("cancel is no-op after completion", () async {
        final signal = Signal(10);
        final until = signal.until((value) => value >= 5);

        expect(await until, equals(10));
        until.cancel();
        expect(until.isCompleted, isTrue);
        expect(until.isCancelled, isFalse);
      });

      test("detach true survives scope dispose", () async {
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

      test("detach false stops when scope is disposed", () async {
        final signal = Signal(0);
        late Until<int> until;

        final scope = EffectScope()
          ..run(() {
            until = Until(signal, (v) => v >= 5, detach: false);
          });

        scope.dispose();
        signal.value = 5;

        expect(
          await until.timeout(
            const Duration(milliseconds: 20),
            onTimeout: () => -1,
          ),
          equals(-1),
        );
        expect(until.isCompleted, isFalse);
        expect(until.isCancelled, isFalse);
      });

      test("multiple until on same source complete independently", () async {
        final signal = Signal(0);
        final until1 = signal.until((value) => value >= 5);
        final until2 = signal.until((value) => value >= 10);

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until1, equals(5));

        signal.value = 10;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until2, equals(10));
      });

      test("works when source is Computed", () async {
        final source = Signal(0);
        final computed = Computed<int>(() => source.value * 2);
        final until = computed.until((value) => value >= 10);

        source.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(10));
      });
    });

    group("untilWhen()", () {
      test("waits until value equals target", () async {
        final signal = Signal(0);
        final until = signal.untilWhen(5);

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await until, equals(5));
      });

      test("completes immediately when value already matches", () async {
        final signal = Signal(5);
        final until = signal.untilWhen(5);

        await Future.delayed(const Duration(milliseconds: 1));
        expect(await until, equals(5));
      });
    });

    group("untilChanged()", () {
      test("ignores writes equal to snapshot and completes on change", () async {
        final signal = Signal(0);
        final until = signal.untilChanged();

        signal.value = 0;
        await Future.delayed(const Duration(milliseconds: 1));

        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(await until, equals(5));
      });
    });

    group("Future delegation", () {
      test("then, whenComplete, and catchError forward to the completer", () async {
        final signal = Signal(5);
        final until = signal.until((value) => value >= 5);
        var completed = false;

        expect(await until.catchError((_) => -1), equals(5));

        final result = await until
            .whenComplete(() => completed = true)
            .then((value) => value + 1);

        expect(result, equals(6));
        expect(completed, isTrue);
      });

      test("timeout and asStream forward to the completer", () async {
        final signal = Signal(0);
        final pending = signal.until((value) => value >= 5);
        final streamValues = <int>[];

        final subscription = pending.asStream().listen(streamValues.add);
        signal.value = 5;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(streamValues, equals([5]));
        await subscription.cancel();

        expect(
          await pending.timeout(
            const Duration(milliseconds: 20),
            onTimeout: () => -1,
          ),
          equals(5),
        );

        final stalled = signal.until((value) => value > 100);
        expect(
          await stalled.timeout(
            const Duration(milliseconds: 20),
            onTimeout: () => -1,
          ),
          equals(-1),
        );
      });
    });
  });
}
