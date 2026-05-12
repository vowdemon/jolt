import "package:test/test.dart";

import "common.dart";

/// Regression for graph mutations during [checkDirty] / [updateNode], aligned
/// with alien-signals #109 ([ad52894](https://github.com/stackblitz/alien-signals/commit/ad5289456e06759b85cc170fa53f046c34459287)).
void main() {
  group("issue 109", () {
    test('#109', () {
      final s = signal(false);
      late void Function() dispose;
      final a = computed(() {
        if (s()) dispose();
        return 0;
      });
      final b = computed(() => a());
      dispose = effect(() {
        b();
      });
      s(true);
    });

    group('#109 edge', () {
// (1) Side-effect after the dispose-trigger inside the effect body
//     should still run, just like in any other JS function — disposing
//     swaps the .fn property but the closure already on the stack must
//     finish executing.
      test('self-dispose inside effect: code after dispose() still runs', () {
        final s = signal(0);
        late void Function() dispose;
        final stages = <String>[];

        dispose = effect(() {
          stages.add('start');
          s();
          if (s() == 1) {
            dispose();
            stages.add('after-dispose');
          }
          stages.add('end');
        });

        expect(stages, equals(['start', 'end']));
        s(1, true);
        expect(
            stages,
            equals([
              'start', 'end', // initial run
              'start', 'after-dispose',
              'end', // re-run; the fn body must finish
            ]));
      });

// (2) When dispose is triggered from *another* node's update (the
//     #109 path), the swapped fn replaces the user fn before run() calls
//     it — so the side-effect inside the user fn is never invoked.
//     This documents that this run is *skipped*, not just suppressed.
      test('disposed-by-other-node effect: scheduled run is skipped entirely',
          () {
        final s = signal(0);
        late void Function() dispose;
        var bodyRuns = 0;

        final a = computed(() {
          if (s() == 1) dispose();
          return s();
        });

        dispose = effect(() {
          a();
          bodyRuns++;
        });
        effect(() {
          a();
        });

        expect(bodyRuns, 1);
        s(1);
        // The flush queued e1 because of the propagation; if e1 had been
        // disposed *between flushes*, this run wouldn't have been scheduled.
        // The fix-by-fn-swap turns the scheduled run into a no-op.
        expect(bodyRuns, 1);
      });

// (3) After being disposed mid-flush, the effect's graph state should
//     be clean: no deps, not Watching, no subs — otherwise future
//     propagations would still walk through it.
      test('disposed effect: graph state is fully cleaned up', () {
        final s = signal(0);
        late void Function() dispose;
        ReactiveNode? e1Node;

        final a = computed(() {
          if (s() == 1) dispose();
          return s();
        });

        dispose = effect(() {
          e1Node ??= getActiveSub();
          a();
        });
        effect(() {
          a();
        });

        s(1, true);

        expect(e1Node, isNotNull);
        expect(e1Node!.deps, isNull);
        expect(e1Node!.flags & ReactiveFlags.watching, 0);
      });
    });

    group('#109 leak', () {
      test('disposed effect should not be re-notified on later updates', () {
        final s = signal(0);
        late void Function() dispose1;
        var e1runs = 0;

        final a = computed(() {
          if (s() == 1) dispose1();
          return s();
        });

        dispose1 = effect(() {
          a();
          e1runs++;
        });
        effect(() {
          a();
        });

        expect(e1runs, 1);
        s(1, true);
        expect(e1runs, 1);

        // If e1 was actually disposed, further signal changes shouldn't
        // involve it at all. With the fn-swap fix, e1 stays subscribed to `a`
        // and gets notified each time, even though fn is now a no-op.
        s(2, true);
        s(3, true);
        s(4, true);
        expect(e1runs, 1);
      });
    });

    group('#109 scope', () {
// Same shape as issue_109.spec.ts, but the dispose target is an
// effectScope instead of an effect. effectScopeOper has no defer
// branch in the current fix, so unwatched() cascades immediately and
// the original crash should still reproduce.
      test('#109 scope-variant: dispose effectScope during computed update',
          () {
        final s = signal(false);
        late void Function() disposeScope;

        final a = computed(() {
          if (s()) disposeScope();
          return 0;
        });
        final b = computed(() => a());

        disposeScope = effectScope(() {
          effect(() {
            b();
          });
        });

        s(true, true);
      });
    });

    group('#109 shallow', () {
      test('#109 shallowPropagate walks stale link after sibling disposal', () {
        final s = signal(0);
        late void Function() dispose1;
        var e2Value = -1;

        final a = computed(() {
          if (s() == 1) dispose1();
          return s();
        });

        dispose1 = effect(() {
          a();
        });
        effect(() {
          e2Value = a();
        });

        expect(e2Value, 0);
        s(1, true);
        expect(e2Value, 1);
      });

      test('#109 shallowPropagate walks stale link with 3 subscribers', () {
        final s = signal(0);
        late void Function() dispose1;
        var e2Value = -1;
        var e3Value = -1;

        final a = computed(() {
          if (s() == 1) dispose1();
          return s();
        });

        dispose1 = effect(() {
          a();
        });
        effect(() {
          e2Value = a();
        });
        effect(() {
          e3Value = a();
        });

        expect(e2Value, 0);
        expect(e3Value, 0);
        s(1, true);
        expect(e2Value, 1);
        expect(e3Value, 1);
      });
    });

    group('#109 stale', () {
      test('#109 stale-link: disposed effect still runs', () {
        final s = signal(0);
        late void Function() dispose1;
        var e1runs = 0;

        final a = computed(() {
          if (s() == 1) dispose1();
          return s();
        });

        dispose1 = effect(() {
          a();
          e1runs++;
        });
        effect(() {
          a();
        }); // second subscriber keeps `a` alive

        expect(e1runs, 1);
        s(1, true);
        expect(e1runs, 1); // disposed during update(a); should not re-run
      });
    });

    group('#109 variant', () {
      test('#109 variant - dep.subs undefined at line 190', () {
        final s = signal(0);
        late void Function() dispose;
        final a = computed(() => (s(), 0)); // value never changes
        final a2 = computed(() {
          if (s() != 0) {
            dispose();
          }
          return s();
        }); // disposes mid-update, value changes
        final b = computed(() => (a(), a2(), 0)); // reads a before a2
        dispose = effect(() {
          b();
        });
        s(1, true);
      });
    });
  });
}
