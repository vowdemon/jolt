import "package:test/test.dart";

import "common.dart";

void main() {
  group("untracked", () {
    test("should pause tracking in computed", () {
      final src = signal(0);

      var computedTriggerTimes = 0;
      final c = computed(() {
        computedTriggerTimes++;
        final currentSub = setActiveSub(null);
        final value = src();
        setActiveSub(currentSub);
        return value;
      });

      expect(c(), 0);
      expect(computedTriggerTimes, 1);

      src(1, true);
      src(2, true);
      src(3, true);
      expect(c(), 0);
      expect(computedTriggerTimes, 1);
    });

    test("should pause tracking in effect", () {
      final src = signal(0);
      final kIs = signal(0);

      var effectTriggerTimes = 0;
      effect(() {
        effectTriggerTimes++;
        if (kIs() != 0) {
          final currentSub = setActiveSub(null);
          src();
          setActiveSub(currentSub);
        }
      });

      expect(effectTriggerTimes, 1);

      kIs(1, true);
      expect(effectTriggerTimes, 2);

      src(1, true);
      src(2, true);
      src(3, true);
      expect(effectTriggerTimes, 2);

      kIs(2, true);
      expect(effectTriggerTimes, 3);

      src(4, true);
      src(5, true);
      src(6, true);
      expect(effectTriggerTimes, 3);

      kIs(0, true);
      expect(effectTriggerTimes, 4);

      src(7, true);
      src(8, true);
      src(9, true);
      expect(effectTriggerTimes, 4);
    });

    test("should pause tracking in effect scope", () {
      final src = signal(0);

      var effectTriggerTimes = 0;
      effectScope(() {
        effect(() {
          effectTriggerTimes++;
          final currentSub = setActiveSub(null);
          src();
          setActiveSub(currentSub);
        });
      });

      expect(effectTriggerTimes, 1);

      src(1, true);
      src(2, true);
      src(3, true);
      expect(effectTriggerTimes, 1);
    });
  });
}
