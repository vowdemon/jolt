import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

extension on ReactiveNode {
  bool testNoSubscribers() => subs == null && subsTail == null;
}

void main() {
  group("EffectScope", () {
    test("run returns the callback result without keeping subscriptions", () {
      final signal = Signal(1);
      final scope = EffectScope();
      final values = <int>[];

      final result = scope.run(() {
        values.add(signal.value);
        return signal.value + 1;
      });

      expect(result, equals(2));
      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1]));

      scope.dispose();
    });

    test("dispose stops scoped effects but leaves captured sources usable", () {
      final signal = Signal(1);
      final values = <int>[];

      final scope = EffectScope()
        ..run(() {
          Effect(() {
            values.add(signal.value);
          });
        });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      scope.dispose();
      signal.value = 3;

      expect(values, equals([1, 2]));
      expect(signal.value, equals(3));
    });

    test("linked nested scopes dispose children with the parent", () {
      final signal = Signal(1);
      final outerValues = <int>[];
      final innerValues = <int>[];
      late EffectScope outerScope;
      late EffectScope innerScope;

      outerScope = EffectScope()
        ..run(() {
          Effect(() {
            outerValues.add(signal.value);
          });

          innerScope = EffectScope()
            ..run(() {
              Effect(() {
                innerValues.add(signal.value * 10);
              });
            });
        });

      expect(outerValues, equals([1]));
      expect(innerValues, equals([10]));

      signal.value = 2;
      expect(outerValues, equals([1, 2]));
      expect(innerValues, equals([10, 20]));

      outerScope.dispose();
      signal.value = 3;

      expect(outerScope.isDisposed, isTrue);
      expect(innerScope.isDisposed, isTrue);
      expect(outerValues, equals([1, 2]));
      expect(innerValues, equals([10, 20]));
    });

    test("sibling scopes dispose independently", () {
      final signal = Signal(1);
      final scope1Values = <int>[];
      final scope2Values = <int>[];

      final scope1 = EffectScope()
        ..run(() {
          Effect(() {
            scope1Values.add(signal.value);
          });
        });

      final scope2 = EffectScope()
        ..run(() {
          Effect(() {
            scope2Values.add(signal.value * 2);
          });
        });

      signal.value = 2;
      expect(scope1Values, equals([1, 2]));
      expect(scope2Values, equals([2, 4]));

      scope1.dispose();
      signal.value = 3;

      expect(scope1Values, equals([1, 2]));
      expect(scope2.isDisposed, isFalse);
      expect(scope2Values, equals([2, 4, 6]));
    });

    test("disposing a scope before batch flush drops queued child reruns", () {
      final signal = Signal(0);
      final values = <int>[];

      final scope = EffectScope()
        ..run(() {
          Effect(() {
            values.add(signal.value);
          });
        });

      expect(values, equals([0]));

      batch(() {
        signal.value = 1;
        scope.dispose();
        signal.value = 2;
      });

      expect(values, equals([0]));
      expect(signal.value, equals(2));
    });

    test("detached child scopes outlive the parent until disposed", () {
      final signal = Signal(1);
      final outerValues = <int>[];
      final innerValues = <int>[];
      late EffectScope outerScope;
      late EffectScope innerScope;

      outerScope = EffectScope()
        ..run(() {
          Effect(() {
            outerValues.add(signal.value);
          });

          innerScope = EffectScope(detach: true)
            ..run(() {
              Effect(() {
                innerValues.add(signal.value * 10);
              });
            });
        });

      signal.value = 2;
      expect(outerValues, equals([1, 2]));
      expect(innerValues, equals([10, 20]));

      outerScope.dispose();
      signal.value = 3;

      expect(outerScope.isDisposed, isTrue);
      expect(innerScope.isDisposed, isFalse);
      expect(outerValues, equals([1, 2]));
      expect(innerValues, equals([10, 20, 30]));

      innerScope.dispose();
      signal.value = 4;

      expect(innerScope.isDisposed, isTrue);
      expect(innerValues, equals([10, 20, 30]));
    });

    test(
        "deeply nested scopes clean up cross-scope subscriptions without touching global observers",
        () {
      final globalSignal = Signal(10);
      final globalComputed = Computed(() => globalSignal.value * 2);
      final globalValues = <int>[];

      Effect(() {
        globalValues.add(globalComputed.value);
      });

      final outerValues = <int>[];
      final midValues = <int>[];
      final innerValues = <int>[];
      final crossValues = <int>[];

      late EffectScope outerScope;
      late EffectScope midScope;
      late EffectScope innerScope;

      late Signal<int> outerSignal;
      late Computed<int> outerComputed;
      late Effect outerEffect;

      late Signal<int> midSignal;
      late Computed<int> midComputed;
      late Effect midEffect;

      late Signal<int> innerSignal;
      late Computed<int> innerComputed;
      late Effect innerEffect1;
      late Effect innerEffect2;

      outerScope = EffectScope()
        ..run(() {
          outerSignal = Signal(1);
          outerComputed =
              Computed(() => outerSignal.value + globalSignal.value);
          outerEffect = Effect(() {
            outerValues.add(outerComputed.value);
          });

          midScope = EffectScope()
            ..run(() {
              midSignal = Signal(5);
              midComputed = Computed(() => midSignal.value + outerSignal.value);
              midEffect = Effect(() {
                midValues.add(midComputed.value);
              });

              innerScope = EffectScope()
                ..run(() {
                  innerSignal = Signal(100);
                  innerComputed = Computed(
                    () =>
                        innerSignal.value +
                        midSignal.value +
                        globalSignal.value,
                  );
                  innerEffect1 = Effect(() {
                    innerValues.add(innerComputed.value);
                  });
                  innerEffect2 = Effect(() {
                    crossValues.add(innerSignal.value * outerSignal.value);
                  });
                });
            });
        });

      expect(globalValues, equals([20]));
      expect(outerValues, equals([11]));
      expect(midValues, equals([6]));
      expect(innerValues, equals([115]));
      expect(crossValues, equals([100]));

      globalSignal.value = 20;
      midSignal.value = 7;
      outerSignal.value = 2;

      expect(globalValues, equals([20, 40]));
      expect(outerValues, equals([11, 21, 22]));
      expect(midValues, equals([6, 8, 9]));
      expect(innerValues, equals([115, 125, 127]));
      expect(crossValues, equals([100, 200]));

      innerScope.dispose();
      expect(innerScope.isDisposed, isTrue);
      expect((innerSignal as SignalImpl).raw.testNoSubscribers(), isTrue);
      expect((innerComputed as ComputedImpl).raw.testNoSubscribers(), isTrue);
      expect(innerEffect1.isDisposed, isTrue);
      expect(innerEffect2.isDisposed, isTrue);

      outerSignal.value = 3;
      expect(outerValues, equals([11, 21, 22, 23]));
      expect(midValues, equals([6, 8, 9, 10]));
      expect(innerValues, equals([115, 125, 127]));
      expect(crossValues, equals([100, 200]));

      midScope.dispose();
      expect(midScope.isDisposed, isTrue);
      expect((midSignal as SignalImpl).raw.testNoSubscribers(), isTrue);
      expect((midComputed as ComputedImpl).raw.testNoSubscribers(), isTrue);
      expect(midEffect.isDisposed, isTrue);

      outerSignal.value = 4;
      expect(outerValues, equals([11, 21, 22, 23, 24]));
      expect(midValues, equals([6, 8, 9, 10]));

      outerScope.dispose();
      expect(outerScope.isDisposed, isTrue);
      expect((outerSignal as SignalImpl).raw.testNoSubscribers(), isTrue);
      expect((outerComputed as ComputedImpl).raw.testNoSubscribers(), isTrue);
      expect(outerEffect.isDisposed, isTrue);

      globalSignal.value = 30;
      expect(globalValues, equals([20, 40, 60]));
      expect(outerValues, equals([11, 21, 22, 23, 24]));
      expect(midValues, equals([6, 8, 9, 10]));
      expect(innerValues, equals([115, 125, 127]));
      expect(crossValues, equals([100, 200]));
    });
  });

  group("onScopeDispose", () {
    test("runs cleanup when the scope is disposed", () {
      var cleanupCalled = false;

      final scope = EffectScope()
        ..run(() {
          onScopeDispose(() {
            cleanupCalled = true;
          });
        });

      expect(cleanupCalled, isFalse);

      scope.dispose();

      expect(cleanupCalled, isTrue);
    });

    test("runs cleanups in registration order", () {
      final cleanupOrder = <int>[];

      final scope = EffectScope()
        ..run(() {
          onScopeDispose(() {
            cleanupOrder.add(1);
          });
          onScopeDispose(() {
            cleanupOrder.add(2);
          });
          onScopeDispose(() {
            cleanupOrder.add(3);
          });
        });

      scope.dispose();

      expect(cleanupOrder, equals([1, 2, 3]));
    });

    test("nested linked scope cleanups follow each scope lifecycle", () {
      final events = <String>[];
      late EffectScope innerScope;

      final outerScope = EffectScope()
        ..run(() {
          onScopeDispose(() {
            events.add("outer");
          });

          innerScope = EffectScope()
            ..run(() {
              onScopeDispose(() {
                events.add("inner");
              });
            });
        });

      innerScope.dispose();
      expect(events, equals(["inner"]));

      outerScope.dispose();
      expect(events, equals(["inner", "outer"]));
    });

    test("explicit owner registers cleanup outside the current scope", () {
      var cleanupCalled = false;
      final owner = EffectScope();

      EffectScope().run(() {
        onScopeDispose(() {
          cleanupCalled = true;
        }, owner: owner);
      });

      expect(cleanupCalled, isFalse);

      owner.dispose();

      expect(cleanupCalled, isTrue);
    });
  });
}
