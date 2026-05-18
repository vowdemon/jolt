import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/core/debug.dart";
import "package:test/test.dart";

import "../test_utils.dart";

typedef _DebugCapture = ({
  List<DebugNodeOperationType> events,
  List<ReactiveNode> nodes,
  void Function(DebugNodeOperationType type, ReactiveNode node) onDebug,
});

_DebugCapture _captureDebug() {
  final events = <DebugNodeOperationType>[];
  final nodes = <ReactiveNode>[];
  void onDebug(DebugNodeOperationType type, ReactiveNode node) {
    events.add(type);
    nodes.add(node);
  }

  return (events: events, nodes: nodes, onDebug: onDebug);
}

void _expectBoundToRaw(List<ReactiveNode> nodes, ReactiveNode raw) {
  expect(nodes, everyElement(same(raw)));
}

void main() {
  group("Debug", () {
    setUpAll(JoltDebug.init);

    group("onDebug callback", () {
      test("signal binds to raw node and reports lifecycle in order", () {
        final capture = _captureDebug();
        final signal = Signal(0, debug: JoltDebugOption.fn(capture.onDebug));
        final raw = (signal as SignalImpl<int>).raw;

        signal.value = 1;
        signal.value;
        signal.notify();
        signal.dispose();

        _expectBoundToRaw(capture.nodes, raw);
        expect(
          capture.events,
          containsAllInOrder([
            DebugNodeOperationType.create,
            DebugNodeOperationType.set,
            DebugNodeOperationType.get,
            DebugNodeOperationType.notify,
            DebugNodeOperationType.dispose,
          ]),
        );
      });

      test("computed reports value operations on read and notify", () {
        final capture = _captureDebug();
        final computed =
            Computed(() => 1, debug: JoltDebugOption.fn(capture.onDebug));

        expect(computed.value, equals(1));
        computed.notify();
        computed.dispose();

        expect(
          capture.events,
          containsAllInOrder([
            DebugNodeOperationType.create,
            DebugNodeOperationType.get,
            DebugNodeOperationType.set,
            DebugNodeOperationType.notify,
            DebugNodeOperationType.dispose,
          ]),
        );
      });

      test("effect reports runs when a dependency changes", () {
        final capture = _captureDebug();
        final source = Signal(0);
        final effect = Effect(
          () {
            source.value;
          },
          debug: JoltDebugOption.fn(capture.onDebug),
        );

        source.value = 1;
        effect.dispose();
        source.dispose();

        expect(capture.events, contains(DebugNodeOperationType.create));
        expect(capture.events, contains(DebugNodeOperationType.effect));
        expect(capture.events, contains(DebugNodeOperationType.dispose));
      });

      test("watcher reports effect on manual trigger", () {
        final capture = _captureDebug();
        final watcher = Watcher(
          () => 1,
          (value, _) => value,
          debug: JoltDebugOption.fn(capture.onDebug),
        );

        watcher.trigger();
        watcher.dispose();

        expect(capture.events, contains(DebugNodeOperationType.create));
        expect(capture.events, contains(DebugNodeOperationType.effect));
        expect(capture.events, contains(DebugNodeOperationType.dispose));
      });

      test("effect scope reports create and dispose only", () {
        final capture = _captureDebug();
        final scope = EffectScope(debug: JoltDebugOption.fn(capture.onDebug));

        scope.run(() => 1);
        scope.dispose();

        expect(
          capture.events,
          containsAllInOrder([
            DebugNodeOperationType.create,
            DebugNodeOperationType.dispose,
          ]),
        );
        expect(capture.events, isNot(contains(DebugNodeOperationType.effect)));
      });
    });

    group("JoltDebugOption", () {
      test("merge returns null when both options are null", () {
        expect(JoltDebugOption.merge(null, null), isNull);
      });

      test("merge prefers other fields when devtools is enabled", () {
        final events = <DebugNodeOperationType>[];
        final merged = JoltDebugOption.merge(
          const JoltDebugOption.of("base-label", null),
          JoltDebugOption.fn((type, _) => events.add(type)),
        );

        expect(merged, isNotNull);
        final signal = Signal(0, debug: merged);
        expect(events, contains(DebugNodeOperationType.create));
        signal.dispose();
      });
    });

    group("DebugCounter", () {
      test("tracks per-type buckets across multiple nodes", () {
        final counter = DebugCounter();

        final source =
            Signal(0, debug: JoltDebugOption.fn(counter.onDebug));
        final derived = Computed(
          () => source.value,
          debug: JoltDebugOption.fn(counter.onDebug),
        );

        expect(derived.value, equals(0));
        source.value = 1;
        expect(derived.value, equals(1));
        derived.dispose();
        source.dispose();

        expect(counter.createCount, equals(2));
        expect(counter.getCount, greaterThanOrEqualTo(2));
        expect(counter.setCount, greaterThanOrEqualTo(2));
        expect(counter.disposeCount, equals(2));
      });
    });

    group("DevTools", () {
      test("collects node snapshots with dependency graph", () {
        final source = Signal(
          1,
          debug: const JoltDebugOption.of("debug-source", null),
        );
        final derived = Computed(
          () => source.value + 1,
          debug: const JoltDebugOption.of("debug-computed", null),
        );

        expect(derived.value, equals(2));

        final nodes = JoltDevTools.collectNodesForTesting();
        final sourceNode =
            nodes.singleWhere((node) => node["label"] == "debug-source");
        final derivedNode =
            nodes.singleWhere((node) => node["label"] == "debug-computed");

        expect(sourceNode["nodeType"], equals("Signal"));
        expect(sourceNode["type"], equals("SignalNode<int>"));
        expect(sourceNode["value"], equals(1));
        expect(sourceNode["valueType"], equals("int"));
        expect(sourceNode["isDisposed"], isFalse);

        expect(derivedNode["nodeType"], equals("Computed"));
        expect(derivedNode["type"], equals("ComputedNode<int>"));
        expect(derivedNode["value"], equals(2));
        expect(derivedNode["valueType"], equals("int"));
        expect(derivedNode["dependencies"], contains(sourceNode["id"]));
        expect(sourceNode["subscribers"], contains(derivedNode["id"]));

        derived.dispose();
        source.dispose();

        final afterDispose = JoltDevTools.collectNodesForTesting();
        expect(
          afterDispose.where(
            (node) =>
                node["label"] == "debug-source" ||
                node["label"] == "debug-computed",
          ),
          isEmpty,
        );
      });

      test("streams link and unlink on dependency wiring", () async {
        final userEvents = <DebugNodeOperationType>[];
        final updates = <Map<String, dynamic>>[];
        final subscription =
            JoltDevTools.updatesForTesting.listen(updates.add);
        void onDebug(DebugNodeOperationType type, ReactiveNode _) {
          userEvents.add(type);
        }

        final source = Signal(
          1,
          debug: JoltDebugOption.of("link-source", onDebug),
        );
        final derived = Computed(
          () => source.value + 1,
          debug: JoltDebugOption.of("link-computed", onDebug),
        );

        expect(derived.value, equals(2));
        await Future<void>.delayed(Duration.zero);

        final nodes = JoltDevTools.collectNodesForTesting();
        final sourceNode =
            nodes.singleWhere((node) => node["label"] == "link-source");
        final derivedNode =
            nodes.singleWhere((node) => node["label"] == "link-computed");

        expect(
          updates,
          contains(
            allOf(
              containsPair("operation", "link"),
              containsPair("depId", sourceNode["id"]),
              containsPair("subId", derivedNode["id"]),
            ),
          ),
        );
        derived.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(
          updates,
          contains(
            allOf(
              containsPair("operation", "unlink"),
              containsPair("depId", sourceNode["id"]),
              containsPair("subId", derivedNode["id"]),
            ),
          ),
        );

        await subscription.cancel();
        source.dispose();
      });

      test("maps watcher to effect node type in snapshots", () {
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

      test("readRootValue returns values for signal and computed roots", () {
        final source = Signal(
          1,
          debug: const JoltDebugOption.of("root-signal", null),
        );
        final derived = Computed(
          () => source.value + 1,
          debug: const JoltDebugOption.of("root-computed", null),
        );

        expect(derived.value, equals(2));

        final nodes = JoltDevTools.collectNodesForTesting();
        final sourceId =
            nodes.singleWhere((node) => node["label"] == "root-signal")["id"]
                as int;
        final derivedId =
            nodes.singleWhere((node) => node["label"] == "root-computed")["id"]
                as int;

        expect(JoltDevTools.readRootValue(sourceId), equals(1));
        expect(JoltDevTools.readRootValue(derivedId), equals(2));

        derived.dispose();
        source.dispose();
      });

      test("readRootValue returns null for unknown ids", () {
        expect(JoltDevTools.readRootValue(-1), isNull);
      });

      test("writeSignalValue updates signal through reactive setter", () {
        final source = Signal(
          1,
          debug: const JoltDebugOption.of("editable-signal", null),
        );
        final doubled = Computed(() => source.value * 2);

        expect(doubled.value, equals(2));

        final sourceId = JoltDevTools.collectNodesForTesting()
            .singleWhere((node) => node["label"] == "editable-signal")["id"]
            as int;

        expect(JoltDevTools.writeSignalValue(sourceId, 5), isTrue);
        expect(source.value, equals(5));
        expect(doubled.value, equals(10));

        doubled.dispose();
        source.dispose();
      });

      test("writeSignalValue rejects non-signal node ids", () {
        final derived = Computed(
          () => 1,
          debug: const JoltDebugOption.of("non-signal-root", null),
        );

        expect(derived.value, equals(1));

        final derivedId = JoltDevTools.collectNodesForTesting()
            .singleWhere((node) => node["label"] == "non-signal-root")["id"]
            as int;

        expect(JoltDevTools.writeSignalValue(derivedId, 2), isFalse);
        expect(derived.value, equals(1));

        derived.dispose();
      });
    });
  });
}
