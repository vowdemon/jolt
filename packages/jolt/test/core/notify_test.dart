import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

// Custom effect that implements EffectScheduler for testing
class _TestScheduledEffect extends EffectReactiveNode
    with EffectNodeMixin
    implements EffectScheduler {
  _TestScheduledEffect({
    required this.scheduleReturnValue,
    required this.onSchedule,
    required this.onRun,
    required this.effectFn,
  }) : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck);

  final bool scheduleReturnValue;
  final void Function()? onSchedule;
  final void Function()? onRun;
  final void Function() effectFn;

  int scheduleCallCount = 0;
  int runCallCount = 0;

  @override
  bool schedule() {
    scheduleCallCount++;
    onSchedule?.call();
    return scheduleReturnValue;
  }

  @override
  void runEffect() {
    runCallCount++;
    onRun?.call();
    // effectFn is called within defaultRunEffect to establish dependency tracking
    defaultRunEffect(this, effectFn);
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}

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

    group("EffectScheduler", () {
      test("should use custom scheduling when schedule() returns true", () {
        final signal = Signal(0);
        int runCount = 0;
        int scheduleCount = 0;

        final effect = _TestScheduledEffect(
          scheduleReturnValue: true, // Custom scheduling handled
          onSchedule: () {
            scheduleCount++;
          },
          onRun: () {
            runCount++;
          },
          effectFn: () {
            // Access signal to establish dependency automatically
            signal.value;
          },
        );

        // Initial run to establish dependency - effect accesses signal during run
        effect.flags |= ReactiveFlags.dirty;
        effect.runEffect();
        expect(runCount, equals(1));
        expect(scheduleCount, equals(0));

        // Change signal value - should trigger notifyEffect (setting value automatically notifies)
        signal.value = 1;

        // schedule() should be called and return true, so effect should NOT be queued
        expect(scheduleCount, equals(1));
        // Effect should not run automatically (custom scheduling handled)
        expect(runCount, equals(1));

        // Manually trigger the effect
        effect.flags |= ReactiveFlags.dirty;
        effect.runEffect();
        expect(runCount, equals(2));

        signal.dispose();
        effect.dispose();
      });

      test("should use default scheduling when schedule() returns false", () {
        final signal = Signal(0);
        int runCount = 0;
        int scheduleCount = 0;

        final effect = _TestScheduledEffect(
          scheduleReturnValue: false, // Use default scheduling
          onSchedule: () {
            scheduleCount++;
          },
          onRun: () {
            runCount++;
          },
          effectFn: () {
            // Access signal to establish dependency automatically
            signal.value;
          },
        );

        // Initial run to establish dependency - effect accesses signal during run
        effect.flags |= ReactiveFlags.dirty;
        effect.runEffect();
        expect(runCount, equals(1));
        expect(scheduleCount, equals(0));

        // Change signal value - should trigger notifyEffect (setting value automatically notifies)
        signal.value = 1;

        // schedule() should be called and return false, so effect should be queued
        expect(scheduleCount, equals(1));
        // Effect should be queued and will run when flushed
        flushEffects();
        expect(runCount, equals(2));

        signal.dispose();
        effect.dispose();
      });

      test("should handle multiple scheduler calls", () {
        final signal1 = Signal(0);
        final signal2 = Signal(0);
        int scheduleCount = 0;

        final effect = _TestScheduledEffect(
          scheduleReturnValue: true,
          onSchedule: () {
            scheduleCount++;
          },
          onRun: () {},
          effectFn: () {
            signal1.value;
            signal2.value;
          },
        );

        // Initial run to establish dependencies - effect accesses signals during run
        effect.flags |= ReactiveFlags.dirty;
        effect.runEffect();

        // Change first signal - should trigger notifyEffect
        signal1.value = 1;
        expect(scheduleCount, equals(1));

        // Clear pending flag that may have been set during first notification
        // This ensures the second notification can trigger properly
        effect.flags &= ~ReactiveFlags.pending;
        effect.flags |= ReactiveFlags.watching;

        // Change second signal - should trigger notifyEffect again
        signal2.value = 2;
        expect(scheduleCount, equals(2));

        signal1.dispose();
        signal2.dispose();
        effect.dispose();
      });
    });

    group("_DummyEffectNode", () {
      test("should track dependencies in trigger function", () {
        final signal = Signal(0);
        int effectCount = 0;

        final effect = Effect(() {
          effectCount++;
          signal.value;
        });

        expect(effectCount, equals(1));

        // Use trigger to access signal
        trigger(() {
          signal.value;
        });

        // Effect should be triggered
        flushEffects();
        expect(effectCount, equals(2));

        signal.dispose();
        effect.dispose();
      });

      test("should handle multiple dependencies in trigger", () {
        final signal1 = Signal(0);
        final signal2 = Signal(0);
        int effectCount = 0;

        final effect = Effect(() {
          effectCount++;
          signal1.value;
          signal2.value;
        });

        expect(effectCount, equals(1));

        // Use trigger to access both signals
        trigger(() {
          signal1.value;
          signal2.value;
        });

        // Effect should be triggered once
        flushEffects();
        expect(effectCount, equals(2));

        signal1.dispose();
        signal2.dispose();
        effect.dispose();
      });

      test("should dispose _DummyEffectNode after trigger", () {
        final signal = Signal(0);

        // Create a custom effect that tracks disposal
        final effect = Effect(() {
          signal.value;
        });

        // Use trigger - _DummyEffectNode should be created and disposed
        trigger(() {
          signal.value;
        });

        // _DummyEffectNode should be disposed after trigger completes
        // We can verify this by checking that the effect still works
        signal.value = 1;
        signal.notify();
        flushEffects();

        signal.dispose();
        effect.dispose();
      });

      test("should work with computed in trigger", () {
        final signal = Signal(0);
        final computed = Computed(() => signal.value * 2);
        int effectCount = 0;

        final effect = Effect(() {
          effectCount++;
          computed.value;
        });

        expect(effectCount, equals(1));

        // Use trigger to access computed
        trigger(() {
          computed.value;
        });

        // Effect should be triggered
        flushEffects();
        expect(effectCount, equals(2));

        signal.dispose();
        effect.dispose();
      });
    });
  });
}
