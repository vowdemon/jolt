import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('Debug', () {
    test('debug signal', () {
      final counter = DebugCounter();

      final s = Signal(0, onDebug: counter.onDebug);
      expect(counter.createCount, equals(1));
      expect(counter.count, equals(1));

      s.value = 1;

      expect(counter.setCount, equals(1));
      expect(counter.count, equals(2));

      s.value;
      expect(counter.getCount, equals(1));
      expect(counter.count, equals(3));

      s.notify();
      expect(counter.notifyCount, equals(1));
      expect(counter.count, equals(4));

      s.dispose();
      expect(counter.disposeCount, equals(1));
      expect(counter.count, equals(5));
    });

    test('debug computed', () {
      final counter = DebugCounter();

      final c = Computed(() => 1, onDebug: counter.onDebug);
      expect(counter.createCount, equals(1));
      expect(counter.count, equals(1));

      c.value;

      expect(c.value, equals(1));

      expect(counter.getCount, equals(2));
      expect(counter.setCount, equals(1));
      expect(counter.count, equals(4));

      c.notify();
      expect(counter.notifyCount, equals(1));
      expect(counter.count, equals(5));

      c.dispose();
      expect(counter.disposeCount, equals(1));
      expect(counter.count, equals(6));
    });

    test('debug effect', () {
      final counter = DebugCounter();

      final e = Effect(() => 1, immediately: false, onDebug: counter.onDebug);

      expect(counter.createCount, equals(1));
      expect(counter.count, equals(1));

      e.run();

      expect(counter.effectCount, equals(1));
      expect(counter.count, equals(2));

      e.dispose();
      expect(counter.disposeCount, equals(1));
      expect(counter.count, equals(3));
    });

    test('debug watcher', () {
      final counter = DebugCounter();

      final w = Watcher(() => 1, (value, _) => 1, onDebug: counter.onDebug);

      expect(counter.createCount, equals(1));
      expect(counter.count, equals(1));

      w.run();
      expect(counter.effectCount, equals(1));
      expect(counter.count, equals(2));

      w.dispose();
      expect(counter.disposeCount, equals(1));
      expect(counter.count, equals(3));
    });

    test('debug effect scope', () {
      final counter = DebugCounter();

      final e = EffectScope(onDebug: counter.onDebug)..run(() => 1);

      expect(counter.createCount, equals(1));
      expect(counter.count, equals(2));

      e.run(() => 1);
      // run when the scope is created
      expect(counter.effectCount, equals(2));
      expect(counter.count, equals(3));

      e.dispose();
      expect(counter.disposeCount, equals(1));
      expect(counter.count, equals(4));
    });

    test('debug reactive', () {
      final sCounter = DebugCounter();
      final cCounter = DebugCounter();
      final eCounter = DebugCounter();
      final esCounter = DebugCounter();
      final wCounter = DebugCounter();

      final s = Signal(0, onDebug: sCounter.onDebug);
      final c = Computed(() => s.value, onDebug: cCounter.onDebug);
      late Effect e;
      late Watcher w;
      final es = EffectScope(onDebug: esCounter.onDebug)
        ..run(
          () {
            e = Effect(() => c.value, onDebug: eCounter.onDebug);
            w = Watcher(
              () => c.value,
              (value, _) => value,
              onDebug: wCounter.onDebug,
              when: (newValue, oldValue) => true,
            );
          },
        );

      expect(sCounter.linked, equals(1));
      expect(cCounter.linked, equals(2));
      expect(cCounter.getCount, equals(2));
      expect(eCounter.effectCount, equals(1));
      expect(wCounter.effectCount, equals(0));

      s.value++;

      expect(sCounter.setCount, equals(1));
      expect(cCounter.getCount, equals(4));
      expect(eCounter.effectCount, equals(2));
      expect(wCounter.effectCount, equals(1));

      w.run();
      expect(wCounter.effectCount, equals(2));
      e.run();
      expect(eCounter.effectCount, equals(3));
      w.dispose();
      expect(wCounter.disposeCount, equals(1));
      expect(cCounter.unlinked, equals(1));

      es.dispose();

      expect(eCounter.disposeCount, equals(1));
      expect(esCounter.disposeCount, equals(1));
      expect(cCounter.unlinked, equals(2));
      expect(sCounter.unlinked, equals(1));

      s.value = 2;
      expect(cCounter.setCount, equals(1));
      expect(sCounter.setCount, equals(2));
      expect(sCounter.getCount, equals(3));
      expect(cCounter.getCount, equals(6));
    });
  });
}
