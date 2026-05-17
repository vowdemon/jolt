import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/core/debug.dart";
import "package:test/test.dart";

import "../utils.dart";

void main() {
  group("Debug", () {
    setUpAll(() {
      JoltDebug.init();
    });

    test("debug signal binds to raw node and reports public operations", () {
      final events = <DebugNodeOperationType>[];
      final nodes = <ReactiveNode>[];
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        events.add(type);
        nodes.add(node);
      }

      final s = Signal(0, debug: JoltDebugOption.fn(onDebug));
      final raw = (s as SignalImpl<int>).raw;

      s.value = 1;
      s.value;
      s.notify();
      s.dispose();

      expect(nodes, everyElement(same(raw)));
      expect(
        events,
        containsAllInOrder([
          DebugNodeOperationType.create,
          DebugNodeOperationType.set,
          DebugNodeOperationType.get,
          DebugNodeOperationType.notify,
          DebugNodeOperationType.dispose,
        ]),
      );
    });

    test("debug computed binds to raw node and reports value operations", () {
      final events = <DebugNodeOperationType>[];
      final nodes = <ReactiveNode>[];
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        events.add(type);
        nodes.add(node);
      }

      final c = Computed(() => 1, debug: JoltDebugOption.fn(onDebug));
      final raw = (c as ComputedImpl<int>).raw;

      expect(c.value, equals(1));
      c.notify();
      c.dispose();

      expect(nodes, everyElement(same(raw)));
      expect(events, contains(DebugNodeOperationType.create));
      expect(events, contains(DebugNodeOperationType.get));
      expect(events, contains(DebugNodeOperationType.set));
      expect(events, contains(DebugNodeOperationType.notify));
      expect(events, contains(DebugNodeOperationType.dispose));
    });

    test("debug effect binds to raw node and reports runs", () {
      final events = <DebugNodeOperationType>[];
      final nodes = <ReactiveNode>[];
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        events.add(type);
        nodes.add(node);
      }

      final s = Signal(0);
      final e = Effect(
        () {
          s.value;
        },
        debug: JoltDebugOption.fn(onDebug),
      );
      final raw = (e as EffectImpl).raw;

      s.value = 1;
      e.dispose();
      s.dispose();

      expect(nodes, everyElement(same(raw)));
      expect(events, contains(DebugNodeOperationType.create));
      expect(events, contains(DebugNodeOperationType.effect));
      expect(events, contains(DebugNodeOperationType.dispose));
    });

    test("debug watcher binds to its raw effect node and reports trigger", () {
      final events = <DebugNodeOperationType>[];
      final nodes = <ReactiveNode>[];
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        events.add(type);
        nodes.add(node);
      }

      final w = Watcher(
        () => 1,
        (value, _) => value,
        debug: JoltDebugOption.fn(onDebug),
      );
      final raw = (w as WatcherImpl<int>).raw;

      w.trigger();
      w.dispose();

      expect(nodes, everyElement(same(raw)));
      expect(events, contains(DebugNodeOperationType.create));
      expect(events, contains(DebugNodeOperationType.effect));
      expect(events, contains(DebugNodeOperationType.dispose));
    });

    test("debug effect scope binds to raw scope node", () {
      final events = <DebugNodeOperationType>[];
      final nodes = <ReactiveNode>[];
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        events.add(type);
        nodes.add(node);
      }

      final scope = EffectScope(debug: JoltDebugOption.fn(onDebug));
      final raw = (scope as EffectScopeImpl).raw;

      scope.run(() => 1);
      scope.dispose();

      expect(nodes, everyElement(same(raw)));
      expect(events, contains(DebugNodeOperationType.create));
      expect(events, contains(DebugNodeOperationType.dispose));
    });

    test("debug counter tracks stable operation types", () {
      final counter = DebugCounter();

      final s = Signal(0, debug: JoltDebugOption.fn(counter.onDebug));
      final c =
          Computed(() => s.value, debug: JoltDebugOption.fn(counter.onDebug));

      expect(c.value, equals(0));
      s.value = 1;
      expect(c.value, equals(1));
      c.dispose();
      s.dispose();

      expect(counter.createCount, equals(2));
      expect(counter.getCount, greaterThanOrEqualTo(2));
      expect(counter.setCount, greaterThanOrEqualTo(2));
      expect(counter.disposeCount, equals(2));
      expect(
          counter.count,
          equals(counter.createCount +
              counter.disposeCount +
              counter.notifyCount +
              counter.setCount +
              counter.getCount +
              counter.effectCount));
    });

    test("devtools collects raw node payload with snapshot relationships", () {
      final s = Signal(
        1,
        debug: const JoltDebugOption.of("debug-source", null),
      );
      final c = Computed(
        () => s.value + 1,
        debug: const JoltDebugOption.of("debug-computed", null),
      );

      expect(c.value, equals(2));

      final nodes = JoltDevTools.collectNodesForTesting();
      final source =
          nodes.singleWhere((node) => node["label"] == "debug-source");
      final computed =
          nodes.singleWhere((node) => node["label"] == "debug-computed");

      expect(source["nodeType"], equals("Signal"));
      expect(source["type"], equals("SignalNode<int>"));
      expect(source["value"], equals(1));
      expect(source["valueType"], equals("int"));
      expect(source["isDisposed"], isFalse);

      expect(computed["nodeType"], equals("Computed"));
      expect(computed["type"], equals("ComputedNode<int>"));
      expect(computed["value"], equals(2));
      expect(computed["valueType"], equals("int"));
      expect(computed["dependencies"], contains(source["id"]));
      expect(source["subscribers"], contains(computed["id"]));

      c.dispose();
      s.dispose();

      final afterDispose = JoltDevTools.collectNodesForTesting();
      expect(
        afterDispose.where((node) =>
            node["label"] == "debug-source" ||
            node["label"] == "debug-computed"),
        isEmpty,
      );
    });

    test("devtools receives internal link updates without user debug events",
        () async {
      final userEvents = <DebugNodeOperationType>[];
      final updates = <Map<String, dynamic>>[];
      final subscription = JoltDevTools.updatesForTesting.listen(updates.add);
      void onDebug(DebugNodeOperationType type, ReactiveNode _) {
        userEvents.add(type);
      }

      final s = Signal(
        1,
        debug: JoltDebugOption.of("link-source", onDebug),
      );
      final c = Computed(
        () => s.value + 1,
        debug: JoltDebugOption.of("link-computed", onDebug),
      );

      expect(c.value, equals(2));
      await Future<void>.delayed(Duration.zero);

      final nodes = JoltDevTools.collectNodesForTesting();
      final source =
          nodes.singleWhere((node) => node["label"] == "link-source");
      final computed =
          nodes.singleWhere((node) => node["label"] == "link-computed");

      expect(
        updates,
        contains(
          allOf(
            containsPair("operation", "link"),
            containsPair("depId", source["id"]),
            containsPair("subId", computed["id"]),
          ),
        ),
      );

      c.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(
        updates,
        contains(
          allOf(
            containsPair("operation", "unlink"),
            containsPair("depId", source["id"]),
            containsPair("subId", computed["id"]),
          ),
        ),
      );
      expect(userEvents, everyElement(isA<DebugNodeOperationType>()));

      await subscription.cancel();
      s.dispose();
    });

    test("devtools uses explicit debug type while keeping raw node type", () {
      final watcher = Watcher(
        () => 1,
        (value, _) => value,
        debug: const JoltDebugOption.of("typed-watcher", null),
      );

      final node = JoltDevTools.collectNodesForTesting()
          .singleWhere((node) => node["label"] == "typed-watcher");

      expect(node["nodeType"], equals("Effect"));
      expect(node["type"], equals("EffectNode"));

      watcher.dispose();
    });
  });
}
