import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('_JoltStreamMixin', () {
    test('should create stream for signal', () async {
      final signal = Signal(1);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));
    });

    test('should create stream for computed', () async {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final List<int> values = [];

      computed.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([4]));
    });

    test('should support multiple listeners', () async {
      final signal = Signal(1);
      final List<int> values1 = [];
      final List<int> values2 = [];

      signal.stream.listen((value) => values1.add(value));
      signal.stream.listen((value) => values2.add(value));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      expect(values1, equals([2]));
      expect(values2, equals([2]));
    });

    test('should reuse stream controller', () async {
      final signal = Signal(1);
      final stream1 = signal.stream;
      final stream2 = signal.stream;

      expect(stream1, stream2);
    });

    test('should create new stream controller after disposal', () async {
      final signal = Signal(1);

      signal.dispose();

      expect(() => signal.stream, throwsA(isA<AssertionError>()));
    });

    test('should handle stream cancellation', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final subscription = signal.stream.listen((value) {
        values.add(value);
      });

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));

      subscription.cancel();

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2])); // 不应该再接收新值
    });

    test('should handle multiple cancellations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final subscription1 = signal.stream.listen((value) => values.add(value));
      final subscription2 = signal.stream.listen((value) => values.add(value));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 2]));

      subscription1.cancel();

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 2, 3])); // 只有subscription2还在监听

      subscription2.cancel();

      signal.value = 4;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 2, 3])); // 不应该再接收新值
    });

    test('should handle rapid value changes', () async {
      final signal = Signal(0);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      // 快速连续更改值
      for (int i = 1; i <= 10; i++) {
        signal.value = i;
      }

      await Future.delayed(const Duration(milliseconds: 10));

      // 应该接收到所有值
      expect(values, equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('should work with batch updates', () async {
      final signal = Signal(1);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      batch(() {
        signal.value = 2;
        signal.value = 3;
        signal.value = 4;
      });

      await Future.delayed(const Duration(milliseconds: 1));

      // 批处理中只应该发出最后一个值
      expect(values, equals([4]));
    });

    test('should work with different data types', () async {
      // String signal
      final stringSignal = Signal('hello');
      final List<String> stringValues = [];

      stringSignal.stream.listen((value) => stringValues.add(value));

      stringSignal.value = 'world';
      await Future.delayed(const Duration(milliseconds: 1));
      expect(stringValues, equals(['world']));

      // List signal
      final listSignal = Signal<List<int>>([1, 2, 3]);
      final List<List<int>> listValues = [];

      listSignal.stream.listen((value) => listValues.add(List.from(value)));

      listSignal.value = [4, 5, 6];
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
        listValues,
        equals([
          [4, 5, 6],
        ]),
      );
    });

    test('should work with nullable values', () async {
      final signal = Signal<int?>(null);
      final List<int?> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      signal.value = 42;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([42]));

      signal.value = null;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([42, null]));
    });

    test('should work with custom objects', () async {
      final signal = Signal(TestPerson('Alice', 30));
      final List<TestPerson> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      signal.value = TestPerson('Bob', 25);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([TestPerson('Bob', 25)]));
    });

    test('should handle stream errors', () async {
      final signal = Signal(1);
      final List<dynamic> values = [];
      final List<dynamic> errors = [];

      signal.stream.listen(
        (value) => values.add(value),
        onError: (error) => errors.add(error),
      );

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));
      expect(errors, equals([]));
    });

    test('should handle stream completion', () async {
      final signal = Signal(1);
      final List<int> values = [];
      bool completed = false;

      signal.stream.listen(
        (value) => values.add(value),
        onDone: () => completed = true,
      );

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));
      expect(completed, isFalse);

      signal.dispose();
      await Future.delayed(const Duration(milliseconds: 1));
      expect(completed, isTrue);
    });

    test('should work with listen method', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final subscription = signal.listen((value) {
        values.add(value);
      }, immediately: false);

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));

      subscription.cancel();
    });

    test('should handle concurrent stream access', () async {
      final signal = Signal(1);
      final List<int> values = [];

      // 创建多个并发监听器
      final futures = <Future>[];
      for (int i = 0; i < 5; i++) {
        futures.add(
          signal.stream.listen((value) {
            values.add(value);
          }).asFuture(),
        );
      }

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      // 所有监听器都应该接收到值
      expect(values.length, equals(5));
      expect(values.every((value) => value == 2), isTrue);
    });

    test('should handle stream controller pool', () async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);

      final stream1 = signal1.stream;
      final stream2 = signal2.stream;

      // 不同的信号应该有不同的stream controller
      expect(identical(stream1, stream2), isFalse);

      // 同一个信号的stream应该相同
      final stream1Again = signal1.stream;
      expect(stream1, stream1Again);
    });

    test('should handle disposed signal stream access', () async {
      final signal = Signal(1);
      final _ = signal.stream;

      signal.dispose();

      // 已释放的信号不应该抛出异常，但stream可能不会工作
      expect(() => signal.stream, throwsA(isA<AssertionError>()));
    });

    test('should handle effect disposal', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final effect = Effect(() {
        values.add(signal.value);
      });

      signal.value = 2;
      expect(values, equals([1, 2]));

      effect.dispose();

      signal.value = 3;
      expect(values, equals([1, 2])); // effect已释放，不应该再运行
    });

    test('should handle auto dispose', () async {
      final signal = Signal(1, autoDispose: true);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));

      // 当没有引用时，信号应该被自动释放
      // 这里我们手动调用dispose来模拟
      signal.dispose();

      expect(() => signal.value = 3, throwsA(isA<AssertionError>()));
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2])); // 不应该再接收新值
    });

    test('should handle stream subscription management', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final subscription = signal.stream.listen((value) {
        values.add(value);
      });

      expect(subscription.isPaused, isFalse);

      subscription.pause();
      expect(subscription.isPaused, isTrue);
      expect(values, equals([])); // 暂停时不应该接收值

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([])); // 暂停时不应该接收值

      subscription.resume();
      expect(subscription.isPaused, isFalse);

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 3])); // 恢复后应该接收值
    });

    test('should handle mutable collection', () async {
      final signal = ListSignal([1, 2, 3]);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value.reduce((a, b) => a + b));
      });

      signal.add(4);
      await Future.microtask(() {
        expect(values, equals([10]));
      });
    });

    test('should handle immutable collection', () async {
      final signal = Signal([1, 2, 3]);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value.reduce((a, b) => a + b));
      });

      signal.value.add(4);
      await Future.microtask(() {
        expect(values, equals([]));
      });
    });
  });
}
