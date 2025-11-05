import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  group('AsyncState', () {
    test('should create AsyncLoading state', () {
      const state = AsyncLoading<int>();

      expect(state.isLoading, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
    });

    test('should create AsyncSuccess state', () {
      const state = AsyncSuccess<int>(42);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.isError, isFalse);
      expect(state.data, equals(42));
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
    });

    test('should create AsyncError state', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final state = AsyncError<int>(error, stackTrace);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isTrue);
      expect(state.data, isNull);
      expect(state.error, equals(error));
      expect(state.stackTrace, equals(stackTrace));
    });

    test('should map AsyncLoading state', () {
      const state = AsyncLoading<int>();

      final result = state.map<String>(
        loading: () => 'loading',
        success: (data) => 'success: $data',
        error: (error, stackTrace) => 'error: $error',
      );

      expect(result, equals('loading'));
    });

    test('should map AsyncSuccess state', () {
      const state = AsyncSuccess<int>(42);

      final result = state.map<String>(
        loading: () => 'loading',
        success: (data) => 'success: $data',
        error: (error, stackTrace) => 'error: $error',
      );

      expect(result, equals('success: 42'));
    });

    test('should map AsyncError state', () {
      final error = Exception('Test error');
      final state = AsyncError<int>(error);

      final result = state.map<String>(
        loading: () => 'loading',
        success: (data) => 'success: $data',
        error: (error, stackTrace) => 'error: $error',
      );

      expect(result, equals('error: Exception: Test error'));
    });
  });

  group('AsyncSignal', () {
    test('should create AsyncSignal with FutureSource', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(42));
    });

    test('should create AsyncSignal with StreamSource', () async {
      final stream = Stream.value(42);
      final asyncSignal = AsyncSignal.fromStream(stream);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncSuccess<int>>());
      expect(asyncSignal.data, equals(42));
    });

    test('should handle Future error', () async {
      final future = Future<int>.error(Exception('Test error'));
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncError<int>>());
      expect(asyncSignal.data, isNull);
      expect(asyncSignal.value.error, isA<Exception>());
    });

    test('should handle Stream error', () async {
      final stream = Stream<int>.error(Exception('Test error'));
      final asyncSignal = AsyncSignal.fromStream(stream);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncError<int>>());
      expect(asyncSignal.data, isNull);
      expect(asyncSignal.value.error, isA<Exception>());
    });

    test('should emit stream events', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final List<AsyncState<int>> states = [];

      asyncSignal.listen((state) {
        states.add(state);
      }, immediately: true);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(states.length, equals(2));
      expect(states[0], isA<AsyncLoading<int>>());
      expect(states[1], isA<AsyncSuccess<int>>());
    });

    test('should dispose properly', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.isDisposed, isFalse);

      asyncSignal.dispose();
      expect(asyncSignal.isDisposed, isTrue);
    });
  });

  group('FutureSignal', () {
    test('should create FutureSignal', () async {
      final future = Future.value('hello');
      final futureSignal = AsyncSignal.fromFuture(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncSuccess<String>>());
      expect(futureSignal.data, equals('hello'));
    });

    test('should handle Future error', () async {
      final future = Future<String>.error(Exception('Test error'));
      final futureSignal = AsyncSignal.fromFuture(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncError<String>>());
      expect(futureSignal.data, isNull);
    });

    test('should work with different data types', () async {
      final listFuture = Future.value([1, 2, 3]);
      final listSignal = AsyncSignal.fromFuture(listFuture);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(listSignal.data, equals([1, 2, 3]));
    });
  });

  group('StreamSignal', () {
    test('should create StreamSignal', () async {
      final stream = Stream.value('hello');
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncSuccess<String>>());
      expect(streamSignal.data, equals('hello'));
    });

    test('should handle Stream error', () async {
      final stream = Stream<String>.error(Exception('Test error'));
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncError<String>>());
      expect(streamSignal.data, isNull);
    });

    test('should handle multiple stream values', () async {
      final stream = Stream.fromIterable(['hello', 'world']);
      final streamSignal = AsyncSignal.fromStream(stream);
      final List<String> values = [];

      streamSignal.listen((state) {
        if (state.isSuccess) {
          values.add(state.data!);
        }
      }, immediately: true);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(values.length, greaterThanOrEqualTo(2));
      expect(values, contains('hello'));
      expect(values, contains('world'));
    });

    test('should cancel stream subscription on dispose', () async {
      final stream = Stream.periodic(const Duration(milliseconds: 1), (i) => i);
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 5));

      expect(streamSignal.value, isA<AsyncSuccess<int>>());

      streamSignal.dispose();

      // 等待一段时间确保流已取消
      await Future.delayed(const Duration(milliseconds: 100));

      // dispose后不允许再读取，应该抛出AssertionError
      expect(() => streamSignal.data, throwsA(isA<AssertionError>()));
      expect(() => streamSignal.value, throwsA(isA<AssertionError>()));
    });
  });

  group('AsyncSource', () {
    test('should implement custom AsyncSource', () async {
      final source = TestSource<String>();
      final asyncSignal = AsyncSignal(source: source);

      expect(asyncSignal.value, isA<AsyncLoading<String>>());
      expect(asyncSignal.data, isNull);

      // 等待 fetch 完成，以确保 dispose 被调用
      await Future.delayed(const Duration(milliseconds: 1));

      asyncSignal.dispose();
      expect(source.isDisposed, isTrue);
    });
  });

  group('AsyncSignal integration', () {
    test('should work with computed', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final computed = Computed<String>(() {
        return asyncSignal.value.map(
              loading: () => 'Loading...',
              success: (data) => 'Data: $data',
              error: (error, stackTrace) => 'Error: $error',
            ) ??
            'Unknown';
      });

      expect(computed.value, equals('Loading...'));

      await Future.delayed(const Duration(milliseconds: 1));

      expect(computed.value, equals('Data: 42'));
    });

    test('should work with effect', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);
      final List<String> states = [];

      Effect(() {
        final state = asyncSignal.value.map(
              loading: () => 'loading',
              success: (data) => 'success: $data',
              error: (error, stackTrace) => 'error: $error',
            ) ??
            'unknown';
        states.add(state);
      });

      expect(states, equals(['loading']));

      await Future.delayed(const Duration(milliseconds: 1));

      expect(states, equals(['loading', 'success: 42']));
    });
  });
}
