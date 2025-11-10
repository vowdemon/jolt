import 'dart:math';

import 'package:jolt/core.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group('effect', () {
    test('should clear subscriptions when untracked by all subscribers', () {
      int bRunTimes = 0;

      final a = signal(1);
      final b = computed(() {
        bRunTimes++;
        return a() * 2;
      });
      final stopEffect = effect(() {
        b();
      });

      expect(bRunTimes, 1);
      a(2, true);
      expect(bRunTimes, 2);
      stopEffect();
      a(3, true);
      expect(bRunTimes, 2);
    });

    test('should not run untracked inner effect', () {
      final a = signal(3);
      final b = computed(() => a() > 0);

      effect(() {
        if (b()) {
          effect(() {
            if (a() == 0) {
              throw "bad";
            }
          });
        }
      });

      a(2);
      a(1);
      a(0);
    });

    test('should run outer effect first', () {
      final a = signal(1);
      final b = signal(1);

      effect(() {
        if (a() == 1) {
          effect(() {
            b();
            if (a() == 0) {
              throw "bad";
            }
          });
        } else {}
      });

      startBatch();
      b(0);
      a(0);
      endBatch();
    });

    test('should not trigger inner effect when resolve maybe dirty', () {
      final a = signal(0);
      final b = computed(() => a() % 2);

      int innerTriggerTimes = 0;

      effect(() {
        effect(() {
          b();
          innerTriggerTimes++;
          if (innerTriggerTimes >= 2) {
            throw "bad";
          }
        });
      });

      a(2);
    });

    test('should notify inner effects in the same order as non-inner effects',
        () {
      final a = signal(0);
      final b = signal(0);
      final c = computed(() => a() - b());
      final List<String> order1 = [];
      final List<String> order2 = [];
      final List<String> order3 = [];

      effect(() {
        order1.add('effect1');
        a();
      });
      effect(() {
        order1.add('effect2');
        a();
        b();
      });

      effect(() {
        c();
        effect(() {
          order2.add('effect1');
          a();
        });
        effect(() {
          order2.add('effect2');
          a();
          b();
        });
      });
      effectScope(() {
        effect(() {
          order3.add('effect1');
          a();
        });
        effect(() {
          order3.add('effect2');
          a();
          b();
        });
      });

      order1.length = 0;
      order2.length = 0;
      order3.length = 0;

      startBatch();
      b(1, true);
      a(1, true);
      endBatch();

      expect(order1, equals(['effect2', 'effect1']));
      expect(order2, equals(order1));
      expect(order3, equals(order1));
    });

    test('should custom effect support batch', () {
      Function batchEffect(void Function() fn) {
        return effect(() {
          startBatch();
          try {
            return fn();
          } finally {
            endBatch();
          }
        });
      }

      final List<String> logs = [];
      final a = signal(0);
      final b = signal(0);

      final aa = computed(() {
        logs.add('aa-0');
        if (!(a() != 0)) {
          b(1, true);
        }
        logs.add('aa-1');
        return a();
      });

      final bb = computed(() {
        logs.add('bb');
        return b();
      });

      batchEffect(() {
        bb();
      });
      batchEffect(() {
        aa();
      });

      expect(logs, ['bb', 'aa-0', 'aa-1', 'bb']);
    });

    test('should duplicate subscribers do not affect the notify order', () {
      final src1 = signal(0);
      final src2 = signal(0);
      final List<String> order = [];

      effect(() {
        order.add('a');
        final currentSub = setCurrentSub(null);
        final isOne = src2() == 1;
        setCurrentSub(currentSub);
        if (isOne) {
          src1();
        }
        src2();
        src1();
      });
      effect(() {
        order.add('b');
        src1();
      });
      src2(1, true); // src1.subs: a -> b -> a

      order.length = 0;
      src1(src1() + 1, true);

      expect(order, ['a', 'b']);
    });

    test('should handle side effect with inner effects', () {
      final a = signal(0);
      final b = signal(0);
      final List<String> order = [];

      effect(() {
        effect(() {
          a();
          order.add('a');
        });
        effect(() {
          b();
          order.add('b');
        });
        expect(order, ['a', 'b']);

        order.length = 0;
        b(1, true);
        a(1, true);
        expect(order, ['b', 'a']);
      });
    });

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

      var triggers = 0;

      effect(() {
        d();
        triggers++;
      });
      expect(triggers, 1);
      a(true, true);
      expect(triggers, 2);
    });
  });

  test('should handle effect recursion for the first execution', () {
    final src1 = signal(0);
    final src2 = signal(0);

    var triggers1 = 0;
    var triggers2 = 0;

    effect(() {
      triggers1++;
      src1(min(src1() + 1, 5), true);
    });
    effect(() {
      triggers2++;
      src2(min(src2() + 1, 5), true);
      src2();
    });

    expect(triggers1, 1);
    expect(triggers2, 1);
  });

  test('should support custom recurse effect', () {
    final src = signal(0);

    var triggers = 0;

    effect(() {
      globalReactiveSystem.getActiveSub()!.flags &=
          ~ReactiveFlags.recursedCheck;
      triggers++;
      src(min(src() + 1, 5), true);
    });

    expect(triggers, 6);
  });
}
