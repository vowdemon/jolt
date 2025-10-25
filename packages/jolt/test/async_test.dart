import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  group('AsyncState', () {
    test('should create AsyncLoading state', () {
      const state = AsyncLoading<int>();

      expect(state.isLoading, isTrue);
      expect(state.isRefreshing, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
    });

    test('should create AsyncData state', () {
      const state = AsyncData<int>(42);

      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
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
      expect(state.isRefreshing, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isTrue);
      expect(state.data, isNull);
      expect(state.error, equals(error));
      expect(state.stackTrace, equals(stackTrace));
    });

    test('should create AsyncRefreshing state', () {
      final error = Exception('Previous error');
      final stackTrace = StackTrace.current;
      final state = AsyncRefreshing<int>(42, error, stackTrace);

      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.data, equals(42));
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

    test('should map AsyncData state', () {
      const state = AsyncData<int>(42);

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

    test('should map AsyncRefreshing state', () {
      final error = Exception('Previous error');
      final state = AsyncRefreshing<int>(42, error);

      final result = state.map<String>(
        loading: () => 'loading',
        refreshing: (data, error, stackTrace) => 'refreshing: $data, $error',
        success: (data) => 'success: $data',
        error: (error, stackTrace) => 'error: $error',
      );

      expect(result, equals('refreshing: 42, Exception: Previous error'));
    });
  });

  group('AsyncSignal', () {
    test('should create AsyncSignal with FutureSource', () async {
      final future = Future.value(42);
      final asyncSignal = AsyncSignal.fromFuture(future);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncData<int>>());
      expect(asyncSignal.data, equals(42));
    });

    test('should create AsyncSignal with StreamSource', () async {
      final stream = Stream.value(42);
      final asyncSignal = AsyncSignal.fromStream(stream);

      expect(asyncSignal.value, isA<AsyncLoading<int>>());
      expect(asyncSignal.data, isNull);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(asyncSignal.value, isA<AsyncData<int>>());
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
      expect(states[1], isA<AsyncData<int>>());
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
      final futureSignal = FutureSignal(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncData<String>>());
      expect(futureSignal.data, equals('hello'));
    });

    test('should handle Future error', () async {
      final future = Future<String>.error(Exception('Test error'));
      final futureSignal = FutureSignal(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncError<String>>());
      expect(futureSignal.data, isNull);
    });

    test('should work with different data types', () async {
      final listFuture = Future.value([1, 2, 3]);
      final listSignal = FutureSignal(listFuture);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(listSignal.data, equals([1, 2, 3]));
    });
  });

  group('StreamSignal', () {
    test('should create StreamSignal', () async {
      final stream = Stream.value('hello');
      final streamSignal = StreamSignal(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncData<String>>());
      expect(streamSignal.data, equals('hello'));
    });

    test('should handle Stream error', () async {
      final stream = Stream<String>.error(Exception('Test error'));
      final streamSignal = StreamSignal(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncError<String>>());
      expect(streamSignal.data, isNull);
    });

    test('should handle multiple stream values', () async {
      final stream = Stream.fromIterable(['hello', 'world']);
      final streamSignal = StreamSignal(stream);
      final List<String> values = [];

      streamSignal.stream.listen((state) {
        if (state.isSuccess) {
          values.add(state.data!);
        }
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(values, equals(['hello', 'world']));
    });

    test('should cancel stream subscription on dispose', () async {
      final stream = Stream.periodic(const Duration(milliseconds: 1), (i) => i);
      final streamSignal = StreamSignal(stream);

      expect(streamSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 5));

      expect(streamSignal.value, isA<AsyncData<int>>());

      streamSignal.dispose();

      // 等待一段时间确保流已取消
      await Future.delayed(const Duration(milliseconds: 100));

      // dispose后不允许再读取，应该抛出SignalAssertionError
      expect(() => streamSignal.data, throwsA(isA<AssertionError>()));
      expect(() => streamSignal.value, throwsA(isA<AssertionError>()));
    });
  });

  group('AsyncSource', () {
    test('should implement custom AsyncSource', () {
      final source = TestSource<String>();
      final asyncSignal = AsyncSignal(source as AsyncSource<String>);

      expect(asyncSignal.value, isA<AsyncLoading<String>>());
      expect(asyncSignal.data, isNull);

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
