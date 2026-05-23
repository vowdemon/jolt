import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("MapSignal", () {
    test("reads establish dependencies on current map state", () {
      final signal = MapSignal<String, int>({"a": 1, "b": 2});
      final values = <int>[];

      Effect(() {
        values.add((signal["a"] ?? 0) + signal.length);
      });

      expect(values, equals([3]));

      signal["a"] = 10;
      expect(values, equals([3, 12]));

      signal["c"] = 3;
      expect(values, equals([3, 12, 13]));
    });

    test("changed mutators notify observers", () {
      final signal = MapSignal<String, int>({"a": 1, "b": 2});
      final snapshots = <Map<String, int>>[];

      Effect(() {
        snapshots.add(Map<String, int>.from(signal.value));
      });

      signal["c"] = 3;
      signal["a"] = 10;
      signal.addAll({"d": 4});
      signal.addEntries([const MapEntry("e", 5)]);
      signal.putIfAbsent("f", () => 6);
      signal.update("a", (value) => value + 1);
      signal.update("g", (value) => value, ifAbsent: () => 7);
      signal.updateAll((key, value) => value * 2);
      signal.remove("b");
      signal.removeWhere((key, value) => value > 10);
      signal.clear();

      expect(
        snapshots,
        equals([
          {"a": 1, "b": 2},
          {"a": 1, "b": 2, "c": 3},
          {"a": 10, "b": 2, "c": 3},
          {"a": 10, "b": 2, "c": 3, "d": 4},
          {"a": 10, "b": 2, "c": 3, "d": 4, "e": 5},
          {"a": 10, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6},
          {"a": 11, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6},
          {"a": 11, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6, "g": 7},
          {"a": 22, "b": 4, "c": 6, "d": 8, "e": 10, "f": 12, "g": 14},
          {"a": 22, "c": 6, "d": 8, "e": 10, "f": 12, "g": 14},
          {"c": 6, "d": 8, "e": 10},
          <String, int>{},
        ]),
      );
    });

    test("semantic no-ops stay silent", () {
      final signal = MapSignal<String, int>({"a": 1, "b": 2});
      final empty = MapSignal<String, int>({});
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

      signal["a"] = 1;
      signal.addAll({"a": 1});
      signal.addEntries([const MapEntry("b", 2)]);
      signal.putIfAbsent("a", () => 99);
      signal.update("a", (value) => value);
      signal.updateAll((key, value) => value);
      signal.remove("missing");
      signal.removeWhere((key, value) => value > 100);
      empty.clear();

      expect(runs, equals(1));
      expect(emptyRuns, equals(1));
    });

    test("update without ifAbsent throws for missing keys", () {
      final signal = MapSignal<String, int>({"a": 1});

      expect(
        () => signal.update("missing", (value) => value),
        throwsA(isA<ArgumentError>()),
      );
    });

    test("delegates Map read operations to the current value", () {
      final baseline = {"a": 1, "b": 2};
      final signal = MapSignal<String, int>(Map<String, int>.from(baseline));

      expect(signal.cast<String, num>(), baseline.cast<String, num>());
      expect(signal.containsKey("a"), baseline.containsKey("a"));
      expect(signal.containsValue(1), baseline.containsValue(1));
      expect(signal.isNotEmpty, baseline.isNotEmpty);

      final keys = <String>[];
      signal.forEach((key, value) => keys.add("$key:$value"));
      final baselineKeys = <String>[];
      baseline.forEach((key, value) => baselineKeys.add("$key:$value"));
      expect(keys, baselineKeys);

      expect(signal.keys.toList(), baseline.keys.toList());
      expect(signal.values.toList(), baseline.values.toList());
      expect(
        signal.map((key, value) => MapEntry(key, value * 2)),
        baseline.map((key, value) => MapEntry(key, value * 2)),
      );
      expect(
        signal.entries.map((entry) => "${entry.key}:${entry.value}").toList(),
        baseline.entries.map((entry) => "${entry.key}:${entry.value}").toList(),
      );
    });

    test("read queries establish dependencies on current map state", () {
      final signal = MapSignal<String, int>({"a": 1, "b": 2});
      final values = <int>[];

      Effect(() {
        values.add(signal.keys.length + (signal.containsKey("b") ? 10 : 0));
      });

      expect(values, equals([12]));

      signal["c"] = 3;
      expect(values, equals([12, 13]));

      signal.remove("b");
      expect(values, equals([12, 13, 2]));
    });

    test("null input creates an empty reactive map", () {
      final signal = MapSignal<String, int>(null);

      expect(signal, isEmpty);
      expect(signal.value, isEmpty);
    });

    test("stream emits post-mutation snapshots only", () async {
      final signal = MapSignal<String, int>({});
      final values = <Map<String, int>>[];

      signal.stream.listen((value) {
        values.add(Map<String, int>.from(value));
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, isEmpty);

      signal["a"] = 1;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            {"a": 1},
          ]));

      signal["b"] = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            {"a": 1},
            {"a": 1, "b": 2},
          ]));
    });
  });
}
