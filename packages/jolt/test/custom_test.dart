import "dart:async";

import "package:jolt/jolt.dart";
import "package:jolt/src/core/reactive.dart" as reactive;
import "package:jolt/src/core/reactive.dart";
import "package:jolt/src/jolt/signal.dart";
import "package:test/test.dart";

import "utils.dart";

/// Test implementation of CustomReactiveNode
/// Implements a simple reactive node that can be read and updated
class TestCustomNode extends CustomReactiveNode<int> {
  TestCustomNode() : super(flags: ReactiveFlags.mutable);

  int _value = 0;
  bool _dirty = false;

  /// Gets the current value and establishes reactive dependency
  int get value {
    // Link to active subscriber if any
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }

    // Update node if dirty (system automatically calls updateNode via updateCustom)
    if (flags & ReactiveFlags.dirty != 0) {
      // Call system function updateNode which will call updateCustom -> this.updateNode()
      // This simulates what the system does automatically
      if (reactive.updateNode(this)) {
        final subs = this.subs;
        if (subs != null) {
          reactive.shallowPropagate(subs);
        }
      }
    }

    return _value;
  }

  void setValue(int newValue) {
    _value = newValue;
    _dirty = true;
    flags |= ReactiveFlags.dirty;
  }

  @override
  bool updateNode() {
    if (_dirty) {
      _dirty = false;
      flags &= ~ReactiveFlags.dirty;
      return true; // Value changed
    }
    return false; // No change
  }

  void markDirty() {
    _dirty = true;
    flags |= ReactiveFlags.dirty;
  }
}

class DebouncedSignal<T> extends SignalImpl<T> {
  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });
  final Duration delay;
  Timer? _timer;

  @override
  T set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
    return value;
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

void main() {
  group("Custom Features", () {
    group("DebouncedSignal", () {
      test("should delay value update", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        expect(signal.value, equals(0));
        expect(signal.peek, equals(0));

        signal.set(1);
        expect(signal.value, equals(0));
        expect(signal.peek, equals(0));

        await Future.delayed(const Duration(milliseconds: 150));
        expect(signal.value, equals(1));
        expect(signal.peek, equals(1));
        expect(counter.setCount, equals(1));

        signal.dispose();
      });

      test("should reset timer when updated multiple times during delay",
          () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );
        // test code
        // ignore: cascade_invocations
        signal.set(1);
        await Future.delayed(const Duration(milliseconds: 50));
        signal.set(2);
        await Future.delayed(const Duration(milliseconds: 50));
        signal.set(3);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(signal.value, equals(0));

        await Future.delayed(const Duration(milliseconds: 60));
        expect(signal.value, equals(3));
        expect(counter.setCount, equals(1));

        signal.dispose();
      });

      test("should cancel pending updates on dispose", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        final initialValue = signal.value;
        expect(initialValue, equals(0));

        signal
          ..set(1)
          ..dispose();

        await Future.delayed(const Duration(milliseconds: 150));
        expect(counter.setCount, equals(0));
      });

      test("should notify subscribers after debounce completes", () async {
        final counter = DebugCounter();
        final signal = DebouncedSignal(
          0,
          delay: const Duration(milliseconds: 100),
          onDebug: counter.onDebug,
        );

        final values = <int>[];
        final effect = Effect(() {
          values.add(signal.value);
        });

        signal
          ..set(1)
          ..set(2)
          ..set(3);

        await Future.delayed(const Duration(milliseconds: 150));

        expect(values, equals([0, 3]));
        expect(counter.setCount, equals(1));

        effect.dispose();
        signal.dispose();
      });

      test("basic usage example", () async {
        final searchQuery = DebouncedSignal(
          "",
          delay: const Duration(milliseconds: 300),
        );

        final results = <String>[];
        final effect = Effect(() {
          final query = searchQuery.value;
          if (query.isNotEmpty) {
            results.add("Results for: $query");
          }
        });

        searchQuery.value = "j";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jo";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jol";
        await Future.delayed(const Duration(milliseconds: 10));
        searchQuery.value = "jolt";

        expect(results, isEmpty);

        await Future.delayed(const Duration(milliseconds: 350));

        expect(results, equals(["Results for: jolt"]));
        expect(searchQuery.value, equals("jolt"));

        effect.dispose();
        searchQuery.dispose();
      });
    });

    group("CustomReactiveNode", () {
      test("updateNode is automatically called by system when node is dirty",
          () {
        final node = TestCustomNode();
        node.setValue(42);

        // Accessing value triggers updateNode via system (updateNode -> updateCustom)
        final value = node.value;
        expect(value, equals(42));
        expect(node._dirty, isFalse); // updateNode cleared the dirty flag
      });

      test("updateNode returns false when value unchanged", () {
        final node = TestCustomNode();
        node.setValue(42);
        final _ = node.value; // First access triggers update

        // Second access without changing value - updateNode returns false
        final value = node.value;
        expect(value, equals(42));
        expect(node._dirty, isFalse);
      });

      test("updateNode is called via updateCustom for CustomReactiveNode", () {
        final node = TestCustomNode();
        node.setValue(10);

        // System automatically calls updateNode (via updateCustom) when accessing
        final value = node.value;
        expect(value, equals(10));
      });

      test("updateCustom returns true for non-CustomReactiveNode", () {
        final regularNode = ReactiveNode(flags: ReactiveFlags.mutable);
        regularNode.flags |= ReactiveFlags.dirty;
        final changed = updateCustom(regularNode);
        expect(changed, isTrue);
      });

      test("notifyCustom marks node as dirty and notifies subscribers", () {
        final node = TestCustomNode();
        final values = <int>[];

        final effect = Effect(() {
          values.add(node.value);
        });

        expect(values, equals([0])); // Initial value

        node.setValue(5);
        notifyCustom(node);
        expect(
            values,
            equals([
              0,
              5
            ])); // Effect runs after notify, updateNode called automatically

        node.setValue(10);
        notifyCustom(node);
        expect(
            values,
            equals([
              0,
              5,
              10
            ])); // Effect runs again, updateNode called automatically

        effect.dispose();
      });

      test("notifyCustom propagates to multiple subscribers", () {
        final node = TestCustomNode();
        final values1 = <int>[];
        final values2 = <int>[];

        final effect1 = Effect(() {
          values1.add(node.value);
        });

        final effect2 = Effect(() {
          values2.add(node.value);
        });

        expect(values1, equals([0]));
        expect(values2, equals([0]));

        node.setValue(7);
        notifyCustom(node);

        expect(values1, equals([0, 7]));
        expect(values2, equals([0, 7]));

        effect1.dispose();
        effect2.dispose();
      });

      test("notifyCustom flushes effects when not in batch", () {
        final node = TestCustomNode();
        final values = <int>[];

        final effect = Effect(() {
          values.add(node.value);
        });

        expect(values, equals([0]));

        node.setValue(3);
        notifyCustom(node);

        expect(
            values,
            equals([
              0,
              3
            ])); // Effect flushed immediately, updateNode called automatically

        effect.dispose();
      });

      test("notifyCustom batches effects when in batch", () {
        final node = TestCustomNode();
        final values = <int>[];

        final effect = Effect(() {
          values.add(node.value);
        });

        expect(values, equals([0]));

        startBatch();
        node.setValue(1);
        notifyCustom(node);
        node.setValue(2);
        notifyCustom(node);
        node.setValue(3);
        notifyCustom(node);
        endBatch(); // Effects flushed here, updateNode called automatically

        expect(values, equals([0, 3])); // Only final value after batch

        effect.dispose();
      });

      test("updateNode can be called multiple times via system", () {
        final node = TestCustomNode();

        node.setValue(1);
        final value1 = node.value; // Triggers updateNode
        expect(value1, equals(1));

        node.setValue(2);
        final value2 = node.value; // Triggers updateNode again
        expect(value2, equals(2));

        // No change - accessing again doesn't trigger update
        final value3 = node.value;
        expect(value3, equals(2));
      });

      test("updateNode sets mutable flag via updateCustom", () {
        final node = TestCustomNode();
        node.setValue(5);

        // Accessing value triggers updateNode (via updateCustom)
        final _ = node.value;

        expect(node.flags & ReactiveFlags.mutable, isNot(equals(0)));
      });

      test("notifyCustom sets dirty and mutable flags", () {
        final node = TestCustomNode();

        notifyCustom(node);

        expect(node.flags & ReactiveFlags.dirty, isNot(equals(0)));
        expect(node.flags & ReactiveFlags.mutable, isNot(equals(0)));
      });

      test("updateNode works with computed dependencies", () {
        final node = TestCustomNode();
        final computed = Computed<int>(() => node.value * 2);
        final values = <int>[];

        final effect = Effect(() {
          values.add(computed.value);
        });

        expect(values, equals([0])); // 0 * 2

        node.setValue(5);
        notifyCustom(
            node); // updateNode called automatically when computed accesses node.value

        expect(values, equals([0, 10])); // 5 * 2

        effect.dispose();
      });

      test("CustomReactiveNode can be used in reactive chains", () {
        final node = TestCustomNode();
        final signal = Signal(0);
        final computed = Computed<int>(() => node.value + signal.value);
        final values = <int>[];

        final effect = Effect(() {
          values.add(computed.value);
        });

        expect(values, equals([0])); // 0 + 0

        node.setValue(10);
        notifyCustom(
            node); // updateNode called automatically when computed accesses node.value
        expect(values, equals([0, 10])); // 10 + 0

        signal.value = 5;
        expect(values, equals([0, 10, 15])); // 10 + 5

        effect.dispose();
      });

      test("getCustom traverses subs chain when first sub doesn't match flags",
          () {
        final customNode = TestCustomNode();

        final firstSub = ReactiveNode(flags: 0);

        final secondSub = ReactiveNode(flags: ReactiveFlags.watching);

        final link = Link(
          version: cycle,
          dep: customNode,
          sub: secondSub,
        );
        firstSub.subs = link;

        final prevSub = setActiveSub(firstSub);
        try {
          getCustom(customNode);

          expect(customNode.subs, isNotNull);
          expect(customNode.subs!.sub, equals(secondSub));
          expect(customNode.subs!.dep, equals(customNode));
        } finally {
          setActiveSub(prevSub);
        }
      });
    });
  });
}
