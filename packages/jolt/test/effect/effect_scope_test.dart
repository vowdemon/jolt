import "package:jolt/jolt.dart";
import "package:test/test.dart";

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

    test(
      "dispose stops scoped effects but keeps scoped signals usable",
      () {
        final values = <int>[];
        late Signal<int> scopedSignal;
        late Effect scopedEffect;

        final scope = EffectScope()
          ..run(() {
            scopedSignal = Signal(1);
            scopedEffect = Effect(() {
              values.add(scopedSignal.value);
            });
          });

        expect(values, equals([1]));
        expect(scopedSignal.isDisposed, isFalse);
        expect(scopedEffect.isDisposed, isFalse);

        scope.dispose();

        expect(scopedEffect.isDisposed, isTrue);
        expect(scopedSignal.isDisposed, isFalse);
        expect(values, equals([1]));

        scopedSignal.value = 2;
        expect(values, equals([1]));
        expect(scopedSignal.value, equals(2));
      },
    );

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

    test("disposing inner scope stops only its effects", () {
      final signal = Signal(1);
      final outerValues = <int>[];
      final innerValues = <int>[];
      late EffectScope innerScope;

      final outerScope = EffectScope()
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

      innerScope.dispose();
      signal.value = 2;

      expect(innerScope.isDisposed, isTrue);
      expect(outerScope.isDisposed, isFalse);
      expect(innerValues, equals([10]));
      expect(outerValues, equals([1, 2]));
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
      expect(scope1.isDisposed, isTrue);
      expect(scope2.isDisposed, isFalse);

      signal.value = 3;

      expect(scope1Values, equals([1, 2]));
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

    test("detached effects outlive the scope until disposed", () {
      final signal = Signal(1);
      final scopedValues = <int>[];
      final detachedValues = <int>[];
      late Effect detachedEffect;

      final scope = EffectScope()
        ..run(() {
          Effect(() {
            scopedValues.add(signal.value);
          });
          detachedEffect = Effect(() {
            detachedValues.add(signal.value * 10);
          }, detach: true);
        });

      scope.dispose();
      signal.value = 2;

      expect(scopedValues, equals([1]));
      expect(detachedEffect.isDisposed, isFalse);
      expect(detachedValues, equals([10, 20]));

      detachedEffect.dispose();
      signal.value = 3;

      expect(detachedEffect.isDisposed, isTrue);
      expect(detachedValues, equals([10, 20]));
    });

    test("double dispose is idempotent", () {
      var cleanupCount = 0;
      final scope = EffectScope()
        ..run(() {
          onScopeDispose(() {
            cleanupCount++;
          });
        });

      scope.dispose();
      scope.dispose();

      expect(scope.isDisposed, isTrue);
      expect(cleanupCount, equals(1));
    });

    test("run after dispose does not reactivate the scope", () {
      final scope = EffectScope()..run(() {});

      scope.dispose();
      expect(scope.isDisposed, isTrue);

      final result = scope.run(() => 42);

      expect(result, equals(42));
      expect(scope.isDisposed, isTrue);
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
