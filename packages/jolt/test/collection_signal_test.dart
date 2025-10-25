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
  });
}
