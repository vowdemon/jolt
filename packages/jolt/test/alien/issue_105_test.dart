import 'package:test/test.dart';

import 'common.dart';

void main() {
  group("issue 105", () {
    test('#105 signal and computed should link to the same node in effectScope',
        () {
      final a = signal(0);
      final b = computed(() => 0);
      var triggers = 0;

      effect(() {
        triggers += 1;
        effectScope(() {
          effectScope(() {
            a();
            b();
          });
        });
      });

      expect(triggers, 1);
      a(a() + 1, true);
      expect(triggers, 2);
      trigger(b);
      expect(triggers, 3);
    });

    test(
        '#105 effect should respond to both signal and computed changes through scope',
        () {
      final s = signal(0);
      final c = computed(() => s() * 2);
      var triggers = 0;

      effect(() {
        triggers += 1;
        effectScope(() {
          s();
          c();
        });
      });

      expect(triggers, 1);

      s(1, true);
      expect(triggers, 2);

      trigger(c);
      expect(triggers, 3);
    });

    test('#105 scope should respond to consecutive signal updates', () {
      final s = signal(0);
      var triggers = 0;

      effect(() {
        triggers += 1;
        effectScope(() {
          s();
        });
      });

      expect(triggers, 1);
      s(1, true);
      expect(triggers, 2);
      s(2, true);
      expect(triggers, 3);
    });

    test('#105 computed in standalone scope should cache and clean up', () {
      final s = signal(0);
      var computeCount = 0;

      final dispose = effectScope(() {
        final c = computed(() {
          computeCount++;
          return s();
        });
        expect(c(), 0);
        expect(c(), 0);
      });

      // Computed should cache (only 1 evaluation, not 2)
      expect(computeCount, 1);

      dispose();
    });
  });
}
