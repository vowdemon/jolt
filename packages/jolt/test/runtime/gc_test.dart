import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

Future<void> encourageGc() async {
  for (var round = 0; round < 80; round++) {
    final pressure = List<Object>.generate(20000, (_) => Object());
    expect(pressure.length, 20000);
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> waitForGc(String reason, bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await encourageGc();
    if (predicate()) return;
  }
  fail(reason);
}

@pragma('vm:never-inline')
void expectWeakTargetNotNull<T extends Object>(WeakReference<T> ref) {
  expect(ref.target, isNotNull);
}

@pragma('vm:never-inline')
void disposeWeakEffectNode(WeakReference<EffectNode> ref) {
  final target = ref.target;
  expect(target, isNotNull);
  target!.dispose();
}

@pragma('vm:never-inline')
WeakReference<EffectNode> createDisposedEffectRawRef(Signal<int> s) {
  final effect = Effect(() {
    s.value;
  });
  final rawRef = WeakReference((effect as EffectImpl).raw);
  effect.dispose();
  return rawRef;
}

@pragma('vm:never-inline')
WeakReference<EffectNode> createDisposedWatcherRawRef(Signal<int> s) {
  final watcher = Watcher(() => s.value, (newValue, oldValue) {});
  final rawRef = WeakReference((watcher as WatcherImpl<int>).raw);
  watcher.dispose();
  return rawRef;
}

@pragma('vm:never-inline')
WeakReference<EffectNode> createDisposedScopeChildRawRef(Signal<int> s) {
  final scope = EffectScope();
  late final WeakReference<EffectNode> rawRef;

  scope.run(() {
    final effect = Effect(() {
      s.value;
    });
    rawRef = WeakReference((effect as EffectImpl).raw);
  });

  scope.dispose();
  return rawRef;
}

@pragma('vm:never-inline')
bool weakTargetIsNull<T extends Object>(WeakReference<T> ref) {
  return ref.target == null;
}

@pragma('vm:never-inline')
bool weakTargetIsNotNull<T extends Object>(WeakReference<T> ref) {
  return ref.target != null;
}

void main() {
  test('source drops stale computed sibling subscriptions after GC', () async {
    final s = Signal(1);
    final sRaw = (s as SignalImpl<int>).raw;

    late final WeakReference<Computed<int>> c1Ref;
    late final WeakReference<Computed<int>> c2Ref;
    late final WeakReference<Object> c1RawRef;
    late final WeakReference<Object> c2RawRef;

    () {
      final c1 = Computed(() => s.value * 2);
      final c2 = Computed(() => s.value * 3);
      expect(c1.value, 2);
      expect(c2.value, 3);
      c1Ref = WeakReference(c1);
      c2Ref = WeakReference(c2);
      c1RawRef = WeakReference((c1 as ComputedImpl<int>).raw);
      c2RawRef = WeakReference((c2 as ComputedImpl<int>).raw);
    }();

    expect(c1Ref.target, isNotNull);
    expect(c2Ref.target, isNotNull);
    expect(c1RawRef.target, isNotNull);
    expect(c2RawRef.target, isNotNull);

    await waitForGc('computed siblings and raws should be collected', () {
      return weakTargetIsNull(c1Ref) &&
          weakTargetIsNull(c2Ref) &&
          weakTargetIsNull(c1RawRef) &&
          weakTargetIsNull(c2RawRef);
    });

    await encourageGc();

    s.value = 2;
    expect(s.value, 2);

    expect(sRaw.subs, isNull);

    s.dispose();
  });

  test('source drops stale computed chain subscriptions after GC', () async {
    final s = Signal(1);
    final sRaw = (s as SignalImpl<int>).raw;

    late final WeakReference<Computed<int>> midRef;
    late final WeakReference<Computed<int>> leafRef;
    late final WeakReference<Object> midRawRef;
    late final WeakReference<Object> leafRawRef;

    () {
      final mid = Computed(() => s.value * 2);
      final leaf = Computed(() => mid.value + 1);

      expect(leaf.value, 3);

      midRef = WeakReference(mid);
      leafRef = WeakReference(leaf);
      midRawRef = WeakReference((mid as ComputedImpl<int>).raw);
      leafRawRef = WeakReference((leaf as ComputedImpl<int>).raw);
    }();

    expect(midRef.target, isNotNull);
    expect(leafRef.target, isNotNull);
    expect(midRawRef.target, isNotNull);
    expect(leafRawRef.target, isNotNull);

    await waitForGc('unreferenced computed chain should be collected', () {
      return weakTargetIsNull(midRef) &&
          weakTargetIsNull(leafRef) &&
          weakTargetIsNull(midRawRef) &&
          weakTargetIsNull(leafRawRef);
    });

    await encourageGc();

    s.value = 2;
    expect(s.value, 2);

    expect(sRaw.subs, isNull);

    s.dispose();
  });

  test('retained effect raw is not GCed while still subscribed', () async {
    final s = Signal(1);
    final values = <int>[];

    late final WeakReference<Effect> effectRef;
    late final WeakReference<EffectNode> effectRawRef;

    () {
      final effect = Effect(() {
        values.add(s.value);
      });
      effectRef = WeakReference(effect);
      effectRawRef = WeakReference((effect as EffectImpl).raw);
    }();

    expect(values, [1]);
    expect(effectRef.target, isNotNull);
    expectWeakTargetNotNull(effectRawRef);

    await waitForGc('effect wrapper can be collected while raw is retained', () {
      return weakTargetIsNull(effectRef) && weakTargetIsNotNull(effectRawRef);
    });

    expectWeakTargetNotNull(effectRawRef);

    s.value = 2;
    expect(values, [1, 2]);

    disposeWeakEffectNode(effectRawRef);
    s.dispose();
  });

  test('disposed effect raw is GCed', () async {
    final s = Signal(1);
    final effectRawRef = createDisposedEffectRawRef(s);

    expectWeakTargetNotNull(effectRawRef);

    await waitForGc('disposed effect raw should be collected', () {
      return weakTargetIsNull(effectRawRef);
    });

    s.dispose();
  });

  test('effect scope keeps child effect raw alive until scope dispose', () async {
    final s = Signal(1);
    final scope = EffectScope();
    final values = <int>[];

    late final WeakReference<Effect> childEffectRef;
    late final WeakReference<Object> childEffectRawRef;
    late final WeakReference<Object> scopeRawRef;

    scope.run(() {
      final effect = Effect(() {
        values.add(s.value);
      });
      childEffectRef = WeakReference(effect);
      childEffectRawRef = WeakReference((effect as EffectImpl).raw);
    });
    scopeRawRef = WeakReference((scope as EffectScopeImpl).raw);

    expect(values, [1]);
    expect(childEffectRef.target, isNotNull);
    expectWeakTargetNotNull(childEffectRawRef);
    expectWeakTargetNotNull(scopeRawRef);

    await encourageGc();

    expectWeakTargetNotNull(childEffectRawRef);
    expectWeakTargetNotNull(scopeRawRef);

    s.value = 2;
    expect(values, [1, 2]);

    scope.dispose();

    s.value = 3;
    expect(values, [1, 2]);

    s.dispose();
  });

  test('disposed effect scope child raw is GCed', () async {
    final s = Signal(1);
    final childEffectRawRef = createDisposedScopeChildRawRef(s);

    expectWeakTargetNotNull(childEffectRawRef);

    await waitForGc('disposed scope child effect raw should be collected', () {
      return weakTargetIsNull(childEffectRawRef);
    });

    s.dispose();
  });

  test('active watcher raw is not GCed while still subscribed', () async {
    final s = Signal(1);
    final values = <int>[];

    late final WeakReference<EffectNode> watcherRawRef;

    () {
      final watcher = Watcher(
        () => s.value,
        (newValue, _) => values.add(newValue),
      );
      watcherRawRef = WeakReference((watcher as WatcherImpl<int>).raw);
    }();

    expect(values, isEmpty);
    expectWeakTargetNotNull(watcherRawRef);

    await encourageGc();
    expectWeakTargetNotNull(watcherRawRef);

    s.value = 2;
    expect(values, [2]);

    disposeWeakEffectNode(watcherRawRef);
    s.dispose();
  });

  test('disposed watcher raw is GCed', () async {
    final s = Signal(1);
    final watcherRawRef = createDisposedWatcherRawRef(s);

    expectWeakTargetNotNull(watcherRawRef);

    await waitForGc('disposed watcher raw should be collected', () {
      return weakTargetIsNull(watcherRawRef);
    });

    s.dispose();
  });
}
