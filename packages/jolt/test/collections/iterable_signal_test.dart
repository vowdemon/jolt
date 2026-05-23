import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("IterableSignal", () {
    test("projects reactive list sources", () {
      final source = Signal<List<int>>([1, 2, 3, 4]);
      final signal = IterableSignal(() => source.value.where((value) => value.isEven));
      final snapshots = <List<int>>[];

      Effect(() {
        snapshots.add(signal.toList());
      });

      expect(snapshots, equals([
        [2, 4]
      ]));

      source.value = [2, 6, 7, 8];
      expect(snapshots, equals([
        [2, 4],
        [2, 6, 8],
      ]));
    });

    test("supports set sources without losing iterable behavior", () {
      final source = Signal<Set<int>>({1, 2, 3});
      final signal = IterableSignal(() => source.value);

      expect(signal.contains(2), isTrue);
      expect(signal.toSet(), equals({1, 2, 3}));

      source.value = {3, 4};
      expect(signal.toSet(), equals({3, 4}));
    });

    test("value factory exposes a stable static iterable", () {
      final iterable = IterableSignal.value([10, 20, 30]);

      expect(iterable.toList(), equals([10, 20, 30]));
      expect(iterable.peek.toList(), equals([10, 20, 30]));
      expect(iterable.toString(), equals([10, 20, 30].toString()));
    });
  });
}
