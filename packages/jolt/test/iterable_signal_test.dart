import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('IterableSignal', () {
    test('should create IterableSignal with initial value', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      expect(iterableSignal.value, equals(iterable));
      expect(iterableSignal.length, equals(3));
    });

    test('should iterate over elements', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final List<int> elements = [];

      for (final element in iterableSignal) {
        elements.add(element);
      }

      expect(elements, equals([1, 2, 3]));
    });

    test('should check if empty or not empty', () {
      final emptyIterable = <int>[];
      final nonEmptyIterable = [1, 2, 3];

      final emptySignal = IterableSignal.value(emptyIterable);
      final nonEmptySignal = IterableSignal.value(nonEmptyIterable);

      expect(emptySignal.isEmpty, isTrue);
      expect(emptySignal.isNotEmpty, isFalse);
      expect(nonEmptySignal.isEmpty, isFalse);
      expect(nonEmptySignal.isNotEmpty, isTrue);
    });

    test('should get first and last elements', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.first, equals(1));
      expect(iterableSignal.last, equals(3));
    });

    test('should get single element', () {
      final singleIterable = [42];
      final multiIterable = [1, 2];

      final singleSignal = IterableSignal.value(singleIterable);
      final multiSignal = IterableSignal.value(multiIterable);

      expect(singleSignal.single, equals(42));

      expect(() {
        multiSignal.single;
      }, throwsA(isA<StateError>()));
    });

    test('should get length', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.length, equals(5));
    });

    test('should check if contains element', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.contains(2), isTrue);
      expect(iterableSignal.contains(4), isFalse);
    });

    test('should get element at index', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.elementAt(0), equals(1));
      expect(iterableSignal.elementAt(1), equals(2));
      expect(iterableSignal.elementAt(2), equals(3));
    });

    test('should work with any and every', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.any((element) => element > 3), isTrue);
      expect(iterableSignal.any((element) => element > 5), isFalse);

      expect(iterableSignal.every((element) => element > 0), isTrue);
      expect(iterableSignal.every((element) => element > 2), isFalse);
    });

    test('should work with firstWhere and lastWhere', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.firstWhere((element) => element > 2), equals(3));
      expect(iterableSignal.lastWhere((element) => element < 4), equals(3));

      expect(() {
        iterableSignal.firstWhere((element) => element > 5);
      }, throwsA(isA<StateError>()));
    });

    test('should work with singleWhere', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      expect(iterableSignal.singleWhere((element) => element == 3), equals(3));

      expect(() {
        iterableSignal.singleWhere((element) => element > 2);
      }, throwsA(isA<StateError>()));
    });

    test('should work with fold', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final sum = iterableSignal.fold(
        0,
        (previous, element) => previous + element,
      );
      expect(sum, equals(6));
    });

    test('should work with map', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final mapped = iterableSignal.map((element) => element * 2);
      expect(mapped, equals([2, 4, 6]));
    });

    test('should work with where', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);
      final filtered = iterableSignal.where((element) => element % 2 == 0);
      expect(filtered, equals([2, 4]));
    });

    test('should work with expand', () {
      final iterable = [1, 2];
      final iterableSignal = IterableSignal.value(iterable);
      final expanded = iterableSignal.expand(
        (element) => [element, element * 2],
      );
      expect(expanded, equals([1, 2, 2, 4]));
    });

    test('should work with followedBy', () {
      final iterable = [1, 2];
      final iterableSignal = IterableSignal.value(iterable);
      final followed = iterableSignal.followedBy([3, 4]);
      expect(followed, equals([1, 2, 3, 4]));
    });

    test('should work with skip and take', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      final skipped = iterableSignal.skip(2);
      expect(skipped, equals([3, 4, 5]));

      final taken = iterableSignal.take(3);
      expect(taken, equals([1, 2, 3]));
    });

    test('should work with skipWhile and takeWhile', () {
      final iterable = [1, 2, 3, 4, 5];
      final iterableSignal = IterableSignal.value(iterable);

      final skipped = iterableSignal.skipWhile((element) => element < 3);
      expect(skipped, equals([3, 4, 5]));

      final taken = iterableSignal.takeWhile((element) => element < 4);
      expect(taken, equals([1, 2, 3]));
    });

    test('should work with whereType', () {
      final iterable = [1, 'hello', 2, 'world'];
      final iterableSignal = IterableSignal.value(iterable);
      final numbers = iterableSignal.whereType<int>();
      expect(numbers, equals([1, 2]));
    });

    test('should work with join', () {
      final iterable = ['a', 'b', 'c'];
      final iterableSignal = IterableSignal.value(iterable);
      expect(iterableSignal.join(','), equals('a,b,c'));
      expect(iterableSignal.join(), equals('abc'));
    });

    test('should work with reduce', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final sum = iterableSignal.reduce((value, element) => value + element);
      expect(sum, equals(6));
    });

    test('should work with forEach', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final List<int> elements = [];

      for (var element in iterableSignal) {
        elements.add(element);
      }

      expect(elements, equals([1, 2, 3]));
    });

    test('should work with cast', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final casted = iterableSignal.cast<num>();
      expect(casted, equals([1, 2, 3]));
    });

    test('should convert to list', () {
      final iterable = [3, 1, 2];
      final iterableSignal = IterableSignal.value(iterable);
      final list = iterableSignal.toList();
      expect(list, equals([3, 1, 2]));
    });

    test('should convert to set', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final set = iterableSignal.toSet();
      expect(set, equals({1, 2, 3}));
    });

    test('should work with computed', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final computed = Computed<int>(
        () => iterableSignal.value.fold(0, (sum, value) => sum + value),
      );

      expect(computed.value, equals(6));
    });

    test('should work with effect', () {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final List<Iterable<int>> values = [];

      Effect(() {
        values.add(iterableSignal.value);
      });

      expect(
        values,
        equals([
          [1, 2, 3],
        ]),
      );
    });

    test('should emit stream events', () async {
      final iterable = [1, 2, 3];
      final iterableSignal = IterableSignal.value(iterable);
      final List<Iterable<int>> values = [];

      iterableSignal.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));
    });

    test('should work with different data types', () {
      final stringIterable = ['hello', 'world'];
      final stringSignal = IterableSignal.value(stringIterable);

      expect(stringSignal.value, equals(['hello', 'world']));
      expect(stringSignal.first, equals('hello'));
      expect(stringSignal.last, equals('world'));
    });

    test('should work with nullable values', () {
      final nullableIterable = [1, null, 3];
      final nullableSignal = IterableSignal.value(nullableIterable);

      expect(nullableSignal.value, equals([1, null, 3]));
      expect(nullableSignal.elementAt(1), isNull);
    });

    test('should work with custom objects', () {
      final personIterable = [TestPerson('Alice', 30), TestPerson('Bob', 25)];
      final personSignal = IterableSignal.value(personIterable);

      expect(
        personSignal.value,
        equals([TestPerson('Alice', 30), TestPerson('Bob', 25)]),
      );
      expect(personSignal.first, equals(TestPerson('Alice', 30)));
    });

    test('should handle equality correctly', () {
      final iterable1 = [1, 2, 3];
      final iterable2 = [1, 2, 3];

      final signal1 = IterableSignal.value(iterable1);
      final signal2 = IterableSignal.value(iterable1);
      final signal3 = IterableSignal.value(iterable2);

      expect(signal1.value == signal2.value, isTrue);
      expect(signal1.value == signal3.value, isFalse);
    });

    test('should handle hashCode correctly', () {
      final iterable1 = [1, 2, 3];
      final iterable2 = [1, 2, 3];

      final signal1 = IterableSignal.value(iterable1);
      final signal2 = IterableSignal.value(iterable2);

      expect(signal1.hashCode, isNot(equals(signal2.hashCode)));
    });

    test('should work with empty iterable', () {
      final emptyIterable = <int>[];
      final emptySignal = IterableSignal.value(emptyIterable);

      expect(emptySignal.isEmpty, isTrue);
      expect(emptySignal.length, equals(0));
      expect(emptySignal.any((element) => true), isFalse);
      expect(emptySignal.every((element) => true), isTrue);
    });

    test('should work with single element iterable', () {
      final singleIterable = [42];
      final singleSignal = IterableSignal.value(singleIterable);

      expect(singleSignal.length, equals(1));
      expect(singleSignal.first, equals(42));
      expect(singleSignal.last, equals(42));
      expect(singleSignal.single, equals(42));
    });

    test('should work with large iterable', () {
      final largeIterable = List.generate(1000, (index) => index);
      final largeSignal = IterableSignal.value(largeIterable);

      expect(largeSignal.length, equals(1000));
      expect(largeSignal.first, equals(0));
      expect(largeSignal.last, equals(999));
      expect(largeSignal.elementAt(500), equals(500));
    });

    test('should work with set iterable', () {
      final setIterable = {1, 2, 3};
      final setSignal = IterableSignal.value(setIterable);

      expect(setSignal.length, equals(3));
      expect(setSignal.contains(2), isTrue);
      expect(setSignal.contains(4), isFalse);
    });

    test('should work with map values iterable', () {
      final map = {'a': 1, 'b': 2, 'c': 3};
      final mapValuesSignal = IterableSignal.value(map.values);

      expect(mapValuesSignal.length, equals(3));
      expect(mapValuesSignal.contains(2), isTrue);
    });

    test('should work with map keys iterable', () {
      final map = {'a': 1, 'b': 2, 'c': 3};
      final mapKeysSignal = IterableSignal.value(map.keys);

      expect(mapKeysSignal.length, equals(3));
      expect(mapKeysSignal.contains('b'), isTrue);
    });

    test('should work with map entries iterable', () {
      final map = {'a': 1, 'b': 2, 'c': 3};
      final mapEntriesSignal = IterableSignal.value(map.entries);

      expect(mapEntriesSignal.length, equals(3));
      expect(
        mapEntriesSignal.any((entry) => entry.key == 'b' && entry.value == 2),
        isTrue,
      );
    });

    test('should work with chained operations', () {
      final iterable = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final iterableSignal = IterableSignal.value(iterable);

      final result = iterableSignal
          .where((element) => element % 2 == 0)
          .map((element) => element * 2)
          .take(3)
          .toList();

      expect(result, equals([4, 8, 12]));
    });

    test('should work with complex transformations', () {
      final iterable = [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
        {'name': 'Charlie', 'age': 35},
      ];
      final iterableSignal = IterableSignal.value(iterable);

      final names = iterableSignal
          .where((person) => (person['age'] as int) > 25)
          .map((person) => person['name'])
          .toList();

      expect(names, equals(['Alice', 'Charlie']));
    });
  });
}
