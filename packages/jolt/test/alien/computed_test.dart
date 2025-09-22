import 'package:test/test.dart';

import 'common.dart';

void main() {
  group('computed', () {
    test('should correctly propagate changes through computed signals', () {
      final src = signal(0);
      final c1 = computed(() => src() % 2);
      final c2 = computed(() => c1());
      final c3 = computed(() => c2());

      c3();
      src(1, true);
      c2();
      src(3, true);

      expect(c3(), 1);
    });

    test(
      'should propagate updated source value through chained computations',
      () {
        final src = signal(0);
        final a = computed(() => src());
        final b = computed(() => a() % 2);
        final c = computed(() => src());
        final d = computed(() => b() + c());

        expect(d(), 0);
        src(2, true);
        expect(d(), 2);
      },
    );

    test('should handle flags are indirectly updated during checkDirty', () {
      final a = signal(false);
      final b = computed(() => a());
      final c = computed(() {
        b();
        return 0;
      });
      final d = computed(() {
        c();
        return b();
      });

      expect(d(), false);
      a(true, true);
      expect(d(), true);
    });

    test('should not update if the signal value is reverted', () {
      int times = 0;

      final src = signal(0);
      final c1 = computed(() {
        times++;
        return src();
      });
      c1();
      expect(times, 1);
      src(1, true);
      src(0, true);
      c1();
      expect(times, 1);
    });
  });
}
