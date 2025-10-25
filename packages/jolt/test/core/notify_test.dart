import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('Notify', () {
    test('signal notify', () {
      final s1 = Signal(0);
      int e1 = 0;
      int e2 = 0;
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

    test('computed notify', () {
      final s1 = Signal(0);
      final c1 = Computed(() => s1.value * 2);
      int e1 = 0;
      int e2 = 0;
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

    test('setSignal notify', () {
      final s1 = SetSignal<int>({});
      int e1 = 0;
      int e2 = 0;
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
  });
}
