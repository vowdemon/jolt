import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

class _TestPerson {
  final String name;
  final int age;

  _TestPerson(this.name, this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestPerson && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

void main() {
  group('Signal', () {
    test('should create signal with initial value', () {
      final signal = Signal(42);
      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));
    });

    test('should update signal value', () {
      final signal = Signal(1);
      expect(signal.value, equals(1));

      signal.value = 2;
      expect(signal.value, equals(2));
      expect(signal.peek, equals(2));
    });

    test('should use set method to update value', () {
      final signal = Signal(1);
      expect(signal.value, equals(1));

      signal.set(3);
      expect(signal.value, equals(3));
      expect(signal.peek, equals(3));
    });

    test('should use get method to retrieve value', () {
      final signal = Signal(42);
      expect(signal.get(), equals(42));
    });

    test('should force update signal', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.notify();
      expect(values, equals([1, 1]));
    });

    test('should track signal in computed', () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));

      signal.value = 10;
      expect(computed.value, equals(20));
    });

    test('should track signal in effect', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      signal.value = 3;
      expect(values, equals([1, 2, 3]));
    });

    test('should emit stream events', () async {
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

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 3]));
    });

    test('should support multiple stream listeners', () async {
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

    test('should throw AssertionError when accessing disposed signal', () {
      final signal = Signal(42);
      signal.dispose();

      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(() => signal.value = 1, throwsA(isA<AssertionError>()));
      expect(() => signal.notify(), throwsA(isA<AssertionError>()));
    });

    test('should support auto dispose', () {
      final signal = Signal(42, autoDispose: true);
      expect(signal.isDisposed, isFalse);

      // 当没有引用时，信号应该被自动释放
      // 这里我们手动调用dispose来模拟
      signal.dispose();
      expect(signal.isDisposed, isTrue);
    });

    test('should work with different data types', () {
      // String signal
      final stringSignal = Signal('hello');
      expect(stringSignal.value, equals('hello'));
      stringSignal.value = 'world';
      expect(stringSignal.value, equals('world'));

      // List signal
      final listSignal = Signal<List<int>>([1, 2, 3]);
      expect(listSignal.value, equals([1, 2, 3]));
      listSignal.value = [4, 5, 6];
      expect(listSignal.value, equals([4, 5, 6]));

      // Map signal
      final mapSignal = Signal<Map<String, int>>({'a': 1});
      expect(mapSignal.value, equals({'a': 1}));
      mapSignal.value = {'b': 2};
      expect(mapSignal.value, equals({'b': 2}));

      // Nullable signal
      final nullableSignal = Signal<int?>(null);
      expect(nullableSignal.value, isNull);
      nullableSignal.value = 42;
      expect(nullableSignal.value, equals(42));
    });

    test('should work with custom objects', () {
      final personSignal = Signal(_TestPerson('Alice', 30));
      expect(personSignal.value.name, equals('Alice'));
      expect(personSignal.value.age, equals(30));

      personSignal.value = _TestPerson('Bob', 25);
      expect(personSignal.value.name, equals('Bob'));
      expect(personSignal.value.age, equals(25));
    });

    test('should handle rapid value changes', () {
      final signal = Signal(0);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      // 快速连续更改值
      for (int i = 1; i <= 100; i++) {
        signal.value = i;
      }

      // 应该只记录最后一个值（由于批处理）
      expect(values.length, equals(101)); // 初始值 + 最终值
      expect(values.last, equals(100));
    });

    test('should work with batch updates', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        signal.value = 2;
        signal.value = 3;
        signal.value = 4;
      });

      // 批处理中只应该触发一次更新
      expect(values, equals([1, 4]));
    });
  });
}
