// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_surge/observer.dart';

void main() {
  group('Change', () {
    test('should create with currentState and nextState', () {
      const change = Change<int>(
        currentState: 0,
        nextState: 1,
      );

      expect(change.currentState, equals(0));
      expect(change.nextState, equals(1));
    });

    test('should support different types', () {
      const intChange = Change<int>(currentState: 0, nextState: 1);
      const stringChange = Change<String>(
        currentState: 'a',
        nextState: 'b',
      );
      const listChange = Change<List<int>>(
        currentState: [1, 2],
        nextState: [3, 4],
      );

      expect(intChange.currentState, equals(0));
      expect(stringChange.currentState, equals('a'));
      expect(listChange.currentState, equals([1, 2]));
    });

    group('operator ==', () {
      test('should be equal for identical instances', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = change1;

        expect(change1 == change2, isTrue);
        expect(change1, equals(change2));
      });

      test('should be equal for same values', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<int>(currentState: 0, nextState: 1);

        expect(change1 == change2, isTrue);
        expect(change1, equals(change2));
      });

      test('should not be equal for different currentState', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<int>(currentState: 2, nextState: 1);

        expect(change1 == change2, isFalse);
        expect(change1, isNot(equals(change2)));
      });

      test('should not be equal for different nextState', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<int>(currentState: 0, nextState: 2);

        expect(change1 == change2, isFalse);
        expect(change1, isNot(equals(change2)));
      });

      test('should not be equal for different types', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<String>(currentState: '0', nextState: '1');

        expect(change1 == change2, isFalse);
        expect(change1, isNot(equals(change2)));
      });

      test('should not be equal to non-Change objects', () {
        const change = Change<int>(currentState: 0, nextState: 1);

        expect(change == 1, isFalse);
        expect(change == 'string', isFalse);
        expect(change, isNotNull);
      });

      test('should handle null states', () {
        const change1 = Change<int?>(currentState: null, nextState: 1);
        const change2 = Change<int?>(currentState: null, nextState: 1);
        const change3 = Change<int?>(currentState: null, nextState: null);

        expect(change1 == change2, isTrue);
        expect(change1 == change3, isFalse);
      });
    });

    group('hashCode', () {
      test('should have same hashCode for equal objects', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<int>(currentState: 0, nextState: 1);

        expect(change1.hashCode, equals(change2.hashCode));
      });

      test('should have different hashCode for different values', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<int>(currentState: 0, nextState: 2);

        expect(change1.hashCode, isNot(equals(change2.hashCode)));
      });

      test('should have different hashCode for different types', () {
        const change1 = Change<int>(currentState: 0, nextState: 1);
        const change2 = Change<String>(currentState: '0', nextState: '1');

        expect(change1.hashCode, isNot(equals(change2.hashCode)));
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        const change = Change<int>(currentState: 0, nextState: 1);

        expect(
          change.toString(),
          equals('Change { currentState: 0, nextState: 1 }'),
        );
      });

      test('should format string values correctly', () {
        const change = Change<String>(
          currentState: 'hello',
          nextState: 'world',
        );

        expect(
          change.toString(),
          equals("Change { currentState: hello, nextState: world }"),
        );
      });

      test('should format list values correctly', () {
        const change = Change<List<int>>(
          currentState: [1, 2],
          nextState: [3, 4],
        );

        expect(
          change.toString(),
          equals('Change { currentState: [1, 2], nextState: [3, 4] }'),
        );
      });

      test('should format null values correctly', () {
        const change = Change<int?>(currentState: null, nextState: 1);

        expect(
          change.toString(),
          equals('Change { currentState: null, nextState: 1 }'),
        );
      });
    });
  });
}
