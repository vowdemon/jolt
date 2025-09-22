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

    test('should trigger inner effects in sequence', () {
      final a = signal(0);
      final b = signal(0);
      final c = computed(() => a() - b());
      final List<String> order = [];

      effect(() {
        c();

        effect(() {
          order.add('first inner');
          a();
        });

        effect(() {
          order.add('last inner');
          a();
          b();
        });
      });

      order.length = 0;

      startBatch();
      b(1, true);
      a(1, true);
      endBatch();

      expect(order, ['first inner', 'last inner']);
    });

    test('should trigger inner effects in sequence in effect scope', () {
      final a = signal(0);
      final b = signal(0);
      final List<String> order = [];

      effectScope(() {
        effect(() {
          order.add('first inner');
          a();
        });

        effect(() {
          order.add('last inner');
          a();
          b();
        });
      });

      order.length = 0;

      startBatch();
      b(1, true);
      a(1, true);
      endBatch();

      expect(order, ['first inner', 'last inner']);
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
}
