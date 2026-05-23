import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsStreamExtension", () {
    group("stream", () {
      test("emits on change but not on subscribe", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3]));
      });

      test("does not emit on same-value writes", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        signal.value = 1;
        signal.value = 1;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));
      });

      test("works when source is Computed", () async {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);
        final values = <int>[];

        computed.stream.listen(values.add);

        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, isEmpty);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([4]));

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([4, 6]));
      });

      test("broadcasts each change to multiple listeners", () async {
        final signal = Signal(1);
        final values1 = <int>[];
        final values2 = <int>[];

        signal.stream.listen(values1.add);
        signal.stream.listen(values2.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(values1, equals([2]));
        expect(values2, equals([2]));
      });

      test("reuses stream instance for signal and readonly views", () async {
        final signal = Signal(1);
        final readonly1 = signal.readonly();
        final readonly2 = signal.readonly();
        final values = <int>[];

        expect(signal.stream, same(readonly1.stream));
        expect(readonly1.stream, same(readonly2.stream));

        readonly2.stream.listen(values.add);
        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));

        expect(values, equals([2]));
      });

      test("batch emits only final value", () async {
        final signal = Signal(1);
        final values = <int>[];

        signal.stream.listen(values.add);

        batch(() {
          signal
            ..value = 2
            ..value = 3
            ..value = 4;
        });

        await Future<void>.delayed(Duration.zero);
        expect(values, equals([4]));
      });

      test("batch defers each signal stream until batch ends", () async {
        final first = Signal(1);
        final second = Signal(2);
        final firstValues = <int>[];
        final secondValues = <int>[];

        first.stream.listen(firstValues.add);
        second.stream.listen(secondValues.add);

        batch(() {
          first.value = 10;
          second.value = 20;
        });

        await Future<void>.delayed(Duration.zero);
        expect(firstValues, equals([10]));
        expect(secondValues, equals([20]));
      });

      test("stops emitting after dispose while keeping stream identity",
          () async {
        final signal = Signal(1);
        final stream = signal.stream;
        final values = <int>[];

        final subscription = stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        signal.dispose();
        expect(signal.stream, same(stream));

        signal.value = 3;
        signal.notify();
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        await subscription.cancel();
      });

      test("stops emitting after all subscriptions cancel", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription1 = signal.stream.listen(values.add);
        final subscription2 = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 2]));

        await subscription1.cancel();
        await subscription2.cancel();

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 2]));
      });

      test("emits again after all subscriptions were cancelled", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        await subscription.cancel();

        signal.stream.listen(values.add);
        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2, 3]));
      });
    });

    group("listen", () {
      test("immediately true emits current value then changes", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.listen(values.add, immediately: true);

        await Future.microtask(() {});
        expect(values, equals([1]));

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([1, 2]));

        await subscription.cancel();
      });

      test("immediately true on disposed emits one snapshot only", () async {
        final signal = Signal(1)..dispose();
        final values = <int>[];
        final subscription = signal.listen(values.add, immediately: true);

        await Future<void>.delayed(Duration.zero);
        expect(values, equals([1]));

        signal.value = 2;
        signal.notify();
        await Future<void>.delayed(Duration.zero);
        expect(values, equals([1]));

        await subscription.cancel();
      });
    });

    group("subscription", () {
      test("cancel stops further emissions", () async {
        final signal = Signal(1);
        final values = <int>[];

        final subscription = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        await subscription.cancel();

        signal.value = 3;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));
      });
    });
  });
}
