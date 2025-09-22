import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('SetSignal', () {
    test('should create SetSignal with initial value', () {
      final setSignal = SetSignal<int>(null);
      expect(setSignal.value, equals(<int>{}));
      expect(setSignal.isEmpty, isTrue);
      expect(setSignal.length, equals(0));
    });

    test('should create SetSignal with provided value', () {
      final initialSet = {1, 2, 3};
      final setSignal = SetSignal(initialSet);
      expect(setSignal.value, equals(initialSet));
      expect(setSignal.length, equals(3));
    });

    test('should add elements', () {
      final setSignal = SetSignal<int>(null);
      final List<Set<int>> values = [];

      Effect(() {
        Effect(() {
          values.add(Set.from(setSignal.value));
        });
      });

      expect(values, equals([<int>{}]));

      final result = setSignal.add(1);
      expect(result, isTrue);
      expect(setSignal.contains(1), isTrue);
      expect(
        values,
        equals([
          <int>{},
          {1},
        ]),
      );

      final result2 = setSignal.add(1);
      expect(result2, isFalse); // 重复元素
      expect(
        values,
        equals([
          <int>{},
          {1},
        ]),
      );
    });

    test('should add all elements', () {
      final setSignal = SetSignal<int>({1});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1},
        ]),
      );

      setSignal.addAll({2, 3, 4});
      expect(setSignal.value, equals({1, 2, 3, 4}));
      expect(
        values,
        equals([
          {1},
          {1, 2, 3, 4},
        ]),
      );
    });

    test('should remove elements', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final List<Set<int>> values = [];

      Effect(() {
        Effect(() {
          values.add(Set.from(setSignal.value));
        });
      });

      expect(
        values,
        equals([
          {1, 2, 3},
        ]),
      );

      final result = setSignal.remove(2);
      expect(result, isTrue);
      expect(setSignal.value, equals({1, 3}));
      expect(
        values,
        equals([
          {1, 2, 3},
          {1, 3},
        ]),
      );

      final result2 = setSignal.remove(4);
      expect(result2, isFalse); // 不存在的元素
      expect(
        values,
        equals([
          {1, 2, 3},
          {1, 3},
        ]),
      );
    });

    test('should clear all elements', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1, 2, 3},
        ]),
      );

      setSignal.clear();
      expect(setSignal.value, equals(<int>{}));
      expect(setSignal.isEmpty, isTrue);
      expect(
        values,
        equals([
          {1, 2, 3},
          <int>{},
        ]),
      );
    });

    test('should check if element exists', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      expect(setSignal.contains(1), isTrue);
      expect(setSignal.contains(4), isFalse);
    });

    test('should iterate over elements', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final List<int> elements = [];

      for (var element in setSignal) {
        elements.add(element);
      }

      expect(elements.length, equals(3));
      expect(elements.contains(1), isTrue);
      expect(elements.contains(2), isTrue);
      expect(elements.contains(3), isTrue);
    });

    test('should get first and last elements', () {
      final setSignal = SetSignal<int>({3, 1, 2});
      expect(setSignal.first, equals(3));
      expect(setSignal.last, equals(2));
    });

    test('should get single element', () {
      final setSignal = SetSignal<int>({42});
      expect(setSignal.single, equals(42));

      expect(() {
        final multiSet = SetSignal<int>({1, 2});
        multiSet.single;
      }, throwsA(isA<StateError>()));
    });

    test('should check if empty or not empty', () {
      final emptySet = SetSignal<int>(null);
      final nonEmptySet = SetSignal<int>({1, 2, 3});

      expect(emptySet.isEmpty, isTrue);
      expect(emptySet.isNotEmpty, isFalse);
      expect(nonEmptySet.isEmpty, isFalse);
      expect(nonEmptySet.isNotEmpty, isTrue);
    });

    test('should get length', () {
      final setSignal = SetSignal<int>(null);
      expect(setSignal.length, equals(0));

      setSignal.add(1);
      expect(setSignal.length, equals(1));

      setSignal.addAll({2, 3});
      expect(setSignal.length, equals(3));
    });

    test('should perform set operations', () {
      final set1 = SetSignal<int>({1, 2, 3});
      final set2 = SetSignal<int>({2, 3, 4});

      final union = set1.union(set2.value);
      expect(union, equals({1, 2, 3, 4}));

      final intersection = set1.intersection(set2.value);
      expect(intersection, equals({2, 3}));

      final difference = set1.difference(set2.value);
      expect(difference, equals({1}));
    });

    test('should check if contains all elements', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      expect(setSignal.containsAll({1, 2, 3}), isTrue);
      expect(setSignal.containsAll({1, 2, 6}), isFalse);
    });

    test('should remove all elements', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
        ]),
      );

      setSignal.removeAll({2, 4});
      expect(setSignal.value, equals({1, 3, 5}));
      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
          {1, 3, 5},
        ]),
      );
    });

    test('should retain all elements', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
        ]),
      );

      setSignal.retainAll({2, 4});
      expect(setSignal.value, equals({2, 4}));
      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
          {2, 4},
        ]),
      );
    });

    test('should remove elements by condition', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
        ]),
      );

      setSignal.removeWhere((element) => element > 3);
      expect(setSignal.value, equals({1, 2, 3}));
      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
          {1, 2, 3},
        ]),
      );
    });

    test('should retain elements by condition', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
        ]),
      );

      setSignal.retainWhere((element) => element % 2 == 0);
      expect(setSignal.value, equals({2, 4}));
      expect(
        values,
        equals([
          {1, 2, 3, 4, 5},
          {2, 4},
        ]),
      );
    });

    test('should cast to different type', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final casted = setSignal.cast<num>();
      expect(casted, equals({1, 2, 3}));
    });

    test('should convert to list', () {
      final setSignal = SetSignal<int>({3, 1, 2});
      final list = setSignal.toList();
      expect(list.length, equals(3));
      expect(list.contains(1), isTrue);
      expect(list.contains(2), isTrue);
      expect(list.contains(3), isTrue);
    });

    test('should convert to set', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final set = setSignal.toSet();
      expect(set, equals({1, 2, 3}));
    });

    test('should work with computed', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final computed = Computed<int>(
        () => setSignal.value.fold(0, (sum, value) => sum + value),
      );

      expect(computed.value, equals(6));

      setSignal.add(4);
      expect(computed.value, equals(10));
    });

    test('should work with effect', () {
      final setSignal = SetSignal<int>({1});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1},
        ]),
      );

      setSignal.add(2);
      expect(
        values,
        equals([
          {1},
          {1, 2},
        ]),
      );
    });

    test('should emit stream events', () async {
      final setSignal = SetSignal<int>({1});
      final List<Set<int>> values = [];

      setSignal.stream.listen((value) {
        values.add(Set.from(value));
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      setSignal.add(2);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
        values,
        equals([
          {1, 2},
        ]),
      );
    });

    test('should work with batch updates', () {
      final setSignal = SetSignal<int>({1});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1},
        ]),
      );

      batch(() {
        setSignal.add(2);
        setSignal.add(3);
        setSignal.remove(1);
      });

      // 批处理中只应该触发一次更新
      expect(
        values,
        equals([
          {1},
          {2, 3},
        ]),
      );
    });

    test('should work with different data types', () {
      final setSignal = SetSignal<String>(null);
      setSignal.add('hello');
      setSignal.add('world');

      expect(setSignal.value, equals({'hello', 'world'}));
    });

    test('should work with nullable values', () {
      final setSignal = SetSignal<int?>(null);
      setSignal.add(1);
      setSignal.add(null);

      expect(setSignal.value, equals({1, null}));
    });

    test('should work with custom objects', () {
      final setSignal = SetSignal<TestPerson>(null);
      setSignal.add(TestPerson('Alice', 30));
      setSignal.add(TestPerson('Bob', 25));

      expect(setSignal.contains(TestPerson('Alice', 30)), isTrue);
      expect(setSignal.contains(TestPerson('Bob', 25)), isTrue);
    });

    test('should work with forceUpdate', () {
      final setSignal = SetSignal<int>({1});
      final List<Set<int>> values = [];

      Effect(() {
        values.add(Set.from(setSignal.value));
      });

      expect(
        values,
        equals([
          {1},
        ]),
      );

      // 直接修改内部set，然后强制更新
      setSignal.value.add(2);
      setSignal.notify();

      expect(
        values,
        equals([
          {1},
          {1, 2},
        ]),
      );
    });

    test('should work with iterator', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final List<int> elements = [];

      for (final element in setSignal) {
        elements.add(element);
      }

      expect(elements.length, equals(3));
      expect(elements.contains(1), isTrue);
      expect(elements.contains(2), isTrue);
      expect(elements.contains(3), isTrue);
    });

    test('should work with elementAt', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      expect(setSignal.elementAt(0), equals(1));
      expect(setSignal.elementAt(1), equals(2));
      expect(setSignal.elementAt(2), equals(3));
    });

    test('should work with lookup', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      expect(setSignal.lookup(2), equals(2));
      expect(setSignal.lookup(4), isNull);
    });

    test('should work with any and every', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});

      expect(setSignal.any((element) => element > 3), isTrue);
      expect(setSignal.any((element) => element > 5), isFalse);

      expect(setSignal.every((element) => element > 0), isTrue);
      expect(setSignal.every((element) => element > 2), isFalse);
    });

    test('should work with firstWhere and lastWhere', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});

      expect(setSignal.firstWhere((element) => element > 2), equals(3));
      expect(setSignal.lastWhere((element) => element < 4), equals(3));

      expect(() {
        setSignal.firstWhere((element) => element > 5);
      }, throwsA(isA<StateError>()));
    });

    test('should work with singleWhere', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});

      expect(setSignal.singleWhere((element) => element == 3), equals(3));

      expect(() {
        setSignal.singleWhere((element) => element > 2);
      }, throwsA(isA<StateError>()));
    });

    test('should work with fold', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final sum = setSignal.fold(0, (previous, element) => previous + element);
      expect(sum, equals(6));
    });

    test('should work with map', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final mapped = setSignal.map((element) => element * 2);
      expect(mapped, equals({2, 4, 6}));
    });

    test('should work with where', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
      final filtered = setSignal.where((element) => element % 2 == 0);
      expect(filtered, equals({2, 4}));
    });

    test('should work with expand', () {
      final setSignal = SetSignal<int>({1, 2});
      final expanded = setSignal.expand((element) => [element, element * 2]);
      expect(expanded, equals([1, 2, 2, 4]));
    });

    test('should work with followedBy', () {
      final setSignal = SetSignal<int>({1, 2});
      final followed = setSignal.followedBy({3, 4});
      expect(followed, equals({1, 2, 3, 4}));
    });

    test('should work with skip and take', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});

      final skipped = setSignal.skip(2);
      expect(skipped, equals({3, 4, 5}));

      final taken = setSignal.take(3);
      expect(taken, equals({1, 2, 3}));
    });

    test('should work with skipWhile and takeWhile', () {
      final setSignal = SetSignal<int>({1, 2, 3, 4, 5});

      final skipped = setSignal.skipWhile((element) => element < 3);
      expect(skipped, equals({3, 4, 5}));

      final taken = setSignal.takeWhile((element) => element < 4);
      expect(taken, equals({1, 2, 3}));
    });

    test('should work with whereType', () {
      final setSignal = SetSignal<Object>({1, 'hello', 2, 'world'});
      final numbers = setSignal.whereType<int>();
      expect(numbers, equals({1, 2}));
    });

    test('should work with join', () {
      final setSignal = SetSignal<String>({'a', 'b', 'c'});
      expect(setSignal.join(','), equals('a,b,c'));
      expect(setSignal.join(), equals('abc'));
    });

    test('should work with reduce', () {
      final setSignal = SetSignal<int>({1, 2, 3});
      final sum = setSignal.reduce((value, element) => value + element);
      expect(sum, equals(6));
    });
  });
}
