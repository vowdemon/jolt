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

    test("delegates Set read operations to the current value", () {
      final baseline = {1, 2, 3, 4};
      final signal = SetSignal<int>(Set<int>.from(baseline));
      final other = {3, 4, 5};

      expect(signal.cast<num>(), baseline.cast<num>());
      expect(signal.contains(2), baseline.contains(2));
      expect(signal.union(other), baseline.union(other));
      expect(signal.intersection(other), baseline.intersection(other));
      expect(signal.any((value) => value.isEven),
          baseline.any((value) => value.isEven));
      expect(signal.containsAll({1, 2}), baseline.containsAll({1, 2}));
      expect(signal.difference(other), baseline.difference(other));
      expect(signal.elementAt(0), baseline.elementAt(0));
      expect(
        signal.expand<String>((value) => ["$value"]).toList(),
        baseline.expand<String>((value) => ["$value"]).toList(),
      );
      expect(signal.every((value) => value > 0),
          baseline.every((value) => value > 0));
      expect(signal.firstWhere((value) => value > 2),
          baseline.firstWhere((value) => value > 2));
      expect(
        signal.fold<int>(0, (sum, value) => sum + value),
        baseline.fold<int>(0, (sum, value) => sum + value),
      );
      expect(signal.followedBy([5]).toList(), baseline.followedBy([5]).toList());
      expect(signal.join("-"), baseline.join("-"));
      expect(signal.lastWhere((value) => value < 4),
          baseline.lastWhere((value) => value < 4));
      expect(signal.lookup(3), baseline.lookup(3));
      expect(signal.first, baseline.first);
      expect(signal.last, baseline.last);
      expect(
        [for (final value in signal) value],
        [for (final value in baseline) value],
      );
      expect(signal.map((value) => value * 2).toList(),
          baseline.map((value) => value * 2).toList());
      expect(signal.toSet(), baseline.toSet());
      expect(signal.reduce((left, right) => left + right),
          baseline.reduce((left, right) => left + right));
      expect(signal.skip(1).toList(), baseline.skip(1).toList());
      expect(signal.skipWhile((value) => value < 2).toList(),
          baseline.skipWhile((value) => value < 2).toList());
      expect(signal.take(2).toList(), baseline.take(2).toList());
      expect(signal.takeWhile((value) => value < 4).toList(),
          baseline.takeWhile((value) => value < 4).toList());
      expect(signal.toList(), baseline.toList());
      expect(signal.whereType<int>().toList(), baseline.whereType<int>().toList());
      expect(signal.where((value) => value.isEven).toList(),
          baseline.where((value) => value.isEven).toList());
      expect(signal.isNotEmpty, baseline.isNotEmpty);

      final visited = <int>[];
      signal.forEach(visited.add);
      expect(visited.toSet(), baseline);
    });

    test("delegates single-element queries", () {
      final signal = SetSignal<int>({7});

      expect(signal.single, 7);
      expect(signal.singleWhere((value) => value == 7), 7);
    });

    test("read queries establish dependencies on current set state", () {
      final signal = SetSignal<int>({1, 2, 3});
      final values = <int>[];

      Effect(() {
        values.add(signal.union({4}).length);
      });

      expect(values, equals([4]));

      signal.add(5);
      expect(values, equals([4, 5]));

      signal.remove(1);
      expect(values, equals([4, 5, 4]));
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
