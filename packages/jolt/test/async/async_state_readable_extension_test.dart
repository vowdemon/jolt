import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("AsyncStateReadableX", () {
    test("mirrors loading, success, error, and nullable success states", () {
      final failure = StateError("failed");
      final stackTrace = StackTrace.current;
      final source = Signal<AsyncState<int?>>(const AsyncLoading<int?>());
      final Readable<AsyncState<int?>> readable = source;

      expect(readable.isLoading, isTrue);
      expect(readable.isSuccess, isFalse);
      expect(readable.isError, isFalse);
      expect(readable.data, isNull);
      expect(readable.error, isNull);
      expect(readable.stackTrace, isNull);
      expect(readable.map(loading: () => "loading"), "loading");

      source.value = const AsyncSuccess<int?>(null);

      expect(readable.isLoading, isFalse);
      expect(readable.isSuccess, isTrue);
      expect(readable.isError, isFalse);
      expect(readable.data, isNull);
      expect(readable.map(success: (value) => value ?? "null"), "null");

      source.value = AsyncError<int?>(failure, stackTrace);

      expect(readable.isLoading, isFalse);
      expect(readable.isSuccess, isFalse);
      expect(readable.isError, isTrue);
      expect(readable.error, same(failure));
      expect(readable.stackTrace, same(stackTrace));
      expect(
        readable.map(
          error: (error, trace) => [error, trace],
        ),
        [failure, stackTrace],
      );
      expect(readable.map<String>(), isNull);
    });

    test("is shared by async signals, computed values, and readonly views", () {
      final AsyncSignal<int> asyncSignal = AsyncSignal(
        initialValue: const AsyncSuccess(1),
      );
      final state = Signal<AsyncState<int>>(const AsyncSuccess(2));
      final Computed<AsyncState<int>> computed = Computed(() => state.value);
      final Readonly<AsyncState<int>> readonly = state.readonly();

      expect(asyncSignal.data, 1);
      expect(computed.data, 2);
      expect(readonly.data, 2);
    });

    test("tracks value reads and always reflects the replacement state", () {
      final state = Signal<AsyncState<int>>(const AsyncLoading<int>());
      final Readable<AsyncState<int>> readable = state;
      final observed = <String?>[];
      final effect = Effect(() {
        observed.add(
          readable.map(
            loading: () => "loading",
            success: (value) => "success:$value",
            error: (error, _) => "error:$error",
          ),
        );
      });

      state.value = const AsyncSuccess(3);
      state.value = const AsyncError<int>("failed");

      expect(observed, ["loading", "success:3", "error:failed"]);
      effect.dispose();
    });
  });
}
