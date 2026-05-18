import "dart:async";

import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

import "../test_utils.dart";

class ManualAsyncSource<T> extends AsyncSource<T> {
  final Completer<void> _completer = Completer<void>();
  void Function(AsyncState<T> state)? _emit;
  bool _disposed = false;

  @override
  Future<void> subscribe(void Function(AsyncState<T> state) emit) async {
    _emit = emit;
    await _completer.future;
  }

  void emit(AsyncState<T> state) {
    _emit?.call(state);
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    complete();
  }

  bool get isDisposed => _disposed;
}

void main() {
  group("AsyncSignal", () {
    test("should create AsyncSignal with FutureSource", () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(42));
    });

    test("should create AsyncSignal with StreamSource", () async {
      final stream = Stream.value(42);
      final asyncSignal = AsyncSignal.fromStream(stream);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(42));
    });

    test("should handle Future error", () async {
      final future = Future<int>.error(Exception("Test error"));
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncError<int>>());
      expect(asyncSignal.data, isNull);
      expect(asyncSignal.value.error, isA<Exception>());
    });

    test("should handle Stream error", () async {
      final stream = Stream<int>.error(Exception("Test error"));
      final asyncSignal = AsyncSignal.fromStream(stream);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncError<int>>());
      expect(asyncSignal.data, isNull);
      expect(asyncSignal.value.error, isA<Exception>());
    });

    test("should emit stream events", () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final states = <AsyncState<int>>[];

      asyncSignal.listen(states.add, immediately: true);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(states.length, equals(2));
      expect(states[0], isA<AsyncSuccess<int>>());
      expect(states[1], isA<AsyncSuccess<int>>());
    });

    test("should fetch a new source from the public AsyncSignal API", () async {
      final asyncSignal = AsyncSignal<int>(
        initialValue: const AsyncSuccess(1),
      );

      await asyncSignal.fetch(FutureSource(Future.value(2)));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(2));
    });

    test("should expose AsyncState convenience members on AsyncSignal", () {
      final error = Exception("Test error");
      final stackTrace = StackTrace.current;
      final asyncSignal = AsyncSignal<int>(
        initialValue: AsyncError(error, stackTrace),
      );

      expect(asyncSignal.isLoading, isFalse);
      expect(asyncSignal.isSuccess, isFalse);
      expect(asyncSignal.isError, isTrue);
      expect(asyncSignal.data, isNull);
      expect(asyncSignal.error, same(error));
      expect(asyncSignal.stackTrace, same(stackTrace));
      expect(
        asyncSignal.map(
          loading: () => "loading",
          success: (data) => "success: $data",
          error: (error, stackTrace) => "error: $error",
        ),
        equals("error: Exception: Test error"),
      );
    });

    test("should ignore stale emissions from previous fetch", () async {
      final firstSource = ManualAsyncSource<int>();
      final secondSource = ManualAsyncSource<int>();
      final asyncSignal = AsyncSignal<int>();

      final firstFetch = asyncSignal.fetch(firstSource);
      firstSource.emit(const AsyncSuccess(1));
      expect(asyncSignal.data, equals(1));

      final secondFetch = asyncSignal.fetch(secondSource);
      secondSource.emit(const AsyncSuccess(2));
      expect(asyncSignal.data, equals(2));

      firstSource.emit(const AsyncSuccess(99));
      expect(asyncSignal.data, equals(2));

      firstSource.complete();
      secondSource.complete();
      await Future.wait([firstFetch, secondFetch]);
    });
  });

  group("AsyncSource", () {
    test("should implement custom AsyncSource", () async {
      final source = TestSource<String>();
      final asyncSignal = AsyncSignal(source: source);

      expect(asyncSignal.value, isA<AsyncLoading<String>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      asyncSignal.dispose();
      expect(source.isDisposed, isTrue);
    });

    test("should dispose active source when AsyncSignal is disposed", () async {
      final source = ManualAsyncSource<String>();
      final asyncSignal = AsyncSignal<String>(source: source);

      await Future.delayed(const Duration(milliseconds: 1));

      asyncSignal.dispose();

      expect(source.isDisposed, isTrue);
    });
  });

  group("AsyncSignal integration", () {
    test("should work with computed", () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final computed = Computed<String>(() =>
          asyncSignal.value.map(
            loading: () => "Loading...",
            success: (data) => "Data: $data",
            error: (error, stackTrace) => "Error: $error",
          ) ??
          "Unknown");

      expect(computed.value, equals("Loading..."));

      await Future.delayed(const Duration(milliseconds: 1));

      expect(computed.value, equals("Data: 42"));
    });

    test("should work with effect", () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final states = <String>[];

      Effect(() {
        final state = asyncSignal.value.map(
              loading: () => "loading",
              success: (data) => "success: $data",
              error: (error, stackTrace) => "error: $error",
            ) ??
            "unknown";
        states.add(state);
      });

      expect(states, equals(["loading"]));

      await Future.delayed(const Duration(milliseconds: 1));

      expect(states, equals(["loading", "success: 42"]));
    });
  });
}
