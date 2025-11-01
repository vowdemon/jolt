import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('Collection Signal Tests', () {
    group('ListSignal', () {
      test('Basic operations - create and add elements', () {
        final listSignal = ListSignal<int>([]);

        expect(listSignal.value, isEmpty);
        expect(listSignal.length, equals(0));

        listSignal.add(1);
        expect(listSignal.value, equals([1]));
        expect(listSignal.length, equals(1));

        listSignal.addAll([2, 3]);
        expect(listSignal.value, equals([1, 2, 3]));
        expect(listSignal.length, equals(3));
      });

      test('Reactive updates - Effect listening', () {
        final listSignal = ListSignal<int>([]);
        final changes = <List<int>>[];

        Effect(() {
          changes.add(List.from(listSignal.value));
        });

        // Initial state
        expect(changes, equals([[]]));

        // Add elements
        listSignal.add(1);
        expect(
            changes,
            equals([
              [],
              [1]
            ]));

        listSignal.add(2);
        expect(
            changes,
            equals([
              [],
              [1],
              [1, 2]
            ]));
      });

      test('List operations - insert and remove', () {
        final listSignal = ListSignal<int>([1, 2, 3]);

        // Insert
        listSignal.insert(1, 10);
        expect(listSignal.value, equals([1, 10, 2, 3]));

        // Remove
        listSignal.removeAt(1);
        expect(listSignal.value, equals([1, 2, 3]));

        // Clear
        listSignal.clear();
        expect(listSignal.value, isEmpty);
      });
    });

    group('ListSignal ListBase methods and properties', () {
      test('test all read-only properties and methods', () {
        final listSignal = ListSignal<int>([1, 2, 3, 4, 5]);
        int notifyCount = -1;
        Effect(() {
          listSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(0));

        // Properties
        expect(listSignal.length, equals(5));
        expect(listSignal.first, equals(1));
        expect(listSignal.last, equals(5));
        expect(() => listSignal.single, throwsA(isA<StateError>()));
        expect(listSignal.isEmpty, isFalse);
        expect(listSignal.isNotEmpty, isTrue);
        expect(listSignal[0], equals(1));
        expect(listSignal[2], equals(3));

        // Test single with single element list
        final singleList = ListSignal<int>([42]);
        expect(singleList.single, equals(42));

        // Iterator
        expect(listSignal.iterator.moveNext(), isTrue);
        final iterator = listSignal.iterator;
        final values = <int>[];
        while (iterator.moveNext()) {
          values.add(iterator.current);
        }
        expect(values, equals([1, 2, 3, 4, 5]));

        // Query methods
        expect(listSignal.contains(3), isTrue);
        expect(listSignal.contains(10), isFalse);
        expect(listSignal.any((e) => e > 4), isTrue);
        expect(listSignal.every((e) => e > 0), isTrue);
        expect(listSignal.firstWhere((e) => e > 3), equals(4));
        expect(
            listSignal.firstWhere((e) => e > 10, orElse: () => -1), equals(-1));
        expect(listSignal.lastWhere((e) => e < 5), equals(4));
        expect(listSignal.singleWhere((e) => e == 3), equals(3));
        expect(listSignal.indexOf(3), equals(2));
        expect(listSignal.indexOf(3, 3), equals(-1));
        expect(listSignal.lastIndexOf(3), equals(2));
        expect(listSignal.indexWhere((e) => e > 3), equals(3));
        expect(listSignal.lastIndexWhere((e) => e < 5), equals(3));

        // Transformation methods
        expect(listSignal.where((e) => e % 2 == 0).toList(), equals([2, 4]));
        expect(listSignal.whereType<int>().toList(), equals([1, 2, 3, 4, 5]));
        expect(listSignal.map((e) => e * 2).toList(), equals([2, 4, 6, 8, 10]));
        expect(listSignal.expand((e) => [e, e]).toList(),
            equals([1, 1, 2, 2, 3, 3, 4, 4, 5, 5]));
        expect(listSignal.followedBy([6, 7]).toList(),
            equals([1, 2, 3, 4, 5, 6, 7]));
        expect(listSignal.getRange(1, 4).toList(), equals([2, 3, 4]));
        expect(listSignal.asMap(), equals({0: 1, 1: 2, 2: 3, 3: 4, 4: 5}));
        expect(listSignal.reversed.toList(), equals([5, 4, 3, 2, 1]));
        expect(listSignal.sublist(1, 4), equals([2, 3, 4]));
        expect(listSignal.elementAt(2), equals(3));
        expect(listSignal.skip(2).toList(), equals([3, 4, 5]));
        expect(listSignal.skipWhile((e) => e < 3).toList(), equals([3, 4, 5]));
        expect(listSignal.take(3).toList(), equals([1, 2, 3]));
        expect(listSignal.takeWhile((e) => e < 4).toList(), equals([1, 2, 3]));
        expect(listSignal.toList(), equals([1, 2, 3, 4, 5]));
        expect(listSignal.toSet(), equals({1, 2, 3, 4, 5}));
        expect(listSignal.join(','), equals('1,2,3,4,5'));
        expect(listSignal.cast<num>().toList(), equals([1, 2, 3, 4, 5]));
        expect(listSignal.reduce((a, b) => a + b), equals(15));
        expect(listSignal.fold<int>(0, (sum, e) => sum + e), equals(15));

        // forEach
        final forEachValues = <int>[];
        for (var e in listSignal) {
          forEachValues.add(e);
        }
        expect(forEachValues, equals([1, 2, 3, 4, 5]));

        // Operator +
        expect((listSignal + [6, 7]).toList(), equals([1, 2, 3, 4, 5, 6, 7]));

        // Verify no notify was triggered during read-only operations
        expect(notifyCount, equals(0));
      });

      test('should return value.toString() in toString', () {
        final listSignal = ListSignal<int>([1, 2, 3]);
        expect(listSignal.toString(), equals(listSignal.value.toString()));

        listSignal.value = [4, 5, 6];
        expect(listSignal.toString(), equals(listSignal.value.toString()));

        final emptyList = ListSignal<String>([]);
        expect(emptyList.toString(), equals(emptyList.value.toString()));

        final stringList = ListSignal<String>(['a', 'b', 'c']);
        expect(stringList.toString(), equals(stringList.value.toString()));
      });

      test('test write methods functionality', () {
        final listSignal = ListSignal<int>([1, 2, 3]);

        // Setters
        listSignal.first = 10;
        expect(listSignal.value, equals([10, 2, 3]));

        listSignal.last = 30;
        expect(listSignal.value, equals([10, 2, 30]));

        listSignal.length = 2;
        expect(listSignal.value, equals([10, 2]));

        // Index assignment
        listSignal[0] = 100;
        expect(listSignal.value[0], equals(100));

        // Add methods
        listSignal.add(200);
        expect(listSignal.value.last, equals(200));

        listSignal.addAll([300, 400]);
        expect(listSignal.value, containsAll([100, 300, 400]));

        listSignal.insert(1, 150);
        expect(listSignal.value[1], equals(150));

        listSignal.insertAll(2, [160, 170]);
        expect(listSignal.value, containsAll([100, 150, 160, 170]));

        // Remove methods
        expect(listSignal.remove(160), isTrue);
        expect(listSignal.value, isNot(contains(160)));

        final removed = listSignal.removeAt(1);
        expect(removed, equals(150));

        final lastRemoved = listSignal.removeLast();
        expect(lastRemoved, equals(400));

        listSignal.addAll([1, 2, 3, 4, 5]);
        final lengthBefore = listSignal.value.length;
        listSignal.removeRange(0, 2);
        expect(listSignal.value.length, equals(lengthBefore - 2));

        listSignal.addAll([2, 4, 6]);
        listSignal.removeWhere((e) => e % 2 == 0);
        expect(listSignal.value.every((e) => e % 2 == 1), isTrue);

        listSignal.addAll([2, 4, 6]);
        listSignal.retainWhere((e) => e % 2 == 0);
        expect(listSignal.value.every((e) => e % 2 == 0), isTrue);

        // Other modification methods
        listSignal.clear();
        expect(listSignal.value, isEmpty);

        listSignal.addAll([1, 2, 3, 4, 5]);
        listSignal.fillRange(1, 3, 10);
        expect(listSignal.value, equals([1, 10, 10, 4, 5]));

        listSignal.replaceRange(1, 3, [2, 3]);
        expect(listSignal.value, equals([1, 2, 3, 4, 5]));

        listSignal.setAll(2, [30, 40]);
        expect(listSignal.value[2], equals(30));
        expect(listSignal.value[3], equals(40));

        listSignal.setRange(0, 2, [10, 20]);
        expect(listSignal.value[0], equals(10));
        expect(listSignal.value[1], equals(20));

        final originalOrder = List.from(listSignal.value);
        listSignal.shuffle();
        expect(listSignal.value.length, equals(originalOrder.length));
        expect(listSignal.value.toSet(), equals(originalOrder.toSet()));

        listSignal.sort();
        expect(listSignal.value, equals([5, 10, 20, 30, 40])); // After sort
        // Verify it's sorted
        for (int i = 1; i < listSignal.value.length; i++) {
          expect(listSignal.value[i],
              greaterThanOrEqualTo(listSignal.value[i - 1]));
        }
      });
    });

    group('MapSignal', () {
      test('Basic operations - create and set values', () {
        final mapSignal = MapSignal<String, int>({});

        expect(mapSignal.value, isEmpty);

        mapSignal['a'] = 1;
        expect(mapSignal.value, equals({'a': 1}));
        expect(mapSignal['a'], equals(1));

        mapSignal['b'] = 2;
        expect(mapSignal.value, equals({'a': 1, 'b': 2}));
      });

      test('Reactive updates - Effect listening', () {
        final mapSignal = MapSignal<String, int>({});
        final changes = <Map<String, int>>[];

        Effect(() {
          changes.add(Map.from(mapSignal.value));
        });

        // Initial state
        expect(changes, equals([{}]));

        // Set values
        mapSignal['x'] = 10;
        expect(
            changes,
            equals([
              {},
              {'x': 10}
            ]));

        mapSignal['y'] = 20;
        expect(
            changes,
            equals([
              {},
              {'x': 10},
              {'x': 10, 'y': 20}
            ]));
      });

      test('Map operations - remove and update', () {
        final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});

        // Update value
        mapSignal['a'] = 10;
        expect(mapSignal.value, equals({'a': 10, 'b': 2}));

        // Remove key
        mapSignal.remove('a');
        expect(mapSignal.value, equals({'b': 2}));

        // Clear
        mapSignal.clear();
        expect(mapSignal.value, isEmpty);
      });
    });

    group('MapSignal MapBase methods and properties', () {
      test('test all read-only properties and methods', () {
        final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2, 'c': 3});
        int notifyCount = -1;
        Effect(() {
          mapSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(0));

        // Properties
        expect(mapSignal.length, equals(3));
        expect(mapSignal.isEmpty, isFalse);
        expect(mapSignal.isNotEmpty, isTrue);
        expect(mapSignal['a'], equals(1));
        expect(mapSignal['x'], isNull);

        // Iterator and collections
        expect(mapSignal.keys, containsAll(['a', 'b', 'c']));
        expect(mapSignal.values, containsAll([1, 2, 3]));
        expect(mapSignal.entries.length, equals(3));

        // Query methods
        expect(mapSignal.containsKey('a'), isTrue);
        expect(mapSignal.containsKey('x'), isFalse);
        expect(mapSignal.containsValue(2), isTrue);
        expect(mapSignal.containsValue(10), isFalse);

        // Iteration
        final entries = <MapEntry<String, int>>[];
        mapSignal.forEach((key, value) {
          entries.add(MapEntry(key, value));
        });
        expect(entries.length, equals(3));

        // Transformation methods
        final mapped = mapSignal.map<String, String>(
            (key, value) => MapEntry(key, value.toString()));
        expect(mapped['a'], equals('1'));

        expect(mapSignal.cast<String, num>()['a'], equals(1));

        // Test single element map
        final singleMap = MapSignal<String, int>({'x': 42});
        expect(singleMap.length, equals(1));
        expect(singleMap['x'], equals(42));

        // Verify no notify was triggered during read-only operations
        expect(notifyCount, equals(0));
      });

      test('should return value.toString() in toString', () {
        final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});
        expect(mapSignal.toString(), equals(mapSignal.value.toString()));

        mapSignal.value = {'x': 10, 'y': 20};
        expect(mapSignal.toString(), equals(mapSignal.value.toString()));

        final emptyMap = MapSignal<String, int>({});
        expect(emptyMap.toString(), equals(emptyMap.value.toString()));

        final singleEntry = MapSignal<String, String>({'key': 'value'});
        expect(singleEntry.toString(), equals(singleEntry.value.toString()));
      });

      test('test write methods functionality', () {
        final mapSignal = MapSignal<String, int>({'a': 1, 'b': 2});

        // Index assignment
        mapSignal['a'] = 10;
        expect(mapSignal.value, equals({'a': 10, 'b': 2}));

        mapSignal['c'] = 3;
        expect(mapSignal.value, equals({'a': 10, 'b': 2, 'c': 3}));

        // addAll
        mapSignal.addAll({'d': 4, 'e': 5});
        expect(mapSignal.value['d'], equals(4));
        expect(mapSignal.value['e'], equals(5));

        // addEntries
        mapSignal.addEntries([
          MapEntry('f', 6),
          MapEntry('g', 7),
        ]);
        expect(mapSignal.value['f'], equals(6));
        expect(mapSignal.value['g'], equals(7));

        // putIfAbsent
        final existing = mapSignal.putIfAbsent('a', () => 100);
        expect(existing, equals(10)); // Should return existing value
        expect(mapSignal['a'], equals(10)); // Should not change

        final newValue = mapSignal.putIfAbsent('h', () => 8);
        expect(newValue, equals(8));
        expect(mapSignal['h'], equals(8));

        // update
        mapSignal.update('a', (value) => value * 2);
        expect(mapSignal['a'], equals(20));

        mapSignal.update('i', (value) => value, ifAbsent: () => 9);
        expect(mapSignal['i'], equals(9));

        // updateAll
        mapSignal.updateAll((key, value) => value * 2);
        expect(mapSignal['a'], equals(40));
        expect(mapSignal['b'], equals(4));

        // removeWhere
        mapSignal.removeWhere((key, value) => value < 10);
        expect(mapSignal['a'], equals(40)); // Kept (40 >= 10)
        expect(mapSignal['b'], isNull); // Removed (4 < 10)

        // clear
        mapSignal.clear();
        expect(mapSignal.value, isEmpty);
      });
    });

    group('MapSignal notify count', () {
      test('notify count for write methods', () {
        final mapSignal = MapSignal<String, int>({});
        int notifyCount = 0;

        Effect(() {
          mapSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        mapSignal['a'] = 1;
        expect(notifyCount, equals(2));
        expect(mapSignal.value, equals({'a': 1}));

        mapSignal['b'] = 2;
        expect(notifyCount, equals(3));
        expect(mapSignal.value, equals({'a': 1, 'b': 2}));

        mapSignal.addAll({'c': 3, 'd': 4});
        expect(notifyCount, equals(4));
        expect(mapSignal.value['c'], equals(3));
        expect(mapSignal.value['d'], equals(4));

        mapSignal.addEntries([MapEntry('e', 5)]);
        expect(notifyCount, equals(5));

        mapSignal.putIfAbsent('f', () => 6);
        expect(notifyCount, equals(6));

        mapSignal.update('a', (value) => value * 2);
        expect(notifyCount, equals(7));

        mapSignal.updateAll((key, value) => value + 1);
        expect(notifyCount, equals(8));

        mapSignal.removeWhere((key, value) => value < 5);
        expect(notifyCount, equals(9));

        mapSignal.remove('e');
        expect(notifyCount, equals(10));

        mapSignal.clear();
        expect(notifyCount, equals(11));
        expect(mapSignal.value, isEmpty);
      });
    });

    group('SetSignal', () {
      test('Basic operations - create and add elements', () {
        final setSignal = SetSignal<int>({});

        expect(setSignal.value, isEmpty);

        setSignal.add(1);
        expect(setSignal.value, equals({1}));
        expect(setSignal.contains(1), isTrue);

        setSignal.addAll([2, 3]);
        expect(setSignal.value, equals({1, 2, 3}));
      });

      test('Reactive updates - Effect listening', () {
        final setSignal = SetSignal<int>({});
        final changes = <Set<int>>[];

        Effect(() {
          changes.add(Set.from(setSignal.value));
        });

        // Initial state
        expect(changes, equals([<int>{}]));

        // Add elements
        setSignal.add(1);
        expect(
            changes,
            equals([
              <int>{},
              {1}
            ]));

        setSignal.add(2);
        expect(
            changes,
            equals([
              <int>{},
              {1},
              {1, 2}
            ]));
      });

      test('Set operations - remove and contains check', () {
        final setSignal = SetSignal<int>({1, 2, 3});

        // Contains check
        expect(setSignal.contains(1), isTrue);
        expect(setSignal.contains(4), isFalse);

        // Remove element
        setSignal.remove(2);
        expect(setSignal.value, equals({1, 3}));

        // Clear
        setSignal.clear();
        expect(setSignal.value, isEmpty);
      });
    });

    group('SetSignal SetBase methods and properties', () {
      test('test all read-only properties and methods', () {
        final setSignal = SetSignal<int>({1, 2, 3, 4, 5});
        int notifyCount = -1;
        Effect(() {
          setSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(0));

        // Properties
        expect(setSignal.length, equals(5));
        expect(setSignal.isEmpty, isFalse);
        expect(setSignal.isNotEmpty, isTrue);
        expect(setSignal.first, equals(1));
        expect(setSignal.last, equals(5));
        expect(() => setSignal.single, throwsA(isA<StateError>()));

        // Test single element set
        final singleSet = SetSignal<int>({42});
        expect(singleSet.single, equals(42));

        // Iterator
        final values = <int>[];
        for (final value in setSignal) {
          values.add(value);
        }
        expect(values.length, equals(5));
        expect(values.toSet(), equals({1, 2, 3, 4, 5}));

        // Query methods
        expect(setSignal.contains(3), isTrue);
        expect(setSignal.contains(10), isFalse);
        expect(setSignal.containsAll({1, 2, 3}), isTrue);
        expect(setSignal.containsAll({1, 2, 10}), isFalse);
        expect(setSignal.any((e) => e > 4), isTrue);
        expect(setSignal.every((e) => e > 0), isTrue);
        expect(setSignal.firstWhere((e) => e > 3), equals(4));
        expect(
            setSignal.firstWhere((e) => e > 10, orElse: () => -1), equals(-1));
        expect(setSignal.lastWhere((e) => e < 5), equals(4));
        expect(setSignal.singleWhere((e) => e == 3), equals(3));
        expect(setSignal.lookup(3), equals(3));
        expect(setSignal.lookup(10), isNull);
        expect(setSignal.elementAt(2), equals(3));

        // Set operations
        expect(setSignal.union({6, 7}), containsAll({1, 2, 3, 4, 5, 6, 7}));
        expect(setSignal.intersection({3, 4, 5, 6}), equals({3, 4, 5}));
        expect(setSignal.difference({3, 4}), equals({1, 2, 5}));

        // Transformation methods
        expect(setSignal.where((e) => e % 2 == 0).toSet(), equals({2, 4}));
        expect(setSignal.whereType<int>().toSet(), equals({1, 2, 3, 4, 5}));
        expect(setSignal.map((e) => e * 2).toSet(), equals({2, 4, 6, 8, 10}));
        expect(
            setSignal.expand((e) => [e, e]).toSet(), equals({1, 2, 3, 4, 5}));
        expect(setSignal.followedBy({6, 7}).toList(),
            containsAll([1, 2, 3, 4, 5, 6, 7]));
        expect(setSignal.skip(2).toSet(), equals({3, 4, 5}));
        expect(setSignal.skipWhile((e) => e < 3).toSet(), equals({3, 4, 5}));
        expect(setSignal.take(3).toSet(), equals({1, 2, 3}));
        expect(setSignal.takeWhile((e) => e < 4).toSet(), equals({1, 2, 3}));
        expect(setSignal.toList(), containsAll([1, 2, 3, 4, 5]));
        expect(setSignal.toSet(), equals({1, 2, 3, 4, 5}));
        final joined = setSignal.join(',');
        expect(joined.contains('1'), isTrue);
        expect(joined.contains('2'), isTrue);
        expect(joined.contains('3'), isTrue);
        expect(setSignal.cast<num>().toSet(), equals({1, 2, 3, 4, 5}));
        expect(setSignal.reduce((a, b) => a + b), equals(15));
        expect(setSignal.fold<int>(0, (sum, e) => sum + e), equals(15));

        // forEach
        final forEachValues = <int>[];
        for (var e in setSignal) {
          forEachValues.add(e);
        }
        expect(forEachValues.length, equals(5));
        expect(forEachValues.toSet(), equals({1, 2, 3, 4, 5}));

        // Verify no notify was triggered during read-only operations
        expect(notifyCount, equals(0));
      });

      test('should return value.toString() in toString', () {
        final setSignal = SetSignal<int>({1, 2, 3});
        expect(setSignal.toString(), equals(setSignal.value.toString()));

        setSignal.value = {4, 5, 6};
        expect(setSignal.toString(), equals(setSignal.value.toString()));

        final emptySet = SetSignal<String>({});
        expect(emptySet.toString(), equals(emptySet.value.toString()));

        final singleElement = SetSignal<int>({42});
        expect(
            singleElement.toString(), equals(singleElement.value.toString()));
      });

      test('test write methods functionality', () {
        final setSignal = SetSignal<int>({1, 2, 3});

        // add
        expect(setSignal.add(4), isTrue);
        expect(setSignal.value, contains(4));

        expect(setSignal.add(1), isFalse); // Already exists
        expect(setSignal.value.length, equals(4));

        // addAll
        setSignal.addAll([5, 6]);
        expect(setSignal.value, containsAll([5, 6]));
        expect(setSignal.value.length, equals(6)); // [1, 2, 3, 4, 5, 6]

        // remove
        expect(setSignal.remove(2), isTrue);
        expect(setSignal.value, isNot(contains(2)));
        expect(setSignal.value.length,
            equals(5)); // Removed 2, remains [1, 3, 4, 5, 6]

        expect(setSignal.remove(10), isFalse); // Not present
        expect(setSignal.value.length, equals(5)); // No change

        // removeAll
        setSignal.addAll([7, 8, 9]);
        setSignal.removeAll({7, 8});
        expect(setSignal.value, isNot(containsAll([7, 8])));

        // retainAll
        setSignal.retainAll({1, 3, 5, 9});
        expect(setSignal.value, equals({1, 3, 5, 9}));

        // removeWhere
        setSignal.addAll([2, 4, 6]);
        setSignal.removeWhere((e) => e % 2 == 0);
        expect(setSignal.value.every((e) => e % 2 == 1), isTrue);

        // retainWhere
        setSignal.addAll([2, 4, 6]);
        setSignal.retainWhere((e) => e % 2 == 0);
        expect(setSignal.value.every((e) => e % 2 == 0), isTrue);

        // clear
        setSignal.clear();
        expect(setSignal.value, isEmpty);
      });
    });

    group('SetSignal notify count', () {
      test('notify count for write methods', () {
        final setSignal = SetSignal<int>({});
        int notifyCount = 0;

        Effect(() {
          setSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        setSignal.add(1);
        expect(notifyCount, equals(2));
        expect(setSignal.value, equals({1}));

        setSignal.add(2);
        expect(notifyCount, equals(3));
        expect(setSignal.value, equals({1, 2}));

        // add existing element should not notify
        setSignal.add(1);
        expect(notifyCount, equals(3)); // No change

        setSignal.addAll([3, 4]);
        expect(notifyCount, equals(4));
        expect(setSignal.value, containsAll([3, 4]));

        setSignal.remove(2);
        expect(notifyCount, equals(5));
        expect(setSignal.value, isNot(contains(2)));

        // remove non-existent element should not notify
        setSignal.remove(10);
        expect(notifyCount, equals(5)); // No change

        setSignal.removeAll({3});
        expect(notifyCount, equals(6));

        setSignal.retainAll({1, 4});
        expect(notifyCount, equals(7));

        setSignal.addAll([2, 3]);
        setSignal.removeWhere((e) => e % 2 == 0);
        expect(notifyCount, equals(9)); // addAll + removeWhere

        setSignal.addAll([2, 4]);
        setSignal.retainWhere((e) => e % 2 == 0);
        expect(notifyCount, equals(11)); // addAll + retainWhere

        setSignal.clear();
        expect(notifyCount, equals(12));
        expect(setSignal.value, isEmpty);
      });
    });

    group('ListSignal notify count', () {
      test('notify count for setters and index assignment', () {
        final listSignal = ListSignal<int>([1, 2, 3]);
        int notifyCount = 0;

        Effect(() {
          listSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        listSignal.first = 10;
        expect(notifyCount, equals(2));
        expect(listSignal.value, equals([10, 2, 3]));

        listSignal.last = 30;
        expect(notifyCount, equals(3));
        expect(listSignal.value, equals([10, 2, 30]));

        listSignal.length = 2;
        expect(notifyCount, equals(4));
        expect(listSignal.value, equals([10, 2]));

        listSignal[0] = 100;
        expect(notifyCount, equals(5));
        expect(listSignal.value, equals([100, 2]));
      });

      test('notify count for add methods', () {
        final listSignal = ListSignal<int>([1, 2, 3]);
        int notifyCount = 0;

        Effect(() {
          listSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        listSignal.add(4);
        expect(notifyCount, equals(2));
        expect(listSignal.value, equals([1, 2, 3, 4]));

        listSignal.addAll([5, 6]);
        expect(notifyCount, equals(3));
        expect(listSignal.value, equals([1, 2, 3, 4, 5, 6]));

        listSignal.insert(1, 10);
        expect(notifyCount, equals(4));
        expect(listSignal.value, equals([1, 10, 2, 3, 4, 5, 6]));

        listSignal.insertAll(2, [20, 30]);
        expect(notifyCount, equals(5));
        expect(listSignal.value, equals([1, 10, 20, 30, 2, 3, 4, 5, 6]));
      });

      test('notify count for remove methods', () {
        final listSignal = ListSignal<int>([1, 2, 3, 4, 5]);
        int notifyCount = 0;

        Effect(() {
          listSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        listSignal.remove(3);
        expect(notifyCount, equals(2));
        expect(listSignal.value, equals([1, 2, 4, 5]));

        listSignal.removeAt(1);
        expect(notifyCount, equals(3));
        expect(listSignal.value, equals([1, 4, 5]));

        listSignal.removeLast();
        expect(notifyCount, equals(4));
        expect(listSignal.value, equals([1, 4]));

        listSignal.addAll([2, 3, 4, 5]);
        expect(notifyCount, equals(5));
        expect(listSignal.value, equals([1, 4, 2, 3, 4, 5]));

        listSignal.removeRange(1, 3);
        expect(notifyCount, equals(6));
        expect(listSignal.value, equals([1, 3, 4, 5]));

        listSignal.removeWhere((e) => e % 2 == 0);
        expect(notifyCount, equals(7));
        expect(listSignal.value, equals([1, 3, 5]));

        listSignal.addAll([2, 4, 6]);
        expect(notifyCount, equals(8));

        listSignal.retainWhere((e) => e % 2 == 0);
        expect(notifyCount, equals(9));
        expect(listSignal.value, equals([2, 4, 6]));
      });

      test('notify count for other modification methods', () {
        final listSignal = ListSignal<int>([1, 2, 3, 4, 5]);
        int notifyCount = 0;

        Effect(() {
          listSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(1));

        listSignal.clear();
        expect(notifyCount, equals(2));
        expect(listSignal.value, isEmpty);

        listSignal.addAll([1, 2, 3, 4, 5]);
        expect(notifyCount, equals(3));

        listSignal.fillRange(1, 3, 10);
        expect(notifyCount, equals(4));
        expect(listSignal.value, equals([1, 10, 10, 4, 5]));

        listSignal.replaceRange(1, 3, [2, 3]);
        expect(notifyCount, equals(5));
        expect(listSignal.value, equals([1, 2, 3, 4, 5]));

        listSignal.setAll(2, [30, 40]);
        expect(notifyCount, equals(6));
        expect(listSignal.value, equals([1, 2, 30, 40, 5]));

        listSignal.setRange(0, 2, [10, 20], 0);
        expect(notifyCount, equals(7));
        expect(listSignal.value, equals([10, 20, 30, 40, 5]));

        final originalOrder = List.from(listSignal.value);
        listSignal.shuffle();
        expect(notifyCount, equals(8));
        expect(listSignal.value.length, equals(originalOrder.length));
        expect(listSignal.value.toSet(), equals(originalOrder.toSet()));

        listSignal.sort();
        expect(notifyCount, equals(9));
        expect(listSignal.value, equals([5, 10, 20, 30, 40]));
      });
    });

    group('IterableSignal IterableBase methods', () {
      test('test all read-only methods and properties', () {
        final source = Signal<List<int>>([1, 2, 3, 4, 5]);
        final iterableSignal = IterableSignal(() => source.value);
        int notifyCount = -1;
        Effect(() {
          iterableSignal.value;
          notifyCount++;
        });

        expect(notifyCount, equals(0));

        // Properties
        expect(iterableSignal.isEmpty, isFalse);
        expect(iterableSignal.isNotEmpty, isTrue);
        expect(iterableSignal.first, equals(1));
        expect(iterableSignal.last, equals(5));
        expect(() => iterableSignal.single, throwsA(isA<StateError>()));

        // Test single element iterable
        final singleSource = Signal<List<int>>([42]);
        final singleIterable = IterableSignal(() => singleSource.value);
        expect(singleIterable.single, equals(42));

        // Iterator
        final values = <int>[];
        for (final value in iterableSignal) {
          values.add(value);
        }
        expect(values, equals([1, 2, 3, 4, 5]));

        // Query methods
        expect(iterableSignal.contains(3), isTrue);
        expect(iterableSignal.contains(10), isFalse);
        expect(iterableSignal.any((e) => e > 4), isTrue);
        expect(iterableSignal.every((e) => e > 0), isTrue);
        expect(iterableSignal.firstWhere((e) => e > 3), equals(4));
        expect(iterableSignal.firstWhere((e) => e > 10, orElse: () => -1),
            equals(-1));
        expect(iterableSignal.lastWhere((e) => e < 5), equals(4));
        expect(iterableSignal.singleWhere((e) => e == 3), equals(3));
        expect(iterableSignal.elementAt(2), equals(3));

        // Transformation methods
        expect(
            iterableSignal.where((e) => e % 2 == 0).toList(), equals([2, 4]));
        expect(
            iterableSignal.whereType<int>().toList(), equals([1, 2, 3, 4, 5]));
        expect(iterableSignal.map((e) => e * 2).toList(),
            equals([2, 4, 6, 8, 10]));
        expect(iterableSignal.expand((e) => [e, e]).toList(),
            equals([1, 1, 2, 2, 3, 3, 4, 4, 5, 5]));
        expect(iterableSignal.followedBy([6, 7]).toList(),
            equals([1, 2, 3, 4, 5, 6, 7]));
        expect(iterableSignal.skip(2).toList(), equals([3, 4, 5]));
        expect(
            iterableSignal.skipWhile((e) => e < 3).toList(), equals([3, 4, 5]));
        expect(iterableSignal.take(3).toList(), equals([1, 2, 3]));
        expect(
            iterableSignal.takeWhile((e) => e < 4).toList(), equals([1, 2, 3]));
        expect(iterableSignal.toList(), equals([1, 2, 3, 4, 5]));
        expect(iterableSignal.toSet(), equals({1, 2, 3, 4, 5}));
        expect(iterableSignal.join(','), equals('1,2,3,4,5'));

        // Reduction methods
        expect(iterableSignal.reduce((a, b) => a + b), equals(15));
        expect(iterableSignal.fold<int>(0, (sum, e) => sum + e), equals(15));

        // forEach
        final forEachValues = <int>[];
        for (var e in iterableSignal) {
          forEachValues.add(e);
        }
        expect(forEachValues, equals([1, 2, 3, 4, 5]));

        // Verify no notify was triggered during read-only operations
        expect(notifyCount, equals(0));

        // Test reactivity
        source.value = [10, 20, 30];
        expect(
            notifyCount, greaterThan(0)); // Should notify after source changes
        expect(iterableSignal.toList(), equals([10, 20, 30]));
        expect(iterableSignal.first, equals(10));
        expect(iterableSignal.last, equals(30));
      });

      test('should return value.toString() in toString', () {
        final source = Signal<List<int>>([1, 2, 3]);
        final iterableSignal = IterableSignal(() => source.value);
        expect(
            iterableSignal.toString(), equals(iterableSignal.value.toString()));

        source.value = [4, 5, 6];
        expect(
            iterableSignal.toString(), equals(iterableSignal.value.toString()));

        final emptySource = Signal<List<int>>([]);
        final emptyIterable = IterableSignal(() => emptySource.value);
        expect(
            emptyIterable.toString(), equals(emptyIterable.value.toString()));

        final stringSource = Signal<List<String>>(['a', 'b']);
        final stringIterable = IterableSignal(() => stringSource.value);
        expect(
            stringIterable.toString(), equals(stringIterable.value.toString()));

        // Test with Set (different toString format)
        final setSource = Signal<Set<int>>({1, 2, 3});
        final setIterable = IterableSignal(() => setSource.value);
        expect(setIterable.toString(), equals(setIterable.value.toString()));

        // Test with IterableSignal.value factory
        final staticIterable = IterableSignal.value([10, 20, 30]);
        expect(
            staticIterable.toString(), equals(staticIterable.value.toString()));
      });
    });
  });
}
