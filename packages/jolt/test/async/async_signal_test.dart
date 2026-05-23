import "dart:async";

import "package:jolt/jolt.dart";
import "package:test/test.dart";

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

class TrackingStreamSource<T> extends StreamSource<T> {
  TrackingStreamSource(super.stream);

  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

void main() {
  group("AsyncSignal.fromFuture", () {
    test("starts loading then resolves to success", () async {
      final asyncSignal = AsyncSignal.fromFuture(Future.value(42));

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await asyncSignal.until((state) => state.isSuccess);

      expect(asyncSignal.data, equals(42));
    });

    test("starts loading then resolves to error", () async {
      final asyncSignal = AsyncSignal.fromFuture(
        Future<int>.error(Exception("Test error")),
      );

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await asyncSignal.until((state) => state.isError);

      expect(asyncSignal.data, isNull);
      expect(asyncSignal.error, isA<Exception>());
    });
  });

  group("AsyncSignal.fromStream", () {
    test("starts loading then resolves first value to success", () async {
      final asyncSignal = AsyncSignal.fromStream(Stream.value(42));

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await asyncSignal.until((state) => state.isSuccess);

      expect(asyncSignal.data, equals(42));
    });

    test("starts loading then resolves stream errors", () async {
      final asyncSignal = AsyncSignal.fromStream(
        Stream<int>.error(Exception("Test error")),
      );

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await asyncSignal.until((state) => state.isError);

      expect(asyncSignal.data, isNull);
      expect(asyncSignal.error, isA<Exception>());
    });

    test("emits success for each stream value", () async {
      final controller = StreamController<int>();
      final asyncSignal = AsyncSignal.fromStream(controller.stream);
      final values = <int>[];

      asyncSignal.listen((state) {
        if (state.isSuccess) {
          values.add(state.data!);
        }
      });

      controller.add(1);
      await asyncSignal.until((state) => state.data == 1);
      controller.add(2);
      await asyncSignal.until((state) => state.data == 2);
      controller.add(3);
      await asyncSignal.until((state) => state.data == 3);

      expect(values, equals([1, 2, 3]));
      await controller.close();
    });

    test("disposes the stream source when the stream completes", () async {
      final controller = StreamController<int>();
      final source = TrackingStreamSource<int>(controller.stream);
      final asyncSignal = AsyncSignal<int>();
      final fetch = asyncSignal.fetch(source);

      controller.add(42);
      await asyncSignal.until((state) => state.data == 42);
      await controller.close();
      await fetch;

      expect(source.disposeCount, equals(1));
    });

    test("stops receiving values after dispose", () async {
      final controller = StreamController<int>();
      final asyncSignal = AsyncSignal.fromStream(controller.stream);
      final values = <int>[];

      asyncSignal.listen((state) {
        if (state.isSuccess) {
          values.add(state.data!);
        }
      });

      controller.add(1);
      await asyncSignal.until((state) => state.data == 1);
      expect(values, equals([1]));

      asyncSignal.dispose();

      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(asyncSignal.data, equals(1));
      expect(values, equals([1]));
    });
  });

  group("AsyncSignal.fetch", () {
    test("replaces the active source", () async {
      final asyncSignal = AsyncSignal<int>(
        initialValue: const AsyncSuccess(1),
      );

      await asyncSignal.fetch(FutureSource(Future.value(2)));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(2));
    });

    test("disposes the previous source when called again", () async {
      final firstSource = ManualAsyncSource<int>();
      final secondSource = ManualAsyncSource<int>();
      final asyncSignal = AsyncSignal<int>();

      final firstFetch = asyncSignal.fetch(firstSource);
      expect(firstSource.isDisposed, isFalse);

      final secondFetch = asyncSignal.fetch(secondSource);
      expect(firstSource.isDisposed, isTrue);
      expect(secondSource.isDisposed, isFalse);

      secondSource.complete();
      await Future.wait([firstFetch, secondFetch]);

      expect(secondSource.isDisposed, isTrue);
    });

    test("keeps the previous value until the new source emits", () async {
      final firstSource = ManualAsyncSource<int>();
      final secondSource = ManualAsyncSource<int>();
      final asyncSignal = AsyncSignal<int>();

      final firstFetch = asyncSignal.fetch(firstSource);
      firstSource.emit(const AsyncSuccess(1));
      expect(asyncSignal.data, equals(1));

      final secondFetch = asyncSignal.fetch(secondSource);
      expect(asyncSignal.data, equals(1));

      secondSource.emit(const AsyncSuccess(2));
      expect(asyncSignal.data, equals(2));

      firstSource.complete();
      secondSource.complete();
      await Future.wait([firstFetch, secondFetch]);
    });

    test("ignores stale emissions from a replaced source", () async {
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

    test("is ignored after the signal is disposed", () async {
      final asyncSignal = AsyncSignal<int>();
      asyncSignal.dispose();

      await asyncSignal.fetch(FutureSource(Future.value(1)));

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);
    });
  });

  group("AsyncSignal lifecycle", () {
    test("disposes the active source when disposed", () async {
      final source = ManualAsyncSource<String>();
      final asyncSignal = AsyncSignal<String>();
      final fetch = asyncSignal.fetch(source);

      asyncSignal.dispose();

      expect(source.isDisposed, isTrue);
      source.complete();
      await fetch;
    });
  });

  group("AsyncSignal convenience getters", () {
    test("mirror loading, success, and error state", () async {
      final loading = AsyncSignal<int>();
      expect(loading.isLoading, isTrue);
      expect(loading.isSuccess, isFalse);
      expect(loading.isError, isFalse);
      expect(loading.data, isNull);
      expect(loading.error, isNull);
      expect(loading.stackTrace, isNull);
      expect(
        loading.map(
          loading: () => "loading",
          success: (data) => "success: $data",
          error: (error, stackTrace) => "error: $error",
        ),
        equals("loading"),
      );

      await loading.fetch(FutureSource(Future.value(42)));

      expect(loading.isLoading, isFalse);
      expect(loading.isSuccess, isTrue);
      expect(loading.isError, isFalse);
      expect(loading.data, equals(42));
      expect(
        loading.map(
          loading: () => "loading",
          success: (data) => "success: $data",
        ),
        equals("success: 42"),
      );

      final failed = AsyncSignal.fromFuture(
        Future<int>.error(Exception("failed"), StackTrace.current),
      );
      await failed.until((state) => state.isError);

      expect(failed.isLoading, isFalse);
      expect(failed.isSuccess, isFalse);
      expect(failed.isError, isTrue);
      expect(failed.data, isNull);
      expect(failed.error, isA<Exception>());
      expect(failed.stackTrace, isNotNull);
    });
  });

  group("AsyncSignal integration", () {
    test("propagates async state changes to effects", () async {
      final asyncSignal = AsyncSignal.fromFuture(Future.value(42));
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

      await asyncSignal.until((state) => state.isSuccess);

      expect(states, equals(["loading", "success: 42"]));
    });
  });
}
