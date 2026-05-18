import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("SetSignal", () {
    test("reads establish dependencies on current set state", () {
      final signal = SetSignal<int>({1, 2, 3});
      final values = <int>[];

      Effect(() {
        values.add(signal.length + (signal.contains(2) ? 10 : 0));
      });

      expect(values, equals([13]));

      signal.add(4);
      expect(values, equals([13, 14]));

      signal.remove(2);
      expect(values, equals([13, 14, 3]));
    });

    test("changed mutators notify observers", () {
      final signal = SetSignal<int>({1, 2, 3});
      final snapshots = <Set<int>>[];

      Effect(() {
        snapshots.add(Set<int>.from(signal.value));
      });

      signal.add(4);
      signal.addAll([5, 6]);
      signal.remove(1);
      signal.removeAll({5, 9});
      signal.removeWhere((value) => value == 6);
      signal.retainAll({2, 3, 4});
      signal.retainWhere((value) => value.isEven);
      signal.clear();

      expect(
        snapshots,
        equals([
          {1, 2, 3},
          {1, 2, 3, 4},
          {1, 2, 3, 4, 5, 6},
          {2, 3, 4, 5, 6},
          {2, 3, 4, 6},
          {2, 3, 4},
          {2, 4},
          <int>{},
        ]),
      );
    });

    test("semantic no-ops stay silent", () {
      final signal = SetSignal<int>({1, 2, 3});
      final empty = SetSignal<int>({});
      var runs = 0;
      var emptyRuns = 0;

      Effect(() {
        signal.value;
        runs++;
      });
      Effect(() {
        empty.value;
        emptyRuns++;
      });

      expect(signal.add(1), isFalse);
      signal.addAll([1, 2]);
      expect(signal.remove(99), isFalse);
      signal.removeAll({98, 99});
      signal.removeWhere((value) => value > 10);
      signal.retainAll({1, 2, 3});
      signal.retainWhere((value) => value > 0);
      empty.clear();

      expect(runs, equals(1));
      expect(emptyRuns, equals(1));
    });

    test("null input creates an empty reactive set", () {
      final signal = SetSignal<int>(null);

      expect(signal, isEmpty);
      expect(signal.value, isEmpty);
    });

    test("stream emits post-mutation snapshots only", () async {
      final signal = SetSignal<int>({});
      final values = <Set<int>>[];

      signal.stream.listen((value) {
        values.add(Set<int>.from(value));
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, isEmpty);

      signal.add(1);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            {1},
          ]));

      signal.add(2);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            {1},
            {1, 2},
          ]));
    });
  });
}
