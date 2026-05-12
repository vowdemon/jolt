import 'package:test/test.dart';

import 'common.dart';

void main() {
  group("issue 99", () {
    test('#99 consecutive inner resets through computed chain', () {
      final s = signal(0);
      final c = computed(() => s());
      var runs = 0;

      effect(() {
        runs++;
        if (c() > 0) {
          s(0, true);
        }
      });

      expect(runs, 1);
      s(1, true);
      expect(s(), 0);
      expect(runs, 2);
      s(2, true);
      expect(s(), 0);
      expect(runs, 3);
      s(3, true);
      expect(s(), 0);
      expect(runs, 4);
    });
  });
}
