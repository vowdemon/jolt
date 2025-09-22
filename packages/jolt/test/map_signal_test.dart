import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('MapSignal', () {
    test('should create MapSignal with initial value', () {
      final mapSignal = MapSignal<String, int>(null);
      expect(mapSignal.value, equals({}));
      expect(mapSignal.isEmpty, isTrue);
      expect(mapSignal.length, equals(0));
    });

    test('should create MapSignal with provided value', () {
      final initialMap = {'a': 1, 'b': 2};
      final mapSignal = MapSignal(initialMap);
      expect(mapSignal.value, equals(initialMap));
      expect(mapSignal.length, equals(2));
    });

    test('should access values by key', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      expect(mapSignal['a'], equals(1));
      expect(mapSignal['b'], equals(2));
      expect(mapSignal['c'], isNull);
    });

    test('should set values by key', () {
      final mapSignal = MapSignal<String, int>(null);
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(values, equals([{}]));

      mapSignal['a'] = 1;
      expect(mapSignal['a'], equals(1));
      expect(
        values,
        equals([
          {},
          {'a': 1},
        ]),
      );
    });

    test('should update existing values', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );

      mapSignal['a'] = 10;
      expect(mapSignal['a'], equals(10));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
          {'a': 10, 'b': 2},
        ]),
      );
    });

    test('should add all entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      mapSignal.addAll({'b': 2, 'c': 3});
      expect(mapSignal.value, equals({'a': 1, 'b': 2, 'c': 3}));
      expect(
        values,
        equals([
          {'a': 1},
          {'a': 1, 'b': 2, 'c': 3},
        ]),
      );
    });

    test('should add entries from iterable', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      mapSignal.addEntries([MapEntry('b', 2), MapEntry('c', 3)]);
      expect(mapSignal.value, equals({'a': 1, 'b': 2, 'c': 3}));
      expect(
        values,
        equals([
          {'a': 1},
          {'a': 1, 'b': 2, 'c': 3},
        ]),
      );
    });

    test('should clear all entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );

      mapSignal.clear();
      expect(mapSignal.value, equals({}));
      expect(mapSignal.isEmpty, isTrue);
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
          {},
        ]),
      );
    });

    test('should check if key exists', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      expect(mapSignal.containsKey('a'), isTrue);
      expect(mapSignal.containsKey('c'), isFalse);
    });

    test('should check if value exists', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      expect(mapSignal.containsValue(1), isTrue);
      expect(mapSignal.containsValue(3), isFalse);
    });

    test('should iterate over entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<MapEntry<String, int>> entries = [];

      mapSignal.forEach((key, value) {
        entries.add(MapEntry(key, value));
      });

      expect(
        entries.map((e) => [e.key, e.value]),
        equals([
          ['a', 1],
          ['b', 2],
        ]),
      );
    });

    test('should get keys and values', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      expect(mapSignal.keys, equals(['a', 'b']));
      expect(mapSignal.values, equals([1, 2]));
    });

    test('should put if absent', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      final result = mapSignal.putIfAbsent('b', () => 2);
      expect(result, equals(2));
      expect(mapSignal['b'], equals(2));
      expect(
        values,
        equals([
          {'a': 1},
          {'a': 1, 'b': 2},
        ]),
      );

      final result2 = mapSignal.putIfAbsent('b', () => 3);
      expect(result2, equals(2)); // 应该返回现有值
      expect(mapSignal['b'], equals(2));
    });

    test('should remove entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );

      final removed = mapSignal.remove('a');
      expect(removed, equals(1));
      expect(mapSignal.value, equals({'b': 2}));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
          {'b': 2},
        ]),
      );

      final notFound = mapSignal.remove('c');
      expect(notFound, isNull);
    });

    test('should update entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );

      final updated = mapSignal.update('a', (value) => value * 2);
      expect(updated, equals(2));
      expect(mapSignal['a'], equals(2));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
          {'a': 2, 'b': 2},
        ]),
      );
    });

    test('should update all entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );

      mapSignal.updateAll((key, value) => value * 2);
      expect(mapSignal.value, equals({'a': 2, 'b': 4}));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
          {'a': 2, 'b': 4},
        ]),
      );
    });

    test('should remove entries by condition', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2, 'c': 3});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1, 'b': 2, 'c': 3},
        ]),
      );

      mapSignal.removeWhere((key, value) => value > 2);
      expect(mapSignal.value, equals({'a': 1, 'b': 2}));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2, 'c': 3},
          {'a': 1, 'b': 2},
        ]),
      );
    });

    test('should map entries', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final mapped = mapSignal.map<String, String>(
        (key, value) => MapEntry(key.toUpperCase(), value.toString()),
      );
      expect(mapped, equals({'A': '1', 'B': '2'}));
    });

    test('should cast to different types', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final casted = mapSignal.cast<String, num>();
      expect(casted, equals({'a': 1, 'b': 2}));
    });

    test('should work with computed', () {
      final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
      final computed = Computed<int>(
        () => mapSignal.values.fold(0, (sum, value) => sum + value),
      );

      expect(computed.value, equals(3));

      mapSignal['c'] = 3;
      expect(computed.value, equals(6));
    });

    test('should work with effect', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      mapSignal['b'] = 2;
      expect(
        values,
        equals([
          {'a': 1},
          {'a': 1, 'b': 2},
        ]),
      );
    });

    test('should emit stream events', () async {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      mapSignal.stream.listen((value) {
        values.add(Map.from(value));
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      mapSignal['b'] = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
        values,
        equals([
          {'a': 1, 'b': 2},
        ]),
      );
    });

    test('should work with batch updates', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      batch(() {
        mapSignal['b'] = 2;
        mapSignal['c'] = 3;
        mapSignal['a'] = 10;
      });

      // 批处理中只应该触发一次更新
      expect(
        values,
        equals([
          {'a': 1},
          {'a': 10, 'b': 2, 'c': 3},
        ]),
      );
    });

    test('should work with different data types', () {
      final mapSignal = MapSignal<int, String>(null);
      mapSignal[1] = 'one';
      mapSignal[2] = 'two';

      expect(mapSignal.value, equals({1: 'one', 2: 'two'}));
    });

    test('should work with nullable values', () {
      final mapSignal = MapSignal<String, int?>(null);
      mapSignal['a'] = 1;
      mapSignal['b'] = null;

      expect(mapSignal.value, equals({'a': 1, 'b': null}));
    });

    test('should work with custom objects', () {
      final mapSignal = MapSignal<String, TestPerson>(null);
      mapSignal['alice'] = TestPerson('Alice', 30);
      mapSignal['bob'] = TestPerson('Bob', 25);

      expect(mapSignal['alice'], equals(TestPerson('Alice', 30)));
      expect(mapSignal['bob'], equals(TestPerson('Bob', 25)));
    });

    test('should work with forceUpdate', () {
      final mapSignal = MapSignal<String, int>({'a': 1});
      final List<Map<String, int>> values = [];

      Effect(() {
        values.add(Map.from(mapSignal.value));
      });

      expect(
        values,
        equals([
          {'a': 1},
        ]),
      );

      // 直接修改内部map，然后强制更新
      mapSignal.value['b'] = 2;
      mapSignal.notify();

      expect(
        values,
        equals([
          {'a': 1},
          {'a': 1, 'b': 2},
        ]),
      );
    });
  });
}
