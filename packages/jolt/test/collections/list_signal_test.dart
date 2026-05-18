import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";
import "dart:math";

void main() {
  group("ListSignal", () {
    test("reads establish dependencies on current list state", () {
      final signal = ListSignal<int>([1, 2, 3]);
      final values = <int>[];

      Effect(() {
        values.add(signal[0] + signal.length);
      });

      expect(values, equals([4]));

      signal[0] = 5;
      expect(values, equals([4, 8]));

      signal.length = 2;
      expect(values, equals([4, 8, 7]));
    });

    test("changed mutators notify observers with post-mutation values", () {
      final signal = ListSignal<int>([1, 2, 3]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      expect(
          snapshots,
          equals([
            [1, 2, 3]
          ]));

      signal.add(4);
      signal.fillRange(0, 2, 9);
      signal.replaceRange(1, 3, [7, 8]);
      signal.setAll(0, [1, 2]);
      signal.setRange(0, 2, [5, 6]);
      signal.first = 10;
      signal.last = 11;
      signal.length = 2;
      signal.clear();

      expect(
        snapshots,
        equals([
          [1, 2, 3],
          [1, 2, 3, 4],
          [9, 9, 3, 4],
          [9, 7, 8, 4],
          [1, 2, 8, 4],
          [5, 6, 8, 4],
          [10, 6, 8, 4],
          [10, 6, 8, 11],
          [10, 6],
          <int>[],
        ]),
      );
    });

    test("length-based mutators only notify when size actually changes", () {
      final signal = ListSignal<int>([1, 2, 3, 4]);
      var runs = 0;

      Effect(() {
        signal.value;
        runs++;
      });

      expect(runs, equals(1));

      expect(signal.remove(99), isFalse);
      signal.removeWhere((value) => value > 10);
      signal.retainWhere((value) => value > 0);
      signal.removeRange(1, 1);
      expect(runs, equals(1));

      expect(signal.remove(4), isTrue);
      expect(runs, equals(2));

      signal.removeAt(0);
      expect(runs, equals(3));

      signal.removeRange(0, 1);
      expect(runs, equals(4));
    });

    test("semantic no-ops stay silent", () {
      final signal = ListSignal<int>([1, 2, 3]);
      final empty = ListSignal<int>([]);
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

      signal[0] = 1;
      signal.first = 1;
      signal.last = 3;
      signal.length = 3;
      signal.fillRange(1, 2, 2);
      signal.replaceRange(0, 2, [1, 2]);
      signal.setAll(0, [1, 2]);
      signal.setRange(0, 2, [0, 1, 2], 1);
      signal.addAll(const []);
      signal.insertAll(1, const []);
      empty.clear();
      empty.shuffle();
      empty.sort();

      expect(runs, equals(1));
      expect(emptyRuns, equals(1));
    });

    test("addAll notifies with the post-mutation snapshot for non-empty input",
        () {
      final signal = ListSignal<int>([1, 2]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      signal.addAll([3, 4]);

      expect(
        snapshots,
        equals([
          [1, 2],
          [1, 2, 3, 4],
        ]),
      );
    });

    test(
        "insertAll notifies with the post-mutation snapshot for non-empty input",
        () {
      final signal = ListSignal<int>([1, 4]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      signal.insertAll(1, [2, 3]);

      expect(
        snapshots,
        equals([
          [1, 4],
          [1, 2, 3, 4],
        ]),
      );
    });

    test("setRange with skipCount rescans lazy iterables and notifies once",
        () {
      final signal = ListSignal<int>([1, 2, 3, 4]);
      final snapshots = <List<int>>[];
      var passes = 0;

      Iterable<int> replacements() sync* {
        passes++;
        yield 99;
        yield 7;
        yield 8;
      }

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      signal.setRange(1, 3, replacements(), 1);

      expect(passes, equals(2));
      expect(
        snapshots,
        equals([
          [1, 2, 3, 4],
          [1, 7, 8, 4],
        ]),
      );
    });

    test("setRange failure stays silent and leaves state unchanged", () {
      final signal = ListSignal<int>([1, 2, 3]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      expect(
        () => signal.setRange(2, 4, [9, 8]),
        throwsRangeError,
      );

      expect(
        snapshots,
        equals([
          [1, 2, 3],
        ]),
      );
      expect(signal.value, equals([1, 2, 3]));
    });

    test("remaining mutators notify with post-mutation snapshots", () {
      final signal = ListSignal<int>([3, 1, 2, 4]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      signal.insert(1, 9);
      signal.removeLast();
      signal.retainWhere((value) => value != 1);
      signal.sort();

      expect(
        snapshots,
        equals([
          [3, 1, 2, 4],
          [3, 9, 1, 2, 4],
          [3, 9, 1, 2],
          [3, 9, 2],
          [2, 3, 9],
        ]),
      );
    });

    test("shuffle notifies non-empty lists even if order cannot change", () {
      final signal = ListSignal<int>([42]);
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(List<int>.from(signal.value));
      });

      signal.shuffle(Random(0));

      expect(
        snapshots,
        equals([
          [42],
          [42],
        ]),
      );
    });

    test("null input creates an empty reactive list", () {
      final signal = ListSignal<int>(null);

      expect(signal, isEmpty);
      expect(signal.value, isEmpty);
    });

    test("stream emits post-mutation snapshots only", () async {
      final signal = ListSignal<int>([1, 2, 3]);
      final values = <List<int>>[];

      signal.stream.listen((value) {
        values.add(List<int>.from(value));
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, isEmpty);

      signal.add(4);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            [1, 2, 3, 4],
          ]));

      signal.remove(2);
      await Future.delayed(const Duration(milliseconds: 1));
      expect(
          values,
          equals([
            [1, 2, 3, 4],
            [1, 3, 4],
          ]));
    });
  });
}
