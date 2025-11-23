import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Notify", () {
    test("signal notify", () {
      final s1 = Signal(0);
      var e1 = 0;
      var e2 = 0;
      Effect(() {
        s1.value;
        e1++;
      });
      Effect(
        () {
          s1.value;
          e2++;
        },
      );
      expect(e1, equals(1));
      expect(e2, equals(1));
      s1.notify();
      expect(e1, equals(2));
      expect(e2, equals(2));
    });

    test("computed notify", () {
      final s1 = Signal(0);
      final c1 = Computed(() => s1.value * 2);
      var e1 = 0;
      var e2 = 0;
      Effect(() {
        c1.value;
        e1++;
      });
      Effect(
        () {
          c1.value;
          e2++;
        },
      );
      expect(e1, equals(1));
      expect(e2, equals(1));
      c1.notify();
      expect(e1, equals(2));
      expect(e2, equals(2));
    });

    test("setSignal notify", () {
      final s1 = SetSignal<int>({});
      var e1 = 0;
      var e2 = 0;
      Effect(() {
        s1.value;
        e1++;
      });
      Effect(
        () {
          s1.value;
          e2++;
        },
      );
      expect(e1, equals(1));
      expect(e2, equals(1));
      s1.notify();
      expect(e1, equals(2));
      expect(e2, equals(2));
      s1.add(1);
      expect(e1, equals(3));
      expect(e2, equals(3));
      s1.contains(1);
      expect(e1, equals(3));
      expect(e2, equals(3));
    });

    test("multi-level chain notify with mutable values", () {
      final s1 = Signal(<int>[1, 2]);
      final c1 = Computed(() => s1.value.length);
      final c2 = Computed(() => c1.value * 2);
      var e1 = 0;
      var e2 = 0;
      Effect(() {
        c2.value;
        e1++;
      });
      Effect(() {
        c1.value;
        c2.value;
        e2++;
      });
      expect(e1, equals(1));
      expect(e2, equals(1));
      s1.value.add(3);
      s1.notify();
      expect(e1, equals(2));
      expect(e2, equals(2));
      c1.notify();
      expect(e1, equals(2));
      expect(e2, equals(3));
      c2.notify();
      expect(e1, equals(3));
      expect(e2, equals(4));
    });

    test("nested effect notify with mutable values", () {
      final s1 = Signal(<String>['a']);
      var outerCount = 0;
      var innerCount = 0;
      Effect(() {
        s1.value;
        outerCount++;
        Effect(() {
          s1.value;
          innerCount++;
        });
      });
      expect(outerCount, equals(1));
      expect(innerCount, equals(1));
      s1.value.add('b');
      s1.notify();
      expect(outerCount, equals(2));
      expect(innerCount, equals(2));
    });

    test("nested effect with computed notify mutable values", () {
      final s1 = Signal(<int>[1, 2]);
      final c1 = Computed(() => s1.value.length);
      var outerCount = 0;
      var innerCount = 0;
      Effect(() {
        s1.value;
        outerCount++;
        Effect(() {
          c1.value;
          innerCount++;
        });
      });
      expect(outerCount, equals(1));
      expect(innerCount, equals(1));
      s1.value.add(3);
      s1.notify();
      expect(outerCount, equals(2));
      expect(innerCount, equals(2));
      c1.notify();
      expect(outerCount, equals(2));
      expect(innerCount, equals(3));
    });

    test("deep nested effect chain notify with mutable values", () {
      final s1 = Signal(<int>[1]);
      final s2 = Signal(<int>[2]);
      var level1 = 0;
      var level2 = 0;
      var level3 = 0;
      Effect(() {
        s1.value;
        level1++;
        Effect(() {
          s1.value;
          s2.value;
          level2++;
          Effect(() {
            s2.value;
            level3++;
          });
        });
      });
      expect(level1, equals(1));
      expect(level2, equals(1));
      expect(level3, equals(1));
      s1.value.add(3);
      s1.notify();
      expect(level1, equals(2));
      expect(level2, equals(2));
      expect(level3, equals(2));
      s2.value.add(4);
      s2.notify();
      expect(level1, equals(2));
      expect(level2, equals(3));
      expect(level3, equals(3));
    });
  });
}
