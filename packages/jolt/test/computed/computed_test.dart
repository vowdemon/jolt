import "package:jolt/jolt.dart";
import "package:test/test.dart";

bool _listEquals(Object? current, Object? previous) {
  if (current is! List<int> || previous is! List<int>) {
    return current == previous;
  }

  if (current.length != previous.length) {
    return false;
  }

  for (var i = 0; i < current.length; i++) {
    if (current[i] != previous[i]) {
      return false;
    }
  }

  return true;
}

void main() {
  group("Computed", () {
    test("should have peek initialize value when initialValue is null", () {
      final computed = Computed<int>(() => 10);
      expect(computed.peek, equals(10));
      expect(computed.value, equals(10));
    });

    test("should update when dependencies change", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value + 1);

      expect(computed.value, equals(2));

      signal.value = 5;
      expect(computed.value, equals(6));
    });

    test("should work with multiple dependencies", () {
      final signal1 = Signal(2);
      final signal2 = Signal(3);
      final computed = Computed<int>(() => signal1.value * signal2.value);

      expect(computed.value, equals(6));

      signal1.value = 4;
      expect(computed.value, equals(12));

      signal2.value = 5;
      expect(computed.value, equals(20));
    });

    test("should work with nested computed", () {
      final signal = Signal(2);
      final computed1 = Computed<int>(() => signal.value * 2);
      final computed2 = Computed<int>(() => computed1.value + 1);

      expect(computed1.value, equals(4));
      expect(computed2.value, equals(5));

      signal.value = 3;
      expect(computed1.value, equals(6));
      expect(computed2.value, equals(7));
    });

    test("isDisposed and toString reflect computed state", () {
      final computed = Computed<int>(() => 42);

      expect(computed.toString(), equals("42"));
      expect(computed.isDisposed, isFalse);

      computed.dispose();

      expect(computed.isDisposed, isTrue);
    });

    test("disposed computed stops updating and notifying dependents", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([2]));

      computed.dispose();
      signal.value = 2;

      expect(computed.value, equals(2));
      expect(computed.peek, equals(2));
      expect(values, equals([2]));
    });
  });

  group("Computed.withPrevious", () {
    test("should pass null as previous value on first computation", () {
      final signal = Signal(5);
      int? previousValue;
      final computed = Computed<int>.withPrevious((prev) {
        previousValue = prev;
        return signal.value * 2;
      });

      expect(computed.value, equals(10));
      expect(previousValue, isNull);
    });

    test("should pass previous computed value to later computations", () {
      final signal = Signal(1);
      final previousValues = <int?>[];
      final computed = Computed<int>.withPrevious((prev) {
        previousValues.add(prev);
        return signal.value * 2;
      });

      expect(computed.value, equals(2));
      expect(previousValues, equals([null]));

      signal.value = 2;
      expect(computed.value, equals(4));
      expect(previousValues, equals([null, 2]));

      signal.value = 5;
      expect(computed.value, equals(10));
      expect(previousValues, equals([null, 2, 4]));
    });

    test("should remain stable when new object has same value as previous", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final computed = Computed<List<int>>.withPrevious((prev) {
        computeCount++;
        final newList = List<int>.from(signal.value);

        if (_listEquals(newList, prev)) {
          return prev!;
        }

        return newList;
      });

      Effect(() {
        effectValues.add(List<int>.from(computed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));
      expect(effectValues.last, equals([1, 2, 3]));

      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length, equals(1));
      expect(computed.value, equals([1, 2, 3]));

      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2));
      expect(effectValues.last, equals([4, 5, 6]));

      signal.value = [4, 5, 6];
      expect(computeCount, equals(4));
      expect(effectValues.length, equals(2));
    });
  });

  group("Computed equals", () {
    test(
        "custom equals suppresses downstream updates while default equality does not",
        () {
      final listSignal = Signal<List<int>>([1, 2, 3]);
      var customEffectCount = 0;
      var defaultEffectCount = 0;

      final customComputed = Computed<List<int>>(
        () => List<int>.from(listSignal.value),
        equals: _listEquals,
      );
      final defaultComputed = Computed<List<int>>(
        () => List<int>.from(listSignal.value),
      );

      Effect(() {
        customComputed.value;
        customEffectCount++;
      });

      Effect(() {
        defaultComputed.value;
        defaultEffectCount++;
      });

      expect(customEffectCount, equals(1));
      expect(defaultEffectCount, equals(1));

      listSignal.value = [1, 2, 3];
      expect(customEffectCount, equals(1));
      expect(defaultEffectCount, equals(2));

      listSignal.value = [4, 5, 6];
      expect(customEffectCount, equals(2));
      expect(defaultEffectCount, equals(3));
    });
  });

  group("Computed notify", () {
    test("soft update recomputes but does not notify when value is unchanged",
        () {
      final signal = Signal(5);
      var computeCount = 0;
      final computed = Computed<int>(() {
        computeCount++;
        return signal.value;
      });
      var effectCount = 0;

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computeCount, equals(1));
      expect(computed.value, equals(5));

      computed.notifySoft();
      expect(effectCount, equals(1));
      expect(computeCount, equals(2));

      signal.value = 10;
      expect(computed.value, equals(10));
      expect(effectCount, equals(2));
      expect(computeCount, equals(3));

      computed.notifySoft();
      expect(effectCount, equals(2));
      expect(computeCount, equals(4));
    });

    test("should notify subscribers when force update even if value unchanged",
        () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value);
      var effectCount = 0;

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computed.value, equals(5));

      computed.notify();
      expect(effectCount, equals(2));

      computed.notify();
      expect(effectCount, equals(3));
    });
  });
}
